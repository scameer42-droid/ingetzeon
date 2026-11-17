import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../providers/calorie_provider.dart';
import '../../../providers/workout_provider.dart';
import '../../../services/voice_service.dart';
import '../../../services/workout_logic.dart';
import '../../widgets/common.dart';
import 'workout_screen.dart';

enum _Phase { ready, work, rest, done }

/// Pemutar latihan: bersiap 10 dtk → gerakan → istirahat → … → ringkasan.
class WorkoutPlayer extends ConsumerStatefulWidget {
  const WorkoutPlayer({super.key, required this.program, this.mult = 1, required this.logProgram, required this.title});
  final WorkoutProgram program;
  final double mult;
  final String logProgram, title;
  @override
  ConsumerState<WorkoutPlayer> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends ConsumerState<WorkoutPlayer> {
  late final List<WorkoutStep> _steps = Workout.steps(widget.program, mult: widget.mult);
  _Phase _phase = _Phase.ready;
  int _i = 0; // langkah sekarang
  int _left = 10; // detik tersisa (gerakan berwaktu / istirahat / bersiap)
  int _repElapsed = 0; // detik berjalan untuk gerakan repetisi
  bool _paused = false;
  Timer? _t;
  int _workSecs = 0; // detik benar-benar bergerak
  double _kcal = 0;
  final _started = DateTime.now();
  bool _saved = false;

  WorkoutStep get _s => _steps[_i];
  bool get _voice => ref.read(workoutProvider).voice;
  double? get _kg => ref.read(calorieProvider).profile?.kg;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    _say('Bersiap. Gerakan pertama: ${_s.ex.name}');
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    WakelockPlus.disable().catchError((_) {});
    VoiceService.instance.stopSpeaking();
    super.dispose();
  }

  void _say(String t) {
    if (_voice) VoiceService.instance.speak(t);
  }

  void _tick() {
    if (_paused || _phase == _Phase.done) return;
    setState(() {
      if (_phase == _Phase.work) {
        _workSecs++;
        _kcal += Workout.burn(_s.ex.met, _kg, 1);
        if (!_s.ex.timed) {
          _repElapsed++;
          return;
        }
      }
      _left--;
      if (_left > 0 && _left <= 3) HapticFeedback.selectionClick();
      if (_left == 3 && _phase != _Phase.work) _say('3, 2, 1');
      if (_left == _s.secs ~/ 2 && _phase == _Phase.work && _s.secs >= 30) _say('Setengah jalan, terus!');
    });
    if (_left <= 0) _next();
  }

  void _startWork() {
    _phase = _Phase.work;
    _left = _s.secs;
    _repElapsed = 0;
    HapticFeedback.mediumImpact();
    _say(_s.ex.timed ? '${_s.ex.name}, ${Workout.amountText(_s.ex, _s.amount)}' : '${_s.ex.name}, ${_s.amount} kali');
  }

  void _next() {
    setState(() {
      if (_phase == _Phase.ready || _phase == _Phase.rest) {
        _startWork();
        return;
      }
      // selesai satu gerakan
      if (_i >= _steps.length - 1) {
        _finish();
        return;
      }
      _i++;
      if (widget.program.rest > 0) {
        _phase = _Phase.rest;
        _left = widget.program.rest;
        HapticFeedback.lightImpact();
        _say('Istirahat. Berikutnya ${_s.ex.name}');
      } else {
        _startWork();
      }
    });
  }

  void _prev() {
    setState(() {
      if ((_phase == _Phase.work && _left < _s.secs - 2) || _i == 0) {
        _startWork();
        return;
      }
      _i = math.max(0, _i - 1);
      _startWork();
    });
  }

  void _finish() {
    _phase = _Phase.done;
    _t?.cancel();
    HapticFeedback.heavyImpact();
    _say('Latihan selesai. Kerja bagus!');
    _save();
  }

  Future<void> _save() async {
    if (_saved || _workSecs < 30) return;
    _saved = true;
    final total = DateTime.now().difference(_started).inSeconds;
    await ref.read(workoutProvider.notifier).add(
          name: widget.title,
          secs: math.max(_workSecs, math.min(total, _workSecs * 2)),
          kcal: _kcal,
          program: widget.logProgram,
          emoji: widget.program.emoji,
        );
  }

