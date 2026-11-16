import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/reminder.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/wellbeing_provider.dart';
import '../../../services/notification_service.dart';
import '../../../services/wellbeing_logic.dart';
import '../../widgets/common.dart';
import '../calorie/calorie_screen.dart';
import '../muslim/muslim_screen.dart';
import '../muslim/muslim_tools.dart';
import 'calm_screen.dart';
import 'tests_screen.dart';

const kCalm = Color(0xFF0EA5A4);
const kCalmGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14B8A6), Color(0xFF6366F1)]);

/// Buka alat bantu dari nama alat (dipakai chat & layar Ruang Tenang).
Future<void> openTool(BuildContext context, WidgetRef ref, String tool) async {
  Widget? page;
  if (tool.startsWith('muslim:doa:')) page = DoaScreen(focus: tool.substring(11));
  if (tool == 'muslim') page = const MuslimScreen();
  if (tool == 'kalori') page = const CalorieScreen();
  if (tool == 'muslim:kiblat') page = const QiblaScreen();
  if (tool == 'muslim:quran') page = const QuranListScreen();
  if (tool.startsWith('tes:')) {
    final t = PsyTest.byId(tool.substring(4));
    page = t == null ? const TestsScreen() : TestRunScreen(test: t);
  }
  switch (tool) {
    case Tool.napas:
      page = const BreatheScreen();
    case Tool.fokus:
      page = const FocusScreen();
    case Tool.jurnal:
      page = const JournalScreen(write: true);
    case Tool.tes:
      page = const TestsScreen();
    case Tool.grounding:
      await showGrounding(context);
      return;
    case Tool.mood:
      await showMoodCheckin(context, ref);
      return;
    case Tool.healing:
      await launchUrl(Uri.parse('https://healing119.id'), mode: LaunchMode.externalApplication);
      return;
    case Tool.telepon:
      await launchUrl(Uri.parse('tel:119'));
      if (context.mounted) showToast(context, 'Setelah tersambung, tekan 8 untuk layanan kesehatan jiwa');
      return;
    case 'kebiasaan':
      page = const HabitsScreen();
    case 'ruang':
      page = const CalmScreen();
  }
  if (page != null && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
  }
}

/// Label tombol alat.
String toolLabel(String tool) {
  if (tool.startsWith('muslim:doa:')) return '🤲 Buka doa harian';
  if (tool == 'muslim') return '🕌 Buka Muslim Harian';
  if (tool == 'kalori') return '🥗 Buka Kalori';
  if (tool == 'muslim:kiblat') return '🧭 Kompas kiblat';
  if (tool == 'muslim:quran') return "📖 Al-Qur'an";
  if (tool.startsWith('tes:')) {
    final t = PsyTest.byId(tool.substring(4));
    return t == null ? '🌈 Semua tes psikologi' : '${t.emoji} Tes ${t.title}';
  }
  return Tool.label[tool] ?? tool;
}

/// Kartu bantuan profesional (Healing119).
class HelpCard extends ConsumerWidget {
  const HelpCard({super.key, this.urgent = false});
  final bool urgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = urgent ? const Color(0xFFE11D48) : kCalm;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.withValues(alpha: .25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.favorite_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(urgent ? 'Butuh bantuan sekarang?' : 'Butuh teman bicara profesional?', style: TextStyle(fontWeight: FontWeight.w800, color: c))),
        ]),
        const SizedBox(height: 6),
        Text(
          'Healing119 dari Kemenkes — gratis & 24 jam, dilayani tenaga kesehatan jiwa terlatih. Telepon 119 lalu tekan 8, atau chat di healing119.id. '
          'Dalam keadaan darurat, telepon 112.',
          style: TextStyle(fontSize: 13, height: 1.45, color: context.ink),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SoftButton(label: 'Telepon 119', icon: Icons.call_rounded, color: c, height: 44, onPressed: () => openTool(context, ref, Tool.telepon))),
          const SizedBox(width: 8),
          Expanded(child: SoftButton(label: 'healing119.id', icon: Icons.chat_rounded, color: c, height: 44, onPressed: () => openTool(context, ref, Tool.healing))),
        ]),
      ]),
    );
  }
}

