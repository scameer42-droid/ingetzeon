import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/wellbeing_provider.dart';
import '../../services/wellbeing_logic.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';
import '../widgets/reminder_tile.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/muslim_provider.dart';
import 'muslim/muslim_screen.dart';
import 'calorie/calorie_screen.dart';
import 'workout/workout_screen.dart';
import '../../providers/workout_provider.dart';
import '../../providers/calorie_provider.dart';
import 'calm/calm_screen.dart';
import 'calm/calm_tools.dart';
import 'cycle_screen.dart';
import 'item_sheet.dart';
import 'notes_screen.dart';
import 'parking_sheet.dart';
import 'ticket_screens.dart';
import 'reminder_form_screen.dart';
import '../../services/islam_logic.dart';
import '../../services/calorie_logic.dart';

/// Beranda: agenda terdekat → akses cepat → jadwal hari ini → ringkasan harian.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenAi, required this.onGoTo});
  final VoidCallback onOpenAi;
  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final list = ref.watch(remindersProvider);
    final name = ref.watch(settingsProvider.select((s) => s.name));

    // catatan (parkir/barang) tampil di bagiannya sendiri
    final all = occurrencesOn(list, now).where((x) => x.reminder.alarm).toList();
    final today = all.where((x) => !x.done).toList(); // yang selesai otomatis disembunyikan
    final logToday = ref.read(remindersProvider.notifier).doneLogOn(now);
    final totalCount = all.length + logToday;
    final doneCount = all.length - today.length + logToday;
    final next = nextUpcoming(list, now);
    final parking = activeParking(list, now);
    final seen = <String>{};
    final upcoming = <Occurrence>[
      for (var i = 1; i <= 3; i++)
        ...occurrencesOn(list, addDays(dateOnly(now), i)).where((x) => x.reminder.alarm && seen.add(x.reminder.id)),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // A. header
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDateLong(now), style: TextStyle(fontSize: 13, color: context.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${tr(greeting(now))}, ${name.isEmpty ? tr('Kamu') : name}',
                      translate: false, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.3, height: 1.3, color: context.ink)),
                ]),
              ),
              const SizedBox(width: 12),
              const _LangChip(),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: tr('Profil'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onGoTo(3),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: UserAvatar(name: name, path: ref.watch(settingsProvider).avatarPath, size: 44, radius: 22),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // B. agenda terdekat
          _NextCard(next: next, now: now, onNew: () => _openForm(context), onOpenAi: onOpenAi),
          if (parking != null) ...[
            const SizedBox(height: 12),
            _ParkingCard(parking: parking),
          ],
          // C. akses cepat
          SectionHeader('Akses cepat', action: 'Semua fitur', onAction: () => onGoTo(2)),
          _QuickAccess(onNew: () => _openForm(context)),
          // D. jadwal hari ini
          SectionHeader('Jadwal hari ini', action: 'Tambah', onAction: () => _openForm(context)),
          _TodaySection(
            today: today,
            upcoming: upcoming,
            doneCount: doneCount,
            totalCount: totalCount,
            onAdd: () => _openForm(context),
            onCalendar: () => onGoTo(1),
          ),
          // E. ringkasan harian
          const SectionHeader('Ringkasan harian'),
          const _DailySummary(),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
}