  Future<bool> _confirmExit() async {
    if (_phase == _Phase.done || _workSecs < 10) return true;
    setState(() => _paused = true);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Berhenti latihan?'),
        content: Text('Sudah ${(_workSecs / 60).toStringAsFixed(0)} menit bergerak. Simpan yang sudah dikerjakan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'lanjut'), child: const Text('Lanjut latihan')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'buang'), child: const Text('Keluar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'simpan'), child: const Text('Simpan & keluar')),
        ],
      ),
    );
    if (r == 'simpan') await _save();
    if (r == 'lanjut' || r == null) {
      setState(() => _paused = false);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = Color(widget.program.color);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _phase == _Phase.rest ? const Color(0xFF0F766E) : null,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: _phase == _Phase.rest ? Colors.white : null,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(widget.title, style: const TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              tooltip: 'Suara pemandu',
              onPressed: () => setState(() => ref.read(workoutProvider.notifier).setVoice(!_voice)),
              icon: Icon(ref.watch(workoutProvider).voice ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            ),
          ],
        ),
        body: SafeArea(top: false, child: _phase == _Phase.done ? _summary(c) : _player(c)),
      ),
    );
  }

  Widget _player(Color c) {
    final rest = _phase == _Phase.rest, ready = _phase == _Phase.ready;
    final s = _s;
    final fg = rest ? Colors.white : context.ink;
    final total = ready ? 10 : rest ? widget.program.rest : s.secs;
    final progress = (_i + (_phase == _Phase.work ? 1 - _left / math.max(1, s.secs) : 0)) / _steps.length;
    return Column(children: [
      // progres keseluruhan
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress.clamp(0, 1).toDouble(), minHeight: 6, color: rest ? Colors.white : c, backgroundColor: (rest ? Colors.white : c).withValues(alpha: .18)),
            ),
          ),
          const SizedBox(width: 10),
          Text('${_i + 1}/${_steps.length}', style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
        ]),
      ),
      if (widget.program.rounds > 1)
        Text('Ronde ${s.round} dari ${widget.program.rounds}', style: TextStyle(color: rest ? Colors.white70 : context.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 10),
            Text(ready ? 'BERSIAP' : rest ? 'ISTIRAHAT' : 'GERAKAN', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, color: rest ? Colors.white70 : c, fontSize: 13)),
            const SizedBox(height: 4),
            Text(rest || ready ? 'Berikutnya: ${s.ex.name}' : s.ex.name,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 16),
            SizedBox(
              width: 230,
              height: 230,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: !ready && !rest && !s.ex.timed ? 1 : (_left / math.max(1, total)).clamp(0, 1).toDouble(),
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: rest ? Colors.white : c,
                    backgroundColor: (rest ? Colors.white : c).withValues(alpha: .15),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  BouncingEmoji(s.ex.emoji, size: 58, speed: rest ? 1400 : 600),
                  const SizedBox(height: 4),
                  Text(!ready && !rest && !s.ex.timed ? '${s.amount}×' : '$_left',
                      style: accentFont(size: 46, color: fg)),
                  if (!ready && !rest && !s.ex.timed)
                    Text('${_repElapsed}s · ketuk Selesai', style: TextStyle(color: context.muted, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            // cara singkat
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: rest ? Colors.white.withValues(alpha: .14) : context.card2, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var k = 0; k < s.ex.steps.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${k + 1}. ${s.ex.steps[k]}', style: TextStyle(color: fg, height: 1.4, fontSize: 13.5)),
                  ),
                Text('💡 ${s.ex.tip}', style: TextStyle(color: rest ? Colors.white : const Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 13, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
      // kontrol
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(children: [
          _ctrl(Icons.skip_previous_rounded, _prev, fg),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 60,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: rest ? Colors.white : c,
                  foregroundColor: rest ? const Color(0xFF0F766E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  if (_phase == _Phase.work && !s.ex.timed) {
                    _next();
                  } else if (rest || ready) {
                    _next();
                  } else {
                    setState(() => _paused = !_paused);
                  }
                },
                icon: Icon(_phase == _Phase.work && !s.ex.timed
                    ? Icons.check_rounded
                    : rest || ready
                        ? Icons.play_arrow_rounded
                        : _paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded),
                label: Text(
                  _phase == _Phase.work && !s.ex.timed
                      ? 'Selesai'
                      : rest || ready
                          ? 'Mulai sekarang'
                          : _paused
                              ? 'Lanjut'
                              : 'Jeda',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ctrl(Icons.skip_next_rounded, _next, fg),
        ]),
      ),
    ]);
  }

  Widget _ctrl(IconData i, VoidCallback onTap, Color fg) => SizedBox(
        width: 56,
        height: 56,
        child: IconButton.filledTonal(onPressed: onTap, icon: Icon(i, size: 28, color: fg)),
      );

  Widget _summary(Color c) {
    final s = ref.watch(workoutProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 24), children: [
      const Center(child: BouncingEmoji('🏆', size: 84)),
      const SizedBox(height: 10),
      const Text('Latihan selesai!', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(['Kerja bagus! Satu langkah lebih dekat ke perut rata 💪', 'Konsisten itu kuncinya. Sampai besok! 🔥', 'Badan berterima kasih padamu hari ini 🙌'][_workSecs % 3],
          textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 15)),
      const SizedBox(height: 22),
      Row(children: [
        _box('⏱', '${(_workSecs / 60).toStringAsFixed(_workSecs < 600 ? 1 : 0).replaceAll('.', ',')}', 'menit bergerak', c),
        const SizedBox(width: 10),
        _box('🔥', fmtNum(_kcal), 'kkal terbakar', c),
        const SizedBox(width: 10),
        _box('⚡', '${s.streak}', 'hari streak', c),
      ]),
      const SizedBox(height: 16),
      SoftCard(
        child: Text('Kalori yang terbakar otomatis menambah sisa kalori makan hari ini di fitur Kalori. Minum air putih yang cukup ya 💧',
            style: TextStyle(color: context.muted, height: 1.4)),
      ),
      const SizedBox(height: 20),
      GradientButton(label: 'Selesai', icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop()),
    ]);
  }

  Widget _box(String e, String v, String l, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Text(e, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(l, textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 11.5)),
          ]),
        ),
      );
}
