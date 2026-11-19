import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/calorie_provider.dart';
import '../../../providers/workout_provider.dart';
import '../../../services/workout_logic.dart';
import '../../widgets/common.dart';
import '../../../services/calorie_logic.dart';
import '../calorie/calorie_screen.dart';
import '../calorie/weight_screen.dart';
import 'exercise_figure.dart';
import 'workout_player.dart';

/// Warna fitur Olahraga (lihat FeatureColors.workout) — satu aksen, gradasi lembut satu warna.
const kOla = Color(0xFFE11D48);
const kOlaGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA21534), Color(0xFFE11D48)]);
const kNavy = Color(0xFF111633);
const kNavyGradient = kOlaGradient;
const kBlueGradient = kOlaGradient;
const kFireGradient = kOlaGradient;
const kBlue = Color(0xFFE11D48);
const levelNames = ['', 'Pemula', 'Menengah', 'Lanjut'];
const levelColors = [Color(0xFF94A3B8), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFE11D48)];

String figureOf(WorkoutProgram p) => programFigure[p.id] ?? p.items.first.$1;

/// Judul/angka besar di fitur Olahraga — tebal tapi tenang (bukan huruf poster).
TextStyle olaDisplay(double size, {Color color = Colors.white, double spacing = .3}) =>
    TextStyle(fontSize: size * .72, fontWeight: FontWeight.w700, color: color, height: 1.15, letterSpacing: -.2);

String fmtClock(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
String amountLabel(Exercise e, int a) => e.timed ? fmtClock(a) : '$a kali';
String fmtNum(double v) => v.round().toString();
double? bodyKg(WidgetRef ref) => ref.read(calorieProvider).profile?.kg;

void openProgram(BuildContext context, WorkoutProgram p, {double mult = 1, String? logProgram, String? title}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgramScreen(program: p, mult: mult, logProgram: logProgram, title: title)));

/// Tombol besar membulat (MULAI).
class BigStartButton extends StatelessWidget {
  const BigStartButton({super.key, required this.label, required this.onTap, this.height = 58, this.gradient = kBlueGradient, this.textColor = Colors.white, this.icon});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Gradient? gradient;
  final Color textColor;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? Colors.white : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, color: textColor, size: 22), const SizedBox(width: 8)],
                    Text(label, maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pita miring merah-oranye.
class OlaRibbon extends StatelessWidget {
  const OlaRibbon(this.text, {super.key, this.icon = Icons.home_rounded});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _RibbonClip(),
        child: Container(
          height: 42,
          padding: const EdgeInsets.fromLTRB(16, 0, 34, 0),
          decoration: const BoxDecoration(gradient: kFireGradient),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr(text).toUpperCase(), maxLines: 1, style: olaDisplay(24, spacing: .8)))),
          ]),
        ),
      );
}

