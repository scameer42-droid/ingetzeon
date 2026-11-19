import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wellbeing_provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/wellbeing_logic.dart';
import '../../widgets/common.dart';
import 'calm_tools.dart';

/// Pusat fitur psikologi: mood, kebiasaan, fokus, napas, jurnal, tes, teman cerita.
class CalmScreen extends ConsumerWidget {
  const CalmScreen({super.key, this.onOpenChat});
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodProvider);
    final today = ref.read(moodProvider.notifier).today;
    final habits = ref.watch(habitsProvider);
    final settings = ref.watch(calmSettingsProvider);
    final tests = ref.watch(testsProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Ruang Tenang'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        // ---- kartu mood
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(gradient: kCalmGradient, borderRadius: BorderRadius.circular(20)),
          child: CustomPaint(
            painter: const HillsPainter(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(today == null ? 'Gimana perasaanmu hari ini?' : 'Mood hari ini: ${MoodAdvice.moodEmoji[today.mood - 1]} ${MoodAdvice.moodLabel[today.mood - 1]}',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              today == null ? 'Catat mood & energimu, nanti aku sarankan jadwal yang pas.' : 'Energi ${MoodAdvice.energyLabel[today.energy - 1].toLowerCase()} · ${MoodAdvice.forDay(today.mood, today.energy).title}',
              style: TextStyle(color: Colors.white.withValues(alpha: .9), height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _WhiteBtn(label: today == null ? 'Catat mood' : 'Ubah', icon: Icons.mood_rounded, onTap: () => showMoodCheckin(context, ref)),
              if (today != null) ...[const SizedBox(width: 8), _WhiteBtn(label: 'Saran jadwal', icon: Icons.tips_and_updates_rounded, onTap: () => showMoodAdvice(context, ref))],
            ]),
          ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // ---- alat
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .95,
          children: [
            _ToolTile(icon: Icons.forum_rounded, label: 'Teman cerita', color: kCalm, onTap: () => _openChat(context, ref)),
            _ToolTile(icon: Icons.air_rounded, label: 'Latihan napas', color: kCalm, onTap: () => openTool(context, ref, Tool.napas)),
            _ToolTile(icon: Icons.back_hand_rounded, label: 'Grounding', color: kCalm, onTap: () => openTool(context, ref, Tool.grounding)),
            _ToolTile(icon: Icons.timer_rounded, label: 'Timer fokus', color: kCalm, onTap: () => openTool(context, ref, Tool.fokus)),
            _ToolTile(icon: Icons.menu_book_rounded, label: 'Jurnal', color: kCalm, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalScreen()))),
            _ToolTile(icon: Icons.quiz_rounded, label: 'Tes psikologi', color: kCalm, onTap: () => openTool(context, ref, Tool.tes)),
          ],
        ),
        // ---- kebiasaan
        SectionHeader('Kebiasaan hari ini', action: 'Kelola', onAction: () => openTool(context, ref, 'kebiasaan')),
        if (habits.isEmpty)
          SoftCard(
            onTap: () => openTool(context, ref, 'kebiasaan'),
            child: Row(children: [
              const Text('🌱', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Text('Bangun kebiasaan baik: minum air, olahraga, tidur cukup… Ketuk untuk mulai.', style: TextStyle(color: context.muted, height: 1.4))),
            ]),
          )
        else
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [for (final h in habits) _HabitRow(habit: h, compact: true)]),
          ),
        // ---- grafik mood
        SectionHeader('Mood 7 hari terakhir'),
        SoftCard(child: SizedBox(height: 150, child: _MoodChart(moods: moods, now: now))),
        if (tests.isNotEmpty) ...[
          SectionHeader('Hasil tes terakhir', action: 'Tes lagi', onAction: () => openTool(context, ref, Tool.tes)),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final t in tests.take(3))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFD97706)),
                  title: Text(PsyTest.byId(t.test)?.title ?? t.test, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${t.level} · skor ${t.score}/${t.max} · ${fmtDateShort(t.at)}'),
                ),
            ]),
          ),
        ],
        // ---- pengingat
        SectionHeader('Pengingat'),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(children: [
            SwitchListTile(
              value: settings.checkin,
              onChanged: (v) => ref.read(calmSettingsProvider.notifier).save(settings.copyWith(checkin: v)),
              title: const Text('Cek mood pagi', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Setiap hari jam ${settings.checkinH.toString().padLeft(2, '0')}.00'),
              secondary: IconButton(
                icon: const Icon(Icons.schedule_rounded),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: settings.checkinH, minute: 0));
                  if (t != null) await ref.read(calmSettingsProvider.notifier).save(settings.copyWith(checkinH: t.hour, checkin: true));
                },
              ),
            ),
            SwitchListTile(
              value: settings.journal,
              onChanged: (v) => ref.read(calmSettingsProvider.notifier).save(settings.copyWith(journal: v)),
              title: const Text('Jurnal malam', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Setiap hari jam ${settings.journalH.toString().padLeft(2, '0')}.00'),
              secondary: IconButton(
                icon: const Icon(Icons.schedule_rounded),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: settings.journalH, minute: 0));
                  if (t != null) await ref.read(calmSettingsProvider.notifier).save(settings.copyWith(journalH: t.hour, journal: true));
                },
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const HelpCard(),
        const SizedBox(height: 12),
        Text(
          'Ruang Tenang membantu menjaga kesehatan mental sehari-hari, tetapi bukan pengganti psikolog, psikiater, atau dokter. '
          'Semua catatan mood, jurnal, dan hasil tes tersimpan di HP ini saja.',
          style: TextStyle(fontSize: 12, height: 1.45, color: context.faint),
        ),
      ]),
    );
  }

  void _openChat(BuildContext context, WidgetRef ref) {
    ref.read(chatProvider.notifier).startSupport();
    if (onOpenChat != null) {
      Navigator.of(context).pop();
      onOpenChat!();
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(openChatRequestProvider.notifier).state++;
    }
  }
}

