import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../providers/calorie_provider.dart';
import '../../../providers/workout_provider.dart';
import '../../../services/workout_logic.dart';
import '../../widgets/common.dart';
import '../calorie/calorie_screen.dart';
import 'workout_player.dart';

const kOla = Color(0xFFF97316);
const kOlaGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFB923C), Color(0xFFE11D48)]);
const levelNames = ['', 'Pemula', 'Menengah', 'Lanjut'];
const levelColors = [Color(0xFF94A3B8), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFE11D48)];

double? bodyKg(WidgetRef ref) => ref.read(calorieProvider).profile?.kg;

void openProgram(BuildContext context, WorkoutProgram p, {double mult = 1, String? logProgram, String? title}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgramScreen(program: p, mult: mult, logProgram: logProgram, title: title)));

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, this.focusProgram});
  final String? focusProgram;
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  String _area = 'perut';

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
    final week = s.weekMinutes;
    final goal = s.weeklyGoal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olahraga'),
        centerTitle: false,
        actions: [IconButton(tooltip: 'Pengingat olahraga', onPressed: () => _reminder(context), icon: Icon(s.reminderHour == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        // ---- ringkasan
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: kOlaGradient, borderRadius: BorderRadius.circular(26), boxShadow: [
            BoxShadow(color: kOla.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12),
          ]),
          child: Row(children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (week / goal).clamp(0, 1).toDouble(),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: .25),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$week', style: accentFont(size: 28, color: Colors.white)),
                  Text('/ $goal mnt', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Minggu ini', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                Text(week >= goal ? 'Target tercapai! 🏆' : 'Sisa ${goal - week} menit lagi', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _chip('🔥 ${fmtNum(s.kcalOn(now))} kkal hari ini'),
                const SizedBox(height: 6),
                _chip(s.streak > 0 ? '⚡ ${s.streak} hari berturut-turut' : '⚡ Mulai streak hari ini'),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _BellyInfo(onCalorie: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalorieScreen()))),
        // ---- tantangan
        const SectionHeader('Tantangan 4 minggu perut'),
        _ChallengeCard(kg: kg),
        // ---- program
        const SectionHeader('Program latihan'),
        for (final p in workoutPrograms) _ProgramTile(p, kg: kg),
        // ---- gerakan
        const SectionHeader('Cara gerakan'),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final e in exerciseAreas.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _area == e.key,
                  selectedColor: kOla.withValues(alpha: .18),
                  onSelected: (_) => setState(() => _area = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: 20,
          child: Column(children: [
            for (final e in exercises.where((x) => x.area == _area))
              ListTile(
                onTap: () => showExerciseDetail(context, ref, e),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: kOla.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)),
                  alignment: Alignment.center,
                  child: Text(e.emoji, style: const TextStyle(fontSize: 22)),
                ),
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${Workout.amountText(e, e.amount)} · ${levelNames[e.level]}'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
          ]),
        ),
        // ---- aktivitas lain
        SectionHeader('Riwayat', action: '+ Catat aktivitas', onAction: () => logActivitySheet(context, ref)),
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
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Future<void> _reminder(BuildContext context) async {
    final s = ref.read(workoutProvider);
    final n = ref.read(workoutProvider.notifier);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour ?? 6, minute: s.reminderMinute),
      helpText: 'Ingatkan olahraga tiap hari jam',
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