class _RibbonClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width, 0)
    ..lineTo(s.width - 18, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Kotak ilustrasi gerakan berlatar lembut.
class FigureTile extends StatelessWidget {
  const FigureTile(this.id, {super.key, this.animate = false, this.radius = 16, this.padding = 4});
  final String id;
  final bool animate;
  final double radius, padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.isDark ? [const Color(0xFF1E293B), const Color(0xFF172036)] : [const Color(0xFFF1F5FD), const Color(0xFFE3EBFA)],
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ExerciseFigure(id, animate: animate),
      );
}

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, this.focusProgram});
  final String? focusProgram;
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  String _area = 'perut';
  String _cat = 'perut';

  @override
  void initState() {
    super.initState();
    final f = widget.focusProgram;
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final p = programById(f);
        if (p != null && mounted) openProgram(context, p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(workoutProvider);
    final kg = ref.watch(calorieProvider).profile?.kg;
    final now = DateTime.now();
    final list = exercises.where((x) => x.area == _area).toList();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _hero(context, s, now)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ChallengeCard(kg: kg),
              const SizedBox(height: 12),
              _BellyInfo(onCalorie: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalorieScreen()))),
              _title(context, 'Berat badan', sub: 'Pantau hasil latihan & dietmu'),
              const WeightProgressCard(),
              _title(context, 'Disarankan untukmu', sub: _recoWhy(ref)),
              SizedBox(
                height: 132,
                child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
                  for (final id in _reco(ref)) Padding(padding: const EdgeInsets.only(right: 10), child: _MiniProgram(programById(id)!, kg: kg)),
                ]),
              ),
              _title(context, 'Program latihan', sub: '${workoutPrograms.length} program · ${exercises.length} gerakan, semua tanpa alat'),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in [...programCategories, ('semua', 'Semua')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.$2),
                        selected: _cat == c.$1,
                        showCheckmark: false,
                        selectedColor: kNavy,
                        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _cat == c.$1 ? Colors.white : context.ink),
                        onSelected: (_) => setState(() => _cat = c.$1),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              for (final p in workoutPrograms)
                if (_cat == 'semua' || programCategory[p.id] == _cat) _ProgramCard(p, kg: kg),
              _title(context, 'Semua gerakan', sub: 'Ketuk untuk melihat cara lengkapnya'),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final e in exerciseAreas.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _area == e.key,
                        showCheckmark: false,
                        selectedColor: kBlue,
                        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _area == e.key ? Colors.white : context.ink),
                        onSelected: (_) => setState(() => _area = e.key),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, c) {
                final w = (c.maxWidth - 10) / 2;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  for (var i = 0; i < list.length; i++)
                    SizedBox(
                      width: w,
                      child: SoftCard(
                        radius: 18,
                        padding: const EdgeInsets.all(8),
                        onTap: () => showExerciseDetail(context, list, index: i),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FigureTile(list[i].id, radius: 13),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(list[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 1, 4, 2),
                            child: Text('${amountLabel(list[i], list[i].amount)} · ${levelNames[list[i].level]}', style: TextStyle(color: context.muted, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ),
                ]);
              }),
              _title(context, 'Riwayat', action: '+ Catat aktivitas', onAction: () => logActivitySheet(context, ref)),
              if (s.logs.isEmpty)
                SoftCard(
                  child: Text('Belum ada catatan. Mulai satu program di atas, atau catat jalan kaki, lari, renang dll. lewat "+ Catat aktivitas" — bisa juga lewat chat: "tadi jogging 30 menit".',
                      style: TextStyle(color: context.muted, height: 1.4)),
                )
              else
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  radius: 20,
                  child: Column(children: [
                    for (final l in s.logs.take(12))
                      Dismissible(
                        key: ValueKey(l.id),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFE11D48), child: const Icon(Icons.delete_rounded, color: Colors.white)),
                        onDismissed: (_) => ref.read(workoutProvider.notifier).remove(l.id),
                        child: ListTile(
                          leading: Text(l.emoji, style: const TextStyle(fontSize: 24)),
                          title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${sameDay(l.at, now) ? 'Hari ini' : fmtDateShort(l.at)} · ${fmtTime(l.at)} · ${(l.secs / 60).round()} menit'),
                          trailing: Text('${fmtNum(l.kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w800, color: kOla)),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 10),
              Text('Geser riwayat ke kiri untuk menghapus. Hentikan latihan bila terasa nyeri, pusing atau sesak. Sedang hamil, punya penyakit jantung, tekanan darah tinggi atau cedera? Konsultasikan dulu dengan dokter.',
                  style: TextStyle(fontSize: 11.5, color: context.faint, height: 1.4)),
            ]),
          ),
        ),
      ]),
    );
  }

  List<String> _reco(WidgetRef ref) {
    final p = ref.read(calorieProvider).profile;
    return Workout.recommend(kg: p?.kg, cm: p?.cm, age: p?.age, goal: p?.goal, weekMinutes: ref.read(workoutProvider).weekMinutes, hour: DateTime.now().hour);
  }

  String _recoWhy(WidgetRef ref) {
    final p = ref.read(calorieProvider).profile;
    if (p == null) return 'Isi profil tubuh di Kalori agar saran lebih pas';
    if (p.age >= 60) return 'Sesuai usiamu — aman & ringan';
    if (Body.bmi(p.kg, p.cm) > 27) return 'Ramah lutut, tanpa lompat — cocok untuk mulai menurunkan berat';
    if (p.goal == 'turun') return 'Untuk menurunkan berat badan';
    if (p.goal == 'naik') return 'Untuk menambah massa otot';
    return 'Sesuai profil & waktu sekarang';
  }

  Widget _title(BuildContext context, String t, {String? sub, String? action, VoidCallback? onAction}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(t).toUpperCase(), style: olaDisplay(24, color: context.ink, spacing: .6)),
              if (sub != null) Text(sub, style: TextStyle(color: context.muted, fontSize: 12.5)),
            ]),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _hero(BuildContext context, WorkoutState s, DateTime now) {
    final week = s.weekMinutes, goal = s.weeklyGoal;
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, color: context.ink)),
          Expanded(child: Text('Olahraga', style: TextStyle(color: context.ink, fontWeight: FontWeight.w700, fontSize: 19))),
          IconButton(
            tooltip: tr('Pengingat olahraga'),
            onPressed: () => _reminder(context),
            icon: Icon(s.reminderHour == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, color: context.ink),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: FeatureHero(
            color: FeatureColors.workout,
            label: 'Tanpa alat · di rumah',
            title: 'Olahraga di rumah',
            subtitle: week >= goal ? 'Target mingguan tercapai! 🏆' : 'Target WHO: $goal menit seminggu · sisa ${goal - week} menit',
            trailing: const SizedBox(width: 78, height: 78, child: ExerciseFigure('jumping_jack', matColor: Color(0x33FFFFFF))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _stat('$week', '/ $goal menit\nminggu ini'),
                _stat(fmtNum(s.kcalOn(now)), 'kkal terbakar\nhari ini'),
                _stat('${s.streak}', 'hari\nberturut-turut'),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (week / goal).clamp(0, 1).toDouble(), minHeight: 6, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: .22)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, translate: false, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 2),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w500)),
        ]),
      );

  Future<void> _reminder(BuildContext context) async {
    final s = ref.read(workoutProvider);
    final n = ref.read(workoutProvider.notifier);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour ?? 6, minute: s.reminderMinute),
      helpText: tr('Ingatkan olahraga tiap hari jam'),
      cancelText: s.reminderHour != null ? 'Matikan' : 'Batal',
    );
    if (t == null) {
      if (s.reminderHour != null) {
        await n.setReminder(null);
        if (context.mounted) showToast(context, 'Pengingat olahraga dimatikan');
      }
      return;
    }
    await n.setReminder(t.hour, t.minute);
    if (context.mounted) showToast(context, 'Diingatkan olahraga tiap hari jam ${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')} 🏃');
  }
}