class _WhiteBtn extends StatelessWidget {
  const _WhiteBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
      ]),
    );
  }
}

class _MoodChart extends StatelessWidget {
  const _MoodChart({required this.moods, required this.now});
  final List<MoodEntry> moods;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final byDay = {for (final m in moods) m.day: m};
    final spots = <FlSpot>[];
    final eSpots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final m = byDay[dayKey(days[i])];
      if (m != null) {
        spots.add(FlSpot(i.toDouble(), m.mood.toDouble()));
        eSpots.add(FlSpot(i.toDouble(), m.energy.toDouble()));
      }
    }
    if (spots.isEmpty) {
      return Center(child: Text('Belum ada catatan mood minggu ini', style: TextStyle(color: context.muted)));
    }
    return LineChart(LineChartData(
      minY: .5,
      maxY: 5.5,
      minX: -.3,
      maxX: 6.3,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (v, _) => v % 1 == 0 && v >= 1 && v <= 5 ? Text(MoodAdvice.moodEmoji[v.toInt() - 1], style: const TextStyle(fontSize: 13)) : const SizedBox.shrink(),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, _) => v % 1 == 0 && v >= 0 && v <= 6
                ? Text(hariShort[days[v.toInt()].weekday % 7], style: TextStyle(fontSize: 11, color: context.muted))
                : const SizedBox.shrink(),
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(spots: eSpots, isCurved: true, color: const Color(0xFFF59E0B).withValues(alpha: .6), barWidth: 2, dotData: const FlDotData(show: true), dashArray: [5, 4]),
        LineChartBarData(spots: spots, isCurved: true, color: kCalm, barWidth: 4, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: kCalm.withValues(alpha: .1))),
      ],
    ));
  }
}