/// Daftar barang yang disimpan (atau langsung tambah bila belum ada).
void showItemsSheet(BuildContext context) {
  final items = activeItems(ProviderScope.containerOf(context, listen: false).read(remindersProvider));
  if (items.isEmpty) {
    startItemFlow(context);
    return;
  }
    showAppSheet(
      context: context,
      scroll: false,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final list = activeItems(ref.watch(remindersProvider));
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(children: [
                  const Expanded(child: Text('Barang yang kamu simpan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      startItemFlow(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah'),
                  ),
                ]),
              ),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Semua barang sudah diambil 👍', textAlign: TextAlign.center))
              else
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: ctx.line),
                  _ItemRow(item: list[i]),
                ],
            ]),
          ),
        );
      }),
    );
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});
  final Reminder item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ReminderCategory.barang;
    return InkWell(
      onTap: () => showReminderDetail(context, ref, item, item.scheduledAt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          if (item.photoPath != null)
            PhotoThumb(item.photoPath!, height: 38, width: 38, radius: 11)
          else
            CategoryIcon(c, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.item == null ? item.title : item.item![0].toUpperCase() + item.item!.substring(1),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              Text('${item.place ?? ''} · ${dayLabel(item.createdAt)} ${fmtTime(item.createdAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.muted)),
            ]),
          ),
          TextButton(
            onPressed: () => completeWithUndo(ScaffoldMessenger.of(context), ref, item, item.scheduledAt),
            style: TextButton.styleFrom(foregroundColor: c.color, backgroundColor: c.soft, visualDensity: VisualDensity.compact),
            child: const Text('Diambil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}


/// Tombol cepat ganti bahasa ID ⇄ EN.
class _LangChip extends ConsumerWidget {
  const _LangChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => ref.read(settingsProvider.notifier).setLang(lang == 'en' ? 'id' : 'en'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: context.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.language_rounded, size: 13, color: context.muted),
            const SizedBox(width: 4),
            Text(lang == 'en' ? 'EN' : 'ID', translate: false, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.muted)),
          ]),
        ),
      ),
    );
  }
}


/// B. Kartu "Agenda terdekat" — fokus utama beranda.
class _NextCard extends ConsumerWidget {
  const _NextCard({required this.next, required this.now, required this.onNew, required this.onOpenAi});
  final Occurrence? next;
  final DateTime now;
  final VoidCallback onNew, onOpenAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = next;
    const onCard = Colors.white;
    final dim = Colors.white.withValues(alpha: .8);
    Widget btn(String label, VoidCallback onTap, {IconData? icon, bool primary = false}) => Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: primary ? Colors.white : Colors.white.withValues(alpha: .16),
                foregroundColor: primary ? AppColors.primary : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        );

    if (n == null) {
      return MeshCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Agenda terdekat', style: TextStyle(color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text('Belum ada agenda berikutnya.', style: TextStyle(color: onCard, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 4),
          Text('Tambahkan pengingat pertamamu, atau minta Asisten membuatkannya.', style: TextStyle(color: dim, fontSize: 14, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            btn('Tambah pengingat', onNew, icon: Icons.add_rounded, primary: true),
            const SizedBox(width: 8),
            btn('Buka Asisten', onOpenAi),
          ]),
        ]),
      );
    }

    final r = n.reminder;
    final isToday = dateOnly(n.at) == dateOnly(now);
    return MeshCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Agenda terdekat', style: TextStyle(color: dim, fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.category.icon, size: 14, color: onCard),
              const SizedBox(width: 5),
              Text(r.category.label, style: const TextStyle(color: onCard, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(r.title, translate: false, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: onCard, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -.2)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 16, color: onCard),
          const SizedBox(width: 6),
          Text(fmtTime(n.at), translate: false, style: const TextStyle(color: onCard, fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
          Flexible(
            child: Text(' · ${tr(dayLabel(n.at, now))}${r.repeat != RepeatType.once ? ' · ${tr(r.repeatLabel)}' : ''}',
                translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dim, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(countdown(n.at, now), style: TextStyle(color: dim, fontSize: 13)),
        const SizedBox(height: 20),
        Row(children: [
          if (isToday) ...[
            btn('Tandai selesai', () => completeWithUndo(ScaffoldMessenger.of(context), ref, r, n.at), icon: Icons.check_rounded, primary: true),
            const SizedBox(width: 8),
          ],
          btn('Lihat detail', () => showReminderDetail(context, ref, r, n.at), primary: !isToday),
        ]),
      ]),
    );
  }
}