/// ---------- Cek mood & energi ----------
Future<void> showMoodCheckin(BuildContext context, WidgetRef ref) async {
  final today = ref.read(moodProvider.notifier).today;
  var mood = today?.mood ?? 0;
  var energy = today?.energy ?? 3;
  final note = TextEditingController(text: today?.note ?? '');
  final saved = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gimana perasaanmu hari ini?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setS(() => mood = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: mood == i ? AppColors.primary.withValues(alpha: .14) : ctx.card2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: mood == i ? AppColors.primary : Colors.transparent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(MoodAdvice.moodEmoji[i - 1], style: TextStyle(fontSize: mood == i ? 32 : 28)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Center(child: Text(mood == 0 ? 'Pilih salah satu' : MoodAdvice.moodLabel[mood - 1], style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          Text('Energi: ${MoodAdvice.energyLabel[energy - 1]}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: energy.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v) => setS(() => energy = v.round())),
          TextField(
            controller: note,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Catatan singkat (opsional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Simpan & lihat saran',
            icon: Icons.check_rounded,
            onPressed: mood == 0
                ? null
                : () async {
                    await ref.read(moodProvider.notifier).log(mood, energy, note: note.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
          ),
        ]),
      ),
    ),
  );
  if (saved == true && context.mounted) await showMoodAdvice(context, ref);
}

Future<void> showMoodAdvice(BuildContext context, WidgetRef ref) async {
  final m = ref.read(moodProvider.notifier).today;
  if (m == null) return;
  final count = occurrencesOn(ref.read(remindersProvider), DateTime.now()).length;
  final a = MoodAdvice.forDay(m.mood, m.energy, remindersToday: count);
  await showAppSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Saran jadwal hari ini (${MoodAdvice.moodEmoji[m.mood - 1]} mood · energi ${MoodAdvice.energyLabel[m.energy - 1].toLowerCase()})',
              style: TextStyle(color: ctx.muted)),
          const SizedBox(height: 14),
          for (final t in a.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_rounded, size: 18, color: kCalm)),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
              ]),
            ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in a.tools)
              ActionChip(
                label: Text(toolLabel(t)),
                onPressed: () {
                  Navigator.pop(ctx);
                  openTool(context, ref, t);
                },
              ),
          ]),
          if (m.mood <= 2) ...[const SizedBox(height: 14), const HelpCard()],
        ]),
      ),
    ),
  );
}

/// ---------- Latihan napas ----------
class _Pattern {
  const _Pattern(this.name, this.desc, this.steps);
  final String name;
  final String desc;
  final List<(String, int)> steps; // (aksi, detik) aksi: tarik/tahan/hembus
}