class _BellyInfo extends StatefulWidget {
  const _BellyInfo({required this.onCalorie});
  final VoidCallback onCalorie;
  @override
  State<_BellyInfo> createState() => _BellyInfoState();
}

class _BellyInfoState extends State<_BellyInfo> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      onTap: () => setState(() => _open = !_open),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
            child: const Text('💡', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cara benar mengecilkan perut', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Baca dulu sebelum mulai', style: TextStyle(fontSize: 12)),
            ]),
          ),
          AnimatedRotation(turns: _open ? .5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: context.muted)),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final t in const [
                      ('🔥', 'Sit-up saja tidak membakar lemak perut. Lemak berkurang dari seluruh tubuh saat kalori yang keluar lebih banyak dari yang masuk.'),
                      ('🍽️', 'Atur makan: sedikit di bawah kebutuhan (lihat target di fitur Kalori), kurangi gula & gorengan, perbanyak protein dan sayur.'),
                      ('🏃', 'Kardio 3–5× seminggu (jalan cepat, jogging, program "Kardio bakar lemak") untuk membakar kalori.'),
                      ('💪', 'Latihan perut & kekuatan 3× seminggu supaya otot perut kencang dan postur tegak — perut tampak lebih rata.'),
                      ('😴', 'Tidur 7–8 jam & kelola stres: kurang tidur dan stres membuat lemak perut lebih sulit turun.'),
                      ('📅', 'Sabar & konsisten: turun 0,5 kg per minggu itu sehat. Hasil terlihat dalam 4–8 minggu.'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.$1, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t.$2, style: TextStyle(color: context.muted, height: 1.45, fontSize: 13.5))),
                        ]),
                      ),
                    TextButton.icon(onPressed: widget.onCalorie, icon: const Icon(Icons.restaurant_rounded, size: 18), label: const Text('Atur target kalori')),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.kg});
  final double? kg;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(workoutProvider);
    final day = s.challengeDay;
    final done = s.challengeDone;
    final started = s.challengeStart != null;
    final finished = started && day == null && done.length >= 20;
    final week = day == null ? 0 : (day - 1) ~/ 7;
    final (pid, mult) = bellyChallenge[week.clamp(0, 3)];
    final p = programById(pid)!;
    final todayDone = day != null && done.contains(day);
    final rest = day != null && day % 7 == 0; // hari ke-7 tiap minggu: istirahat
    const c = FeatureColors.workout;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Stack(children: [
        Positioned(right: 4, top: 10, width: 110, child: ExerciseFigure('crunch', matColor: c.withValues(alpha: .12))),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconTile(icon: Icons.emoji_events_outlined, color: c, size: 32),
              const SizedBox(width: 8),
              Text('Tantangan 28 hari', style: TextStyle(color: context.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            Text(!started ? 'Perut rata' : finished ? 'Selesai! 🏆' : 'Hari ke-${day ?? 28}', style: TextStyle(color: context.ink, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 100),
              child: Text(!started ? '6 hari latihan + 1 hari istirahat tiap minggu, makin berat bertahap' : '${done.length} hari selesai · minggu ${week + 1}: ${p.name.split(' — ').first}',
                  style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4)),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (var d = 1; d <= 28; d++)
                Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done.contains(d) ? c : (d % 7 == 0 ? context.card2.withValues(alpha: .5) : context.card2),
                    border: d == day ? Border.all(color: c, width: 2) : null,
                  ),
                  child: done.contains(d)
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text(d % 7 == 0 ? '😴' : '$d', style: TextStyle(fontSize: d % 7 == 0 ? 12 : 11.5, fontWeight: FontWeight.w600, color: context.muted)),
                ),
            ]),
            const SizedBox(height: 16),
            if (!started || finished)
              BigStartButton(
                label: finished ? 'Ulangi tantangan' : 'Mulai tantangan',
                gradient: FeatureColors.hero(c),
                height: 50,
                onTap: () => ref.read(workoutProvider.notifier).startChallenge(),
              )
            else if (rest)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(14)),
                child: Text('😴 Hari ini istirahat — otot tumbuh saat beristirahat. Boleh jalan santai atau peregangan.', style: TextStyle(color: context.ink, height: 1.4)),
              )
            else
              BigStartButton(
                label: todayDone ? 'Sudah ✓ · ulangi' : 'Mulai · ${(Workout.seconds(p, mult: mult) / 60).round()} menit',
                gradient: FeatureColors.hero(c),
                height: 50,
                onTap: () => openProgram(context, p, mult: mult, logProgram: 'tantangan_$day', title: 'Tantangan hari ke-$day'),
              ),
            if (started)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (await confirmDialog(context, title: 'Hentikan tantangan?', message: 'Progres tantangan akan diulang dari awal.', ok: 'Hentikan', danger: true)) {
                      ref.read(workoutProvider.notifier).stopChallenge();
                    }
                  },
                  child: Text('Hentikan', style: TextStyle(color: context.muted)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard(this.p, {required this.kg});
  final WorkoutProgram p;
  final double? kg;
  @override
  Widget build(BuildContext context) {
    final c = Color(p.color);
    final parts = p.name.split(' — ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(10),
        onTap: () => openProgram(context, p),
        child: Row(children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: c.withValues(alpha: context.isDark ? .18 : .09), borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(6),
            child: ExerciseFigure(figureOf(p), animate: false, matColor: c.withValues(alpha: .18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.emoji} ${tr(parts.length > 1 ? parts[1] : levelNames[p.level])}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(parts.first, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 6),
              Text('${(Workout.seconds(p) / 60).round()} menit · ${p.items.length} gerakan · ${fmtNum(Workout.kcal(p, kg))} kkal', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: context.faint),
        ]),
      ),
    );
  }
}