String fmtNum(double v) => v.round().toString();

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
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Cara benar mengecilkan perut', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          AnimatedRotation(turns: _open ? .5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: context.muted)),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final t in const [
                      '1. Sit-up saja tidak membakar lemak perut. Lemak berkurang dari seluruh tubuh saat kalori yang keluar lebih banyak dari yang masuk.',
                      '2. Atur makan: makan sedikit di bawah kebutuhan (lihat target di fitur Kalori), kurangi gula & gorengan, perbanyak protein dan sayur.',
                      '3. Kardio 3–5× seminggu (jalan cepat, jogging, program "Kardio bakar lemak") untuk membakar kalori.',
                      '4. Latihan perut & kekuatan 3× seminggu supaya otot perut kencang dan postur tegak — perut tampak lebih rata.',
                      '5. Tidur 7–8 jam & kelola stres: kurang tidur dan stres membuat lemak perut lebih sulit turun.',
                      '6. Sabar & konsisten: turun 0,5 kg per minggu itu sehat. Hasil terlihat dalam 4–8 minggu.',
                    ])
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(color: context.muted, height: 1.45, fontSize: 13.5))),
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
    return SoftCard(
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: kOlaGradient, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Text('🔥', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(!started ? '28 hari perut lebih rata' : finished ? 'Tantangan selesai! 🏆' : 'Hari ke-${day ?? 28} dari 28',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(!started ? 'Latihan bertahap, 6 hari seminggu + 1 hari istirahat' : '${done.length} hari selesai · minggu ${week + 1}: ${p.name.split(' — ').first}',
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 5, runSpacing: 5, children: [
          for (var d = 1; d <= 28; d++)
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done.contains(d) ? kOla : (d % 7 == 0 ? context.card2 : null),
                border: Border.all(color: d == day ? kOla : context.line, width: d == day ? 2 : 1),
              ),
              child: Text(d % 7 == 0 ? '😴' : '$d',
                  style: TextStyle(fontSize: d % 7 == 0 ? 12 : 11.5, fontWeight: FontWeight.w700, color: done.contains(d) ? Colors.white : context.muted)),
            ),
        ]),
        const SizedBox(height: 12),
        if (!started || finished)
          GradientButton(
            label: finished ? 'Ulangi tantangan' : 'Mulai tantangan',
            icon: Icons.play_arrow_rounded,
            onPressed: () => ref.read(workoutProvider.notifier).startChallenge(),
          )
        else if (rest)
          Text('😴 Hari ini istirahat — otot tumbuh saat beristirahat. Boleh jalan santai atau peregangan.', style: TextStyle(color: context.muted, height: 1.4))
        else
          GradientButton(
            label: todayDone ? 'Hari ini sudah ✓ — ulangi?' : 'Mulai hari ke-$day (${(Workout.seconds(p, mult: mult) / 60).round()} menit)',
            icon: Icons.play_arrow_rounded,
            onPressed: () => openProgram(context, p, mult: mult, logProgram: 'tantangan_$day', title: 'Tantangan hari ke-$day'),
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
              child: Text('Hentikan', style: TextStyle(color: context.faint)),
            ),
          ),
      ]),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile(this.p, {required this.kg});
  final WorkoutProgram p;
  final double? kg;
  @override
  Widget build(BuildContext context) {
    final c = Color(p.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        onTap: () => openProgram(context, p),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.withValues(alpha: .9), c], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(17),
            ),
            alignment: Alignment.center,
            child: Text(p.emoji, style: const TextStyle(fontSize: 27)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(p.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _tag('⏱ ${(Workout.seconds(p) / 60).round()} mnt', context.muted),
                _tag('🔥 ${fmtNum(Workout.kcal(p, kg))} kkal', context.muted),
                _tag(levelNames[p.level], levelColors[p.level]),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
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
    final c = Color(p.color);
    return Scaffold(
      appBar: AppBar(title: Text(title ?? p.name), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.withValues(alpha: .85), c]), borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 6),
            Text(p.desc, style: const TextStyle(color: Colors.white, height: 1.4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              _stat('${(Workout.seconds(p, mult: mult) / 60).round()}', 'menit'),
              _stat(fmtNum(Workout.kcal(p, kg, mult: mult)), 'kkal'),
              _stat('${p.items.length}', 'gerakan'),
              _stat('${p.rounds}', 'ronde'),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('Ulangi ${p.rounds} ronde · istirahat ${p.rest} detik antar gerakan', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
        ),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: 20,
          child: Column(children: [
            for (var i = 0; i < p.items.length; i++)
              () {
                final ex = exerciseById(p.items[i].$1);
                final a = ((p.items[i].$2 > 0 ? p.items[i].$2 : ex.amount) * mult).round();
                return ListTile(
                  onTap: () => showExerciseDetail(context, ref, ex),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
                    alignment: Alignment.center,
                    child: Text(ex.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  title: Text('${i + 1}. ${ex.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(ex.steps.first, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(Workout.amountText(ex, a), style: TextStyle(fontWeight: FontWeight.w800, color: c)),
                );
              }(),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Ketuk gerakan untuk melihat cara melakukannya.', style: TextStyle(color: context.faint, fontSize: 12)),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GradientButton(
          label: 'Mulai latihan',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => WorkoutPlayer(program: p, mult: mult, logProgram: logProgram ?? p.id, title: title ?? p.name),
          )),
        ),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// ---------- Cara melakukan gerakan ----------
Future<void> showExerciseDetail(BuildContext context, WidgetRef ref, Exercise e) => showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: BouncingEmoji(e.emoji, size: 64)),
          const SizedBox(height: 8),
          Text(e.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${exerciseAreas[e.area]} · ${levelNames[e.level]} · ${Workout.amountText(e, e.amount)}',
              textAlign: TextAlign.center, style: TextStyle(color: ctx.muted)),
          const SizedBox(height: 16),
          const Text('Cara melakukan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          for (var i = 0; i < e.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: kOla, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.steps[i], style: const TextStyle(height: 1.45))),
              ]),
            ),
          _note(ctx, '✅', 'Tips', e.tip, const Color(0xFF10B981)),
          _note(ctx, '⚠️', 'Kesalahan umum', e.mistake, const Color(0xFFF59E0B)),
          if (e.caution.isNotEmpty) _note(ctx, '🩺', 'Perhatian', e.caution, const Color(0xFFE11D48)),
          const SizedBox(height: 6),
          GradientButton(
            label: 'Latih gerakan ini',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              final single = WorkoutProgram('single_${e.id}', e.name, e.emoji, 0xFFF97316, e.level, '', 20, 3, [(e.id, 0)]);
              Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => WorkoutPlayer(program: single, logProgram: 'single', title: e.name),
              ));
            },
          ),
        ]),
      ),
    );