const _patterns = [
  _Pattern('Napas kotak', '4-4-4-4 · menenangkan & fokus', [('tarik', 4), ('tahan', 4), ('hembus', 4), ('tahan', 4)]),
  _Pattern('4-7-8', 'Bantu rileks & mudah tidur', [('tarik', 4), ('tahan', 7), ('hembus', 8)]),
  _Pattern('Napas tenang', 'Tarik 4 · hembus 6 · redakan cemas', [('tarik', 4), ('hembus', 6)]),
];

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});
  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen> {
  int _p = 0;
  int _minutes = 2;
  DateTime? _start;
  Timer? _t;
  int _lastStep = -1;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_start != null) {
      _t?.cancel();
      setState(() => _start = null);
      return;
    }
    _start = DateTime.now();
    _lastStep = -1;
    _t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final el = DateTime.now().difference(_start!).inMilliseconds / 1000;
      if (el >= _minutes * 60) {
        _t?.cancel();
        HapticFeedback.mediumImpact();
        setState(() => _start = null);
        showToast(context, 'Selesai 🌿 Semoga lebih tenang');
        return;
      }
      setState(() {});
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pat = _patterns[_p];
    final cycle = pat.steps.fold<int>(0, (a, s) => a + s.$2);
    String label = 'Siap?';
    int count = 0;
    double scale = .62;
    double remain = _minutes * 60.0;
    if (_start != null) {
      final el = DateTime.now().difference(_start!).inMilliseconds / 1000;
      remain = _minutes * 60 - el;
      var t = el % cycle;
      var lastScale = .62;
      for (var i = 0; i < pat.steps.length; i++) {
        final (a, d) = pat.steps[i];
        if (t < d) {
          if (i != _lastStep) {
            _lastStep = i;
            HapticFeedback.selectionClick();
          }
          final f = t / d;
          label = a == 'tarik' ? 'Tarik napas' : a == 'hembus' ? 'Hembuskan' : 'Tahan';
          count = (d - t).ceil();
          scale = a == 'tarik' ? .62 + .38 * Curves.easeInOut.transform(f) : a == 'hembus' ? 1 - .38 * Curves.easeInOut.transform(f) : lastScale;
          break;
        }
        t -= d;
        lastScale = a == 'tarik' ? 1 : a == 'hembus' ? .62 : lastScale;
      }
    }
    final size = MediaQuery.of(context).size.width * .72;
    return Scaffold(
      appBar: AppBar(title: const Text('Latihan napas'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: Column(children: [
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (var i = 0; i < _patterns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(_patterns[i].name), selected: _p == i, onSelected: _start != null ? null : (_) => setState(() => _p = i)),
                ),
            ]),
          ),
          Text(pat.desc, style: TextStyle(color: context.muted)),
          Expanded(
            child: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(alignment: Alignment.center, children: [
                  Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: kCalm.withValues(alpha: .08))),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: kCalmGradient,
                        boxShadow: [BoxShadow(color: kCalm.withValues(alpha: .35), blurRadius: 40, spreadRadius: -6)],
                      ),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    if (_start != null) Text('$count', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              ),
            ),
          ),
          if (_start != null)
            Text('Sisa ${remain ~/ 60}:${(remain % 60).floor().toString().padLeft(2, '0')}', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600))
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final m in const [1, 2, 3, 5])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: Text('$m menit'), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m)),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: GradientButton(label: _start == null ? 'Mulai' : 'Berhenti', icon: _start == null ? Icons.play_arrow_rounded : Icons.stop_rounded, onPressed: _toggle),
          ),
        ]),
      ),
    );
  }
}

/// ---------- Grounding 5-4-3-2-1 ----------
Future<void> showGrounding(BuildContext context) async {
  const steps = [
    ('5', 'hal yang bisa kamu LIHAT', 'Sebutkan pelan-pelan dalam hati: warna, bentuk, benda di sekitarmu.', Icons.visibility_rounded),
    ('4', 'hal yang bisa kamu SENTUH', 'Rasakan teksturnya: baju, meja, lantai di bawah kakimu.', Icons.back_hand_rounded),
    ('3', 'suara yang bisa kamu DENGAR', 'Kendaraan, kipas angin, napasmu sendiri…', Icons.hearing_rounded),
    ('2', 'aroma yang bisa kamu CIUM', 'Kalau tidak ada, ingat aroma favoritmu.', Icons.air_rounded),
    ('1', 'rasa yang bisa kamu KECAP', 'Atau satu hal baik tentang dirimu.', Icons.favorite_rounded),
  ];
  var i = 0;
  await showAppSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final done = i >= steps.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Grounding 5-4-3-2-1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Bawa pikiranmu kembali ke saat ini', style: TextStyle(color: ctx.muted)),
              const SizedBox(height: 20),
              if (done) ...[
                const Text('🌿', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('Bagus. Kamu sudah kembali ke saat ini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tarik napas panjang sekali lagi, lalu lanjutkan harimu pelan-pelan.', textAlign: TextAlign.center, style: TextStyle(color: ctx.muted)),
              ] else ...[
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kCalmGradient),
                  alignment: Alignment.center,
                  child: Text(steps[i].$1, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(steps[i].$4, color: kCalm),
                  const SizedBox(width: 8),
                  Flexible(child: Text(steps[i].$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 6),
                Text(steps[i].$3, textAlign: TextAlign.center, style: TextStyle(color: ctx.muted, height: 1.4)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < steps.length; k++)
                    Container(
                      width: k == i ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: k <= i ? kCalm : ctx.line, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ],
              const SizedBox(height: 20),
              GradientButton(
                label: done ? 'Selesai' : (i == steps.length - 1 ? 'Selesai' : 'Lanjut'),
                onPressed: () {
                  if (done) {
                    Navigator.pop(ctx);
                  } else {
                    HapticFeedback.selectionClick();
                    setS(() => i++);
                  }
                },
              ),
            ]),
          ),
        );
      },
    ),
  );
}