class _MiniProgram extends StatelessWidget {
  const _MiniProgram(this.p, {required this.kg});
  final WorkoutProgram p;
  final double? kg;
  @override
  Widget build(BuildContext context) {
    final c = Color(p.color);
    return SizedBox(
      width: 230,
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        onTap: () => openProgram(context, p),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(levelNames[p.level], style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Expanded(child: Text(p.name.split(' — ').first, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w700, height: 1.25))),
              Text('${(Workout.seconds(p) / 60).round()} mnt · ${fmtNum(Workout.kcal(p, kg))} kkal', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12)),
            ]),
          ),
          Container(
            width: 72,
            decoration: BoxDecoration(color: c.withValues(alpha: context.isDark ? .18 : .09), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: ExerciseFigure(figureOf(p), animate: false, matColor: c.withValues(alpha: .18)),
          ),
        ]),
      ),
    );
  }
}

/// ---------- Detail program ----------
class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key, required this.program, this.mult = 1, this.logProgram, this.title});
  final WorkoutProgram program;
  final double mult;
  final String? logProgram, title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = program;
    final kg = ref.watch(calorieProvider).profile?.kg;
    final day = RegExp(r'hari ke-(\d+)').firstMatch(title ?? '')?.group(1);
    final small = day != null ? 'Tantangan perut 28 hari' : '${levelNames[p.level]} · ${p.rounds} ronde';
    final big = day != null ? 'Hari ke-$day' : p.name.split(' — ').first;
    final items = [
      for (final it in p.items) (exerciseById(it.$1), ((it.$2 > 0 ? it.$2 : exerciseById(it.$1).amount) * mult).round()),
    ];
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 300,
          backgroundColor: const Color(0xFFA21534),
          foregroundColor: Colors.white,
          title: Text(title ?? p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(gradient: kOlaGradient),
              child: SafeArea(
                child: Stack(children: [
                  Positioned(right: 8, top: 54, width: 190, child: ExerciseFigure(figureOf(p), matColor: Colors.white.withValues(alpha: .25))),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(small, style: olaDisplay(18, color: Colors.white.withValues(alpha: .8), spacing: 1.4)),
                      const SizedBox(height: 4),
                      Text(big, maxLines: 2, style: olaDisplay(50)),
                      const SizedBox(height: 14),
                      Row(children: [
                        _stat('${(Workout.seconds(p, mult: mult) / 60).round()}', 'menit'),
                        _stat(fmtNum(Workout.kcal(p, kg, mult: mult)), 'kkal'),
                        _stat('${p.items.length}', 'gerakan'),
                        _stat('${p.rounds}', 'ronde'),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(p.desc, style: TextStyle(color: context.muted, height: 1.4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Row(children: [
                  Text('${p.items.length} gerakan', style: olaDisplay(22, color: context.ink)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Ulangi ${p.rounds}× · istirahat ${p.rest} dtk',
                        textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ),
                ]),
              ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    radius: 18,
                    padding: const EdgeInsets.all(8),
                    onTap: () => showExerciseDetail(context, [for (final x in items) x.$1], index: i, amounts: [for (final x in items) x.$2]),
                    child: Row(children: [
                      SizedBox(width: 112, child: FigureTile(items[i].$1.id, radius: 13)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(items[i].$1.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(amountLabel(items[i].$1, items[i].$2), style: olaDisplay(22, color: context.ink, spacing: .5)),
                          const SizedBox(height: 2),
                          Text(items[i].$1.muscles.take(2).join(' · '), style: TextStyle(color: context.muted, fontSize: 12)),
                        ]),
                      ),
                      Icon(Icons.info_outline_rounded, color: context.faint, size: 20),
                      const SizedBox(width: 6),
                    ]),
                  ),
                ),
              Text('Ketuk gerakan untuk melihat animasi & cara lengkapnya.', textAlign: TextAlign.center, style: TextStyle(color: context.faint, fontSize: 12)),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: BigStartButton(
          label: 'Mulai',
          icon: Icons.play_arrow_rounded,
          height: 60,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => WorkoutPlayer(program: p, mult: mult, logProgram: logProgram ?? p.id, title: title ?? p.name),
          )),
        ),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: olaDisplay(28)),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// ---------- Cara melakukan gerakan (bisa digeser ke gerakan lain) ----------
Future<void> showExerciseDetail(BuildContext context, List<Exercise> list, {int index = 0, List<int>? amounts}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseDetailScreen(list: list, index: index, amounts: amounts)));

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.list, this.index = 0, this.amounts});
  final List<Exercise> list;
  final int index;
  final List<int>? amounts;
  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  late final PageController _pc = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int d) => _pc.animateToPage(_i + d, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final n = widget.list.length;
    final e = widget.list[_i];
    return Scaffold(
      appBar: AppBar(
        title: Text(n > 1 ? 'Gerakan ${_i + 1} dari $n' : 'Cara melakukan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: n,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => _ExercisePage(widget.list[i], widget.amounts?[i] ?? widget.list[i].amount),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          if (n > 1) _nav(Icons.chevron_left_rounded, _i > 0 ? () => _go(-1) : null),
          if (n > 1) const SizedBox(width: 10),
          Expanded(
            child: BigStartButton(
              label: 'Latih gerakan',
              height: 56,
              icon: Icons.play_arrow_rounded,
              onTap: () {
                final single = WorkoutProgram('single_${e.id}', e.name, e.emoji, 0xFF2563EB, e.level, '', 20, 3, [(e.id, widget.amounts?[_i] ?? 0)]);
                Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => WorkoutPlayer(program: single, logProgram: 'single', title: e.name)));
              },
            ),
          ),
          if (n > 1) const SizedBox(width: 10),
          if (n > 1) _nav(Icons.chevron_right_rounded, _i < n - 1 ? () => _go(1) : null),
        ]),
      ),
    );
  }

  Widget _nav(IconData ic, VoidCallback? onTap) => SizedBox(
        width: 54,
        height: 54,
        child: IconButton.filledTonal(onPressed: onTap, icon: Icon(ic, size: 30)),
      );
}