/// Lokasi parkir yang masih aktif.
class _ParkingCard extends ConsumerWidget {
  const _ParkingCard({required this.parking});
  final Reminder parking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tickerProvider); // perbarui durasi tiap 30 detik
    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: () => showReminderDetail(context, ref, parking, parking.scheduledAt),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (parking.photoPath != null)
            PhotoThumb(parking.photoPath!, height: 48, width: 48, radius: 14)
          else
            const CategoryIcon(ReminderCategory.parkir, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lokasi parkir kamu', style: TextStyle(fontSize: 12.5, color: context.muted)),
              const SizedBox(height: 2),
              Text(parking.title, translate: false, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 2),
              Text('${elapsed(parking.createdAt)} · sejak ${fmtTime(parking.createdAt)}', style: TextStyle(fontSize: 13, color: context.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          if (parking.hasTicket) ...[
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: () => openTicket(context, parking),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Tampilkan tiket', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: TextButton.styleFrom(foregroundColor: context.ink, backgroundColor: context.card2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextButton.icon(
                onPressed: () => completeWithUndo(ScaffoldMessenger.of(context), ref, parking, parking.scheduledAt),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Sudah diambil', maxLines: 1, overflow: TextOverflow.ellipsis),
                style: TextButton.styleFrom(foregroundColor: context.accent, backgroundColor: context.accentSoft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// C. Empat fitur yang paling sering dipakai.
class _QuickAccess extends ConsumerWidget {
  const _QuickAccess({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final menu = <({IconData icon, String label, VoidCallback onTap})>[
      (icon: Icons.add_alarm_rounded, label: 'Tambah pengingat', onTap: onNew),
      (icon: Icons.sticky_note_2_outlined, label: 'Catatan', onTap: () => push(const NotesScreen())),
      (icon: Icons.local_parking_rounded, label: 'Simpan parkir', onTap: () => startParkingFlow(context, ref)),
      (icon: Icons.timer_outlined, label: 'Fokus', onTap: () => push(const FocusScreen())),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in menu)
          Expanded(
            child: Semantics(
              button: true,
              label: tr(m.label),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: m.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: context.accentSoft, borderRadius: BorderRadius.circular(18)),
                      child: Icon(m.icon, color: context.accent, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(m.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3, color: context.ink)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// E. Ringkasan harian: mood, kebiasaan, sholat, lalu fitur lain yang sedang dipakai.
class _DailySummary extends ConsumerWidget {
  const _DailySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    ref.watch(moodProvider);
    final mood = ref.read(moodProvider.notifier).today;
    final habits = ref.watch(habitsProvider);
    final habitsDone = habits.where((h) => h.doneOn(now)).length;
    final nx = ref.watch(muslimProvider).next(now);
    final kal = ref.watch(calorieProvider);
    final t = kal.target;
    final wk = ref.watch(workoutProvider);
    final eaten = kal.kcalOn(now) - wk.kcalOn(now);
    final cycle = ref.watch(cycleProvider);
    final ci = cycle.enabled ? CycleInfo.from(cycle) : null;
    final items = activeItems(ref.watch(remindersProvider));
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget action(String s) => Text(s, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.accent));

    return ListGroup(children: [
      AppListRow(
        icon: Icons.sentiment_satisfied_alt_rounded,
        color: AppColors.success,
        title: 'Mood',
        subtitle: mood == null
            ? 'Belum dicatat hari ini'
            : '${MoodAdvice.moodEmoji[mood.mood - 1]} ${tr(MoodAdvice.moodLabel[mood.mood - 1])} · ${tr('tercatat hari ini')}',
        trailing: mood == null ? action(tr('Catat')) : null,
        onTap: () => showMoodCheckin(context, ref),
      ),
      AppListRow(
        icon: Icons.task_alt_rounded,
        color: AppColors.primary,
        title: 'Kebiasaan',
        subtitle: habits.isEmpty ? 'Belum ada kebiasaan' : '$habitsDone dari ${habits.length} selesai',
        progress: habits.isEmpty ? null : habitsDone / habits.length,
        trailing: habits.isEmpty ? action(tr('Buat')) : null,
        onTap: () => push(const HabitsScreen()),
      ),
      AppListRow(
        icon: Icons.mosque_outlined,
        color: const Color(0xFF0F766E),
        title: 'Sholat berikutnya',
        subtitle: '${tr(prayerNames[nx.key]!)} ${fmtTime(nx.at)} · ${tr(countdownText(nx.at.difference(now)))}',
        onTap: () => push(const MuslimScreen()),
      ),
      if (t != null)
        AppListRow(
          icon: Icons.restaurant_rounded,
          color: AppColors.warning,
          title: 'Kalori',
          subtitle: t.target - eaten >= 0
              ? 'Sisa ${fmtKcal(t.target - eaten)} dari ${fmtKcal(t.target)} kkal'
              : 'Lebih ${fmtKcal(eaten - t.target)} kkal dari target',
          progress: eaten / t.target,
          onTap: () => push(const CalorieScreen()),
        ),
      if (wk.weekMinutes > 0)
        AppListRow(
          icon: Icons.directions_run_rounded,
          color: AppColors.error,
          title: 'Olahraga',
          subtitle: '${wk.weekMinutes} dari ${wk.weeklyGoal} menit minggu ini',
          progress: wk.weekMinutes / wk.weeklyGoal,
          onTap: () => push(const WorkoutScreen()),
        ),
      if (ci != null)
        AppListRow(
          icon: Icons.water_drop_outlined,
          color: kHaid,
          title: 'Siklus haid',
          subtitle: ci.status().title,
          onTap: () => push(const CycleScreen()),
        ),
      if (items.isNotEmpty)
        AppListRow(
          icon: ReminderCategory.barang.icon,
          color: ReminderCategory.barang.color,
          title: 'Barang disimpan',
          subtitle: '${items.length} barang · ${items.first.title}',
          onTap: () => showItemsSheet(context),
        ),
    ]);
  }
}

/// Jadwal hari ini yang rapi: progres + 3 jadwal teratas, sisanya dibuka saat diketuk.
class _TodaySection extends StatefulWidget {
  const _TodaySection({
    required this.today,
    required this.upcoming,
    required this.doneCount,
    required this.totalCount,
    required this.onAdd,
    required this.onCalendar,
  });
  final List<Occurrence> today, upcoming;
  final int doneCount, totalCount;
  final VoidCallback onAdd, onCalendar;

  @override
  State<_TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<_TodaySection> {
  bool _all = false;
  bool _soon = false;
  static const _show = 3;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final shown = _all ? w.today : w.today.take(_show).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (w.totalCount > 0) ...[
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          radius: 18,
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(height: 8, color: context.card2),
                  FractionallySizedBox(
                    widthFactor: w.doneCount / w.totalCount,
                    child: Container(height: 8, color: AppColors.success),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 14),
            Text('${w.doneCount}/${w.totalCount} selesai', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        if (w.today.isEmpty)
          const EmptyState(title: 'Semua agenda hari ini selesai.', subtitle: 'Tidak ada lagi pengingat hari ini.', icon: Icons.task_alt_rounded)
        else ...[
          ...shown.map((x) => ReminderTile(x)),
          if (w.today.length > _show)
            _MoreButton(
              label: _all ? 'Tutup' : 'Lihat ${w.today.length - _show} jadwal lainnya',
              open: _all,
              onTap: () => setState(() => _all = !_all),
            ),
        ],
      ] else
        EmptyState(
          title: 'Belum ada agenda hari ini.',
          subtitle: 'Tambahkan pengingat pertamamu.',
          actionLabel: 'Tambah pengingat',
          onAction: w.onAdd,
        ),
      if (w.upcoming.isNotEmpty) ...[
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          radius: 18,
          onTap: () => setState(() => _soon = !_soon),
          child: Row(children: [
            Icon(Icons.upcoming_rounded, color: context.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Akan datang · ${w.upcoming.length} jadwal', style: const TextStyle(fontWeight: FontWeight.w700))),
            AnimatedRotation(turns: _soon ? .5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: context.muted)),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _soon
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ...w.upcoming.take(6).map((x) => ReminderTile(x, showDay: true)),
                    TextButton(onPressed: w.onCalendar, child: const Text('Buka agenda')),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ]);
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.open, required this.onTap});
  final String label;
  final bool open;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