/// ---------- Kebiasaan ----------
class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit, this.compact = false});
  final Habit habit;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = habit.doneOn(DateTime.now());
    final streak = habit.streak;
    return ListTile(
      leading: Text(habit.emoji, style: const TextStyle(fontSize: 26)),
      title: Text(habit.name, style: TextStyle(fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null, color: done ? context.muted : context.ink)),
      subtitle: Text([
        if (streak > 0) '🔥 $streak hari berturut-turut' else 'Belum ada streak',
        if (habit.hour != null) 'jam ${habit.hour.toString().padLeft(2, '0')}.${habit.minute.toString().padLeft(2, '0')}',
      ].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!compact)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: context.faint),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Hapus kebiasaan?', message: habit.name, ok: 'Hapus', danger: true);
              if (ok) await ref.read(habitsProvider.notifier).remove(habit.id);
            },
          ),
        GestureDetector(
          onTap: () => ref.read(habitsProvider.notifier).toggleToday(habit.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? const Color(0xFF12A150) : Colors.transparent,
              border: Border.all(color: done ? const Color(0xFF12A150) : context.line, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
          ),
        ),
      ]),
    );
  }
}

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final done = habits.where((h) => h.doneOn(DateTime.now())).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Kebiasaan'), centerTitle: false),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addHabit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kebiasaan'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        if (habits.isNotEmpty) ...[
          Text('$done dari ${habits.length} selesai hari ini', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: habits.isEmpty ? 0 : done / habits.length, minHeight: 10, color: const Color(0xFF12A150), backgroundColor: context.line),
          ),
          const SizedBox(height: 16),
          SoftCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final h in habits) _HabitRow(habit: h)])),
        ] else
          const EmptyState(title: 'Belum ada kebiasaan', subtitle: 'Mulai dari satu kebiasaan kecil — konsisten lebih penting daripada banyak.', icon: Icons.spa_rounded),
        const SizedBox(height: 16),
        Text('Kebiasaan kecil yang dilakukan tiap hari terbukti membantu suasana hati & energi. Mulai dari 1–3 saja.',
            style: TextStyle(fontSize: 12.5, color: context.faint, height: 1.4)),
      ]),
    );
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var emoji = '✅';
    int? hour = 8;
    await showAppSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kebiasaan baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in Habit.presets)
                ActionChip(
                  label: Text('${p.$1} ${p.$2}'),
                  onPressed: () => setS(() {
                    emoji = p.$1;
                    name.text = p.$2;
                    hour = p.$3;
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(prefixText: tr('$emoji  '), labelText: tr('Nama kebiasaan'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: hour != null,
              onChanged: (v) => setS(() => hour = v ? 8 : null),
              title: Text(hour == null ? 'Tanpa pengingat' : 'Ingatkan tiap hari jam ${hour.toString().padLeft(2, '0')}.00', style: const TextStyle(fontWeight: FontWeight.w600)),
              secondary: hour == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.schedule_rounded),
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: hour ?? 8, minute: 0));
                        if (t != null) setS(() => hour = t.hour);
                      },
                    ),
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Tambah',
              icon: Icons.add_rounded,
              onPressed: () async {
                final n = name.text.trim();
                if (n.isEmpty) return;
                await ref.read(habitsProvider.notifier).add(emoji, n, hour: hour);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// ---------- Jurnal ----------
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.write = false});
  final bool write;
  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.write) WidgetsBinding.instance.addPostFrameCallback((_) => _write());
  }

  Future<void> _write() async {
    var prompt = JournalEntry.promptOfDay();
    final text = TextEditingController();
    final saved = await showAppSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Jurnal hari ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton.icon(
                onPressed: () => setS(() {
                  final i = JournalEntry.prompts.indexOf(prompt);
                  prompt = JournalEntry.prompts[(i + 1) % JournalEntry.prompts.length];
                }),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Ganti'),
              ),
            ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
              child: Text(prompt, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6D28D9), height: 1.4)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Tulis bebas, tidak ada yang menilai…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'Simpan',
              icon: Icons.check_rounded,
              onPressed: () async {
                final t = text.text.trim();
                if (t.isEmpty) return;
                final e = await ref.read(journalProvider.notifier).add(prompt, t, mood: ref.read(moodProvider.notifier).today?.mood);
                if (ctx.mounted) Navigator.pop(ctx, e);
              },
            ),
          ]),
        ),
      ),
    );
    if (saved != null && mounted) {
      if (Feelings.isCrisis(saved.text)) {
        await _showCrisis();
      } else {
        showToast(context, 'Jurnal tersimpan 📓');
      }
    }
  }

  Future<void> _showCrisis() => showAppSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Terima kasih sudah menuliskannya 💛', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Sepertinya kamu sedang melewati masa yang sangat berat. Kamu tidak harus menghadapinya sendirian.', textAlign: TextAlign.center, style: TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              const HelpCard(urgent: true),
            ]),
          ),
        ),
      );

  Future<void> _reflect(JournalEntry e) async {
    final s = ref.read(settingsProvider);
    String reply;
    if (!s.hasAi) {
      reply = 'Terima kasih sudah meluangkan waktu menulis. Menuangkan pikiran ke tulisan adalah cara yang baik untuk merawat diri.\n\n'
          'Coba baca lagi tulisanmu pelan-pelan: adakah satu hal yang bisa kamu syukuri, dan satu langkah kecil untuk besok?\n\n'
          '(Isi kunci Gemini di Profil untuk refleksi yang lebih personal.)';
    } else {
      showToast(context, 'Sedang membaca jurnalmu…');
      try {
        final out = await ref.read(aiServiceProvider).chat(
              text: 'Pertanyaan jurnal: ${e.prompt}\nTulisanku: ${e.text}',
              history: const [],
              system: 'Kamu pendamping refleksi yang hangat dalam bahasa Indonesia santai. Baca jurnal pengguna, lalu: '
                  '1) validasi perasaannya dengan tulus (1–2 kalimat), 2) sorot satu hal positif atau kekuatan yang terlihat, '
                  '3) beri satu pertanyaan reflektif atau langkah kecil untuk besok. Maksimal 120 kata. Jangan mendiagnosis. '
                  'Jika ada tanda keinginan menyakiti diri, sarankan menghubungi Healing119 (telepon 119 lalu tekan 8, atau healing119.id) atau 112.',
              apiKey: s.apiKey,
              model: s.model,
            );
        reply = out.text.isEmpty ? 'Maaf, refleksinya belum bisa dibuat sekarang.' : out.text;
      } on AiException catch (err) {
        reply = err.friendly;
      }
    }
    if (!mounted) return;
    await showAppSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✨ Refleksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(reply.replaceAll('**', ''), style: const TextStyle(height: 1.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(journalProvider);
    final hasAi = ref.watch(settingsProvider).hasAi;
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal'), centerTitle: false),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        onPressed: _write,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Tulis'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        if (list.isEmpty)
          const EmptyState(title: 'Jurnal masih kosong', subtitle: 'Menulis 3 menit sebelum tidur membantu pikiran lebih tenang.', icon: Icons.menu_book_rounded)
        else
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (e.mood != null) Text('${MoodAdvice.moodEmoji[e.mood! - 1]} ', style: const TextStyle(fontSize: 16)),
                    Expanded(child: Text('${fmtDateLong(e.at)} · ${fmtTime(e.at)}', style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600))),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: context.muted),
                      onSelected: (v) async {
                        if (v == 'ai') await _reflect(e);
                        if (v == 'del' && context.mounted) {
                          final ok = await confirmDialog(context, title: 'Hapus jurnal ini?', message: e.prompt, ok: 'Hapus', danger: true);
                          if (ok) await ref.read(journalProvider.notifier).remove(e.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'ai', child: Text(hasAi ? 'Minta refleksi AI' : 'Lihat refleksi')),
                        const PopupMenuItem(value: 'del', child: Text('Hapus')),
                      ],
                    ),
                  ]),
                  Text(e.prompt, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                  const SizedBox(height: 6),
                  Text(e.text, style: const TextStyle(height: 1.45)),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        Text(hasAi ? 'Jurnal tersimpan di HP ini. Isinya hanya dikirim ke Gemini kalau kamu memilih "Minta refleksi AI".' : 'Jurnal tersimpan di HP ini saja.',
            style: TextStyle(fontSize: 12, color: context.faint)),
      ]),
    );
  }
}