class _ExercisePage extends ConsumerStatefulWidget {
  const _ExercisePage(this.e, this.amount);
  final Exercise e;
  final int amount;
  @override
  ConsumerState<_ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<_ExercisePage> {
  bool _slow = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final kg = ref.watch(calorieProvider).profile?.kg;
    final perMin = Workout.burn(e.met, kg, 60);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      // ilustrasi animasi
      Container(
        height: 250,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.isDark ? [const Color(0xFF1E293B), const Color(0xFF14203A)] : [const Color(0xFFF1F5FD), const Color(0xFFDCE7FA)],
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(children: [
          Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(10, 26, 10, 6), child: ExerciseFigure(e.id, speed: _slow ? .45 : 1))),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(99)),
              child: Text(tr(exerciseAreas[e.area]!).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
            ),
          ),
          Positioned(
            right: 8,
            top: 6,
            child: TextButton.icon(
              onPressed: () => setState(() => _slow = !_slow),
              icon: Icon(_slow ? Icons.speed_rounded : Icons.slow_motion_video_rounded, size: 18),
              label: Text(_slow ? 'Normal' : 'Pelan'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(tr(e.name).toUpperCase(), style: olaDisplay(36, color: context.ink)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(context, e.timed ? Icons.timer_outlined : Icons.repeat_rounded, e.timed ? amountLabel(e, widget.amount) : '${widget.amount} kali', kBlue),
        _chip(context, Icons.signal_cellular_alt_rounded, levelNames[e.level], levelColors[e.level]),
        _chip(context, Icons.local_fire_department_rounded, '±${perMin.toStringAsFixed(1).replaceAll('.', ',')} kkal/menit', kOla),
      ]),
      const SizedBox(height: 18),
      _head(context, 'Otot yang dilatih'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in e.muscles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: kBlue.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
            child: Text(m, style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ]),
      const SizedBox(height: 18),
      _head(context, 'Cara melakukan'),
      for (var i = 0; i < e.steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: kBlueGradient, shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(e.steps[i], style: const TextStyle(height: 1.45, fontSize: 15)))),
          ]),
        ),
      const SizedBox(height: 6),
      _note(context, '💨', 'Pernapasan', e.breath, const Color(0xFF0EA5E9)),
      _note(context, '✅', 'Tips', e.tip, const Color(0xFF10B981)),
      _note(context, '⚠️', 'Kesalahan umum', e.mistake, const Color(0xFFF59E0B)),
      if (e.caution.isNotEmpty) _note(context, '🩺', 'Perhatian', e.caution, const Color(0xFFE11D48)),
    ]);
  }

  Widget _head(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(tr(t).toUpperCase(), style: olaDisplay(20, color: context.ink, spacing: .8)),
      );

  Widget _chip(BuildContext context, IconData ic, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 17, color: c),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );
}

