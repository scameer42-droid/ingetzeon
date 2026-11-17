import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../providers/calorie_provider.dart';
import '../../../providers/workout_provider.dart';
import '../../../services/voice_service.dart';
import '../../../services/workout_logic.dart';
import '../../widgets/common.dart';
import 'exercise_figure.dart';
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

  void _addRest() => setState(() => _left += 20);

  Future<void> _showSteps() async {
    setState(() => _paused = true);
    await showExerciseDetail(context, [for (final st in _steps) st.ex], index: _i, amounts: [for (final st in _steps) st.amount]);
    if (mounted) setState(() => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    final rest = _phase == _Phase.rest;
    final dark = rest || _phase == _Phase.done;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: dark ? kNavy : (context.isDark ? null : Colors.white),
        body: Container(
          decoration: dark ? const BoxDecoration(gradient: kNavyGradient) : null,
          child: SafeArea(
            child: _phase == _Phase.done
                ? _summary()
                : Column(children: [
                    _top(rest),
                    Expanded(child: rest ? _restView() : _workView()),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _top(bool rest) {
    final fg = rest ? Colors.white : context.ink;
    final n = _steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(children: [
        Row(children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: fg),
            onPressed: () async {
              if (await _confirmExit() && mounted) Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
          ),
          IconButton(
            tooltip: tr('Suara pemandu'),
            onPressed: () => setState(() => ref.read(workoutProvider.notifier).setVoice(!_voice)),
            icon: Icon(ref.watch(workoutProvider).voice ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: fg),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Row(children: [
            for (var k = 0; k < n; k++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: k == n - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: k < _i || (k == _i && _phase == _Phase.work && _left <= 0)
                        ? (rest ? Colors.white : kBlue)
                        : k == _i && !rest
                            ? kBlue.withValues(alpha: .45)
                            : (rest ? Colors.white : kBlue).withValues(alpha: .14),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(children: [
            Text('GERAKAN ${_i + 1}/$n', style: olaDisplay(15, color: rest ? Colors.white70 : context.muted, spacing: 1)),
            const Spacer(),
            if (widget.program.rounds > 1)
              Text('RONDE ${_s.round}/${widget.program.rounds}', style: olaDisplay(15, color: rest ? Colors.white70 : context.muted, spacing: 1)),
          ]),
        ),
      ]),
    );
  }

  Widget _workView() {
    final s = _s, ready = _phase == _Phase.ready, reps = !ready && !s.ex.timed;
    final big = ready ? '$_left' : reps ? 'x${s.amount}' : fmtClock(_left);
    return Column(children: [
      Expanded(
        flex: 6,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: context.isDark ? [const Color(0xFF1E293B), const Color(0xFF14203A)] : [const Color(0xFFF1F5FD), const Color(0xFFDCE7FA)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(8, 30, 8, 4), child: ExerciseFigure(s.ex.id, paused: _paused))),
            if (ready)
              Positioned(
                left: 14,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(gradient: kFireGradient, borderRadius: BorderRadius.circular(99)),
                  child: Text('BERSIAP', style: olaDisplay(16, spacing: 1.2)),
                ),
              ),
            Positioned(
              right: 6,
              top: 4,
              child: TextButton.icon(
                onPressed: _showSteps,
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Cara', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            if (_paused)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: Text('JEDA', style: olaDisplay(44, spacing: 2)),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(ready ? 'BERIKUTNYA: ${tr(s.ex.name).toUpperCase()}' : tr(s.ex.name).toUpperCase(),
            textAlign: TextAlign.center, maxLines: 2, style: olaDisplay(ready ? 24 : 32, color: context.ink)),
      ),
      Text(big, style: olaDisplay(84, color: ready ? kOla : context.ink, spacing: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          ready
              ? 'Ambil posisi — ${amountLabel(s.ex, s.amount)}'
              : reps
                  ? 'Ketuk ✓ kalau sudah ${s.amount} kali · ${_repElapsed}s'
                  : '💡 ${s.ex.tip}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.muted, fontSize: 13, height: 1.35),
        ),
      ),
      const Spacer(flex: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _ctrl(Icons.skip_previous_rounded, _prev, 'Sebelumnya'),
          GestureDetector(
            onTap: () {
              if (ready || reps) {
                _next();
              } else {
                setState(() => _paused = !_paused);
              }
            },
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: reps ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)]) : kBlueGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (reps ? const Color(0xFF16A34A) : kBlue).withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8)],
              ),
              child: Icon(
                reps
                    ? Icons.check_rounded
                    : ready || _paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          _ctrl(Icons.skip_next_rounded, _next, 'Lewati'),
        ]),
      ),
    ]);
  }

  Widget _ctrl(IconData i, VoidCallback onTap, String tip) => SizedBox(
        width: 60,
        height: 60,
        child: IconButton.filledTonal(tooltip: tr(tip), onPressed: onTap, icon: Icon(i, size: 30)),
      );

  Widget _restView() {
    final s = _s;
    return Column(children: [
      const Spacer(flex: 2),
      Text('ISTIRAHAT', style: olaDisplay(34, color: Colors.white70, spacing: 3)),
      Text(fmtClock(_left), style: olaDisplay(96, spacing: 2)),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54, width: 1.5),
            minimumSize: const Size(120, 52),
            shape: const StadiumBorder(),
          ),
          onPressed: _addRest,
          child: Text('+20 DTK', style: olaDisplay(20, spacing: 1)),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kNavy, minimumSize: const Size(140, 52), shape: const StadiumBorder()),
          onPressed: _next,
          child: Text('LEWATI', style: olaDisplay(20, color: kNavy, spacing: 1)),
        ),
      ]),
      const Spacer(flex: 2),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        decoration: BoxDecoration(color: context.isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BERIKUTNYA  ${_i + 1}/${_steps.length}', style: olaDisplay(17, color: context.muted, spacing: 1.2)),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(width: 140, child: FigureTile(s.ex.id, animate: true, radius: 16)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(s.ex.name).toUpperCase(), style: olaDisplay(26, color: context.ink)),
                const SizedBox(height: 4),
                Text(amountLabel(s.ex, s.amount), style: olaDisplay(22, color: kBlue)),
                const SizedBox(height: 4),
                Text(s.ex.steps.first, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.3)),
              ]),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _summary() {
    final st = ref.watch(workoutProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(22, 30, 22, 24), children: [
      const Center(child: Text('🏆', style: TextStyle(fontSize: 86))),
      const SizedBox(height: 8),
      Text('LATIHAN SELESAI!', textAlign: TextAlign.center, style: olaDisplay(44)),
      const SizedBox(height: 6),
      Text(['Kerja bagus! Satu langkah lebih dekat ke perut rata 💪', 'Konsisten itu kuncinya. Sampai besok! 🔥', 'Badan berterima kasih padamu hari ini 🙌'][_workSecs % 3],
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 26),
      Row(children: [
        _box('${(_workSecs / 60).toStringAsFixed(_workSecs < 600 ? 1 : 0).replaceAll('.', ',')}', 'menit\nbergerak'),
        const SizedBox(width: 10),
        _box(fmtNum(_kcal), 'kkal\nterbakar'),
        const SizedBox(width: 10),
        _box('${st.streak}', 'hari\nstreak'),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(18)),
        child: const Text('Kalori yang terbakar otomatis menambah sisa kalori makan hari ini di fitur Kalori. Minum air putih yang cukup ya 💧',
            style: TextStyle(color: Colors.white70, height: 1.4)),
      ),
      const SizedBox(height: 24),
      BigStartButton(label: 'Selesai', icon: Icons.check_rounded, onTap: () => Navigator.of(context).pop()),
    ]);
  }

  Widget _box(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Text(v, style: olaDisplay(36)),
            const SizedBox(height: 2),
            Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.2)),
          ]),
        ),
      );
}