/// ---------- Timer fokus (Pomodoro) ----------
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _modes = [(25, 5, 'Pomodoro'), (50, 10, 'Fokus dalam'), (15, 3, 'Pemanasan')];
  int _m = 0;
  bool _break = false;
  DateTime? _end; // berjalan bila tidak null
  Duration? _paused; // sisa saat dijeda
  int _sessions = 0;
  Timer? _t;
  final _task = TextEditingController();

  int get _focusMin => _modes[_m].$1;
  int get _breakMin => _modes[_m].$2;
  Duration get _total => Duration(minutes: _break ? _breakMin : _focusMin);
  Duration get _remain => _end != null ? _end!.difference(DateTime.now()) : (_paused ?? _total);

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    _end = DateTime.now().add(_paused ?? _total);
    _paused = null;
    final what = _task.text.trim();
    NotificationService.instance.scheduleFocusEnd(_end,
        title: _break ? '☕ Istirahat selesai' : '✅ Sesi fokus selesai',
        body: _break ? 'Siap lanjut fokus lagi?' : 'Kerja bagus${what.isEmpty ? '' : ' mengerjakan "$what"'}! Waktunya istirahat $_breakMin menit.');
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_remain <= Duration.zero) {
        _finish();
      } else {
        setState(() {});
      }
    });
    setState(() {});
  }

  void _pause() {
    _t?.cancel();
    _paused = _remain;
    _end = null;
    NotificationService.instance.scheduleFocusEnd(null);
    setState(() {});
  }

  void _reset() {
    _t?.cancel();
    _end = null;
    _paused = null;
    _break = false;
    NotificationService.instance.scheduleFocusEnd(null);
    setState(() {});
  }

  void _finish() {
    _t?.cancel();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    setState(() {
      if (!_break) _sessions++;
      _break = !_break;
      _end = null;
      _paused = null;
    });
    showToast(context, _break ? 'Sesi selesai! Istirahat $_breakMin menit ☕' : 'Istirahat selesai, yuk fokus lagi 💪');
  }

  @override
  Widget build(BuildContext context) {
    final r = _remain.isNegative ? Duration.zero : _remain;
    final progress = 1 - r.inMilliseconds / _total.inMilliseconds;
    final color = _break ? const Color(0xFF12A150) : AppColors.primary;
    final running = _end != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Timer fokus'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Wrap(spacing: 8, children: [
            for (var i = 0; i < _modes.length; i++)
              ChoiceChip(
                label: Text('${_modes[i].$3} ${_modes[i].$1}/${_modes[i].$2}'),
                selected: _m == i,
                onSelected: running ? null : (_) => setState(() {
                  _m = i;
                  _paused = null;
                  _break = false;
                }),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _task,
            enabled: !running,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.edit_note_rounded),
              hintText: 'Mau fokus mengerjakan apa?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(value: progress.clamp(0, 1).toDouble(), strokeWidth: 14, color: color, backgroundColor: color.withValues(alpha: .12), strokeCap: StrokeCap.round),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_break ? 'ISTIRAHAT' : 'FOKUS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, color: color)),
                  Text('${r.inMinutes.toString().padLeft(2, '0')}:${(r.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: accentFont(size: 56, color: context.ink)),
                  Text('$_sessions sesi selesai', style: TextStyle(color: context.muted)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: SoftButton(label: 'Ulang', icon: Icons.restart_alt_rounded, onPressed: _reset)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GradientButton(label: running ? 'Jeda' : (_paused != null ? 'Lanjut' : 'Mulai'), icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded, onPressed: running ? _pause : _start),
            ),
          ]),
          const SizedBox(height: 20),
          Text(
            _break
                ? 'Saat istirahat: berdiri, minum air, lihat jauh ke luar jendela, atau coba latihan napas.'
                : 'Tips: taruh HP menjauh, tutup tab yang tidak perlu, dan kerjakan SATU hal saja sampai timer selesai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted, height: 1.4),
          ),
          if (_break) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BreatheScreen())),
                icon: const Icon(Icons.air_rounded),
                label: const Text('Latihan napas'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Lingkaran kecil berwarna untuk grafik mood.
double moodY(int mood) => mood.toDouble();
double clampD(double v, double a, double b) => math.max(a, math.min(b, v));