Widget _note(BuildContext ctx, String emoji, String title, String text, Color c) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$title: ', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            TextSpan(text: text),
          ]), style: const TextStyle(height: 1.4, fontSize: 13.5)),
        ),
      ]),
    );

/// ---------- Catat aktivitas bebas (jalan, lari, renang, ...) ----------
Future<void> logActivitySheet(BuildContext context, WidgetRef ref, {String? name, int minutes = 30}) async {
  var sel = freeActivities.indexWhere((a) => a.$2 == name);
  if (sel < 0) sel = 0;
  var min = minutes;
  await showAppSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final a = freeActivities[sel];
      final kcal = Workout.burn(a.$3, bodyKg(ref), min * 60);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CATAT AKTIVITAS', style: olaDisplay(26, color: ctx.ink)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < freeActivities.length; i++)
              ChoiceChip(
                label: Text(freeActivities[i].$2),
                selected: sel == i,
                showCheckmark: false,
                selectedColor: kBlue,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: sel == i ? Colors.white : ctx.ink),
                onSelected: (_) => setS(() => sel = i),
              ),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(onPressed: min > 5 ? () => setS(() => min -= 5) : null, icon: const Icon(Icons.remove_rounded)),
            SizedBox(width: 150, child: Text('$min MENIT', textAlign: TextAlign.center, style: olaDisplay(34, color: ctx.ink))),
            IconButton.filledTonal(onPressed: min < 600 ? () => setS(() => min += 5) : null, icon: const Icon(Icons.add_rounded)),
          ]),
          const SizedBox(height: 8),
          Text('🔥 ±${fmtNum(kcal)} kkal terbakar', textAlign: TextAlign.center, style: const TextStyle(color: kOla, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          BigStartButton(
            label: 'Simpan',
            height: 54,
            onTap: () async {
              await ref.read(workoutProvider.notifier).add(name: a.$2, secs: min * 60, kcal: kcal, emoji: '🏅');
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) showToast(context, '${a.$2} $min menit dicatat · 🔥 ${fmtNum(kcal)} kkal');
            },
          ),
        ]),
      );
    }),
  );
}