Widget _note(BuildContext ctx, String emoji, String title, String text, Color c) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
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

/// Emoji yang bergerak naik-turun (animasi sederhana gerakan).
class BouncingEmoji extends StatefulWidget {
  const BouncingEmoji(this.emoji, {super.key, this.size = 72, this.speed = 900});
  final String emoji;
  final double size;
  final int speed;
  @override
  State<BouncingEmoji> createState() => _BouncingEmojiState();
}

class _BouncingEmojiState extends State<BouncingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.speed))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)),
          child: Transform.scale(scale: 1 + .06 * _c.value, child: child),
        ),
        child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
      );
}

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
          const Text('Catat aktivitas', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < freeActivities.length; i++)
              ChoiceChip(label: Text(freeActivities[i].$2), selected: sel == i, selectedColor: kOla.withValues(alpha: .18), onSelected: (_) => setS(() => sel = i)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(onPressed: min > 5 ? () => setS(() => min -= 5) : null, icon: const Icon(Icons.remove_rounded)),
            SizedBox(width: 130, child: Text('$min menit', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            IconButton.filledTonal(onPressed: min < 600 ? () => setS(() => min += 5) : null, icon: const Icon(Icons.add_rounded)),
          ]),
          const SizedBox(height: 8),
          Text('🔥 ±${fmtNum(kcal)} kkal terbakar', textAlign: TextAlign.center, style: const TextStyle(color: kOla, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Simpan',
            onPressed: () async {
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
