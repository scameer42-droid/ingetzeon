import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/notes_provider.dart';
import '../../providers/wellbeing_provider.dart';
import '../../services/wellbeing_logic.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';
import '../widgets/reminder_tile.dart';
import 'calm/calm_screen.dart';
import 'calm/tests_screen.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/muslim_provider.dart';
import 'muslim/muslim_screen.dart';
import 'calorie/calorie_screen.dart';
import '../../providers/calorie_provider.dart';
import 'calm/calm_tools.dart';
import 'cycle_screen.dart';
import 'item_sheet.dart';
import 'notes_screen.dart';
import 'parking_sheet.dart';
import 'ticket_screens.dart';
import 'reminder_form_screen.dart';
import 'stats_screen.dart';
import '../../services/islam_logic.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenAi, required this.onGoTo});
  final VoidCallback onOpenAi;
  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final list = ref.watch(remindersProvider);
    final name = ref.watch(settingsProvider.select((s) => s.name));

    // catatan parkir tanpa alarm sudah tampil di kartu parkir
    // catatan (parkir/barang) tampil di bagiannya sendiri
    final all = occurrencesOn(list, now).where((x) => x.reminder.alarm).toList();
    final items = activeItems(list);
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDateLong(now), style: TextStyle(fontSize: 13, color: context.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${greeting(now)},', style: accentFont(size: 25, color: context.ink)),
                  Text('${name.isEmpty ? 'Kamu' : name} 👋', style: accentFont(size: 25, color: AppColors.primary)),
                ]),
              ),
              GestureDetector(
                onTap: () => onGoTo(3),
                child: UserAvatar(name: name, path: ref.watch(settingsProvider).avatarPath, size: 46),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _HeroCard(next: next, now: now, onOpen: next == null ? null : () => showReminderDetail(context, ref, next.reminder, next.at)),
          const SizedBox(height: 16),
          _AskBar(onTap: onOpenAi),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.local_parking_rounded,
                label: 'Catat parkir',
                color: ReminderCategory.parkir.color,
                onTap: () => startParkingFlow(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: ReminderCategory.barang.icon,
                label: 'Ingat barang',
                color: ReminderCategory.barang.color,
                onTap: () => startItemFlow(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.add_alarm_rounded,
                label: 'Pengingat',
                color: AppColors.primary,
                onTap: () => _openForm(context),
              ),
            ),
          ]),
          if (parking != null) ...[
            const SizedBox(height: 12),
            _ParkingCard(parking: parking),
          ],
          const SectionHeader('Fitur'),
          _FeatureGrid(onOpenAi: onOpenAi, itemCount: items.length, onItems: () => _showItems(context, items)),
          SectionHeader('Jadwal hari ini', action: '+ Tambah', onAction: () => _openForm(context)),
          _TodaySection(
            today: today,
            upcoming: upcoming,
            doneCount: doneCount,
            totalCount: totalCount,
            onAdd: () => _openForm(context),
            onCalendar: () => onGoTo(1),
          ),
        ],
      ),
    );
  }

  void _showItems(BuildContext context, List<Reminder> items) {
    if (items.isEmpty) {
      startItemFlow(context);
      return;
    }
    showModalBottomSheet(
      context: context,
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

  void _openForm(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.next, required this.now, this.onOpen});
  final Occurrence? next;
  final DateTime now;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final n = next;
    return MeshCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 110, minWidth: double.infinity),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(n == null ? Icons.check_circle_outline_rounded : Icons.notifications_none_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(n == null ? 'Semua beres' : 'Jadwal terdekat',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(n == null ? 'Belum ada jadwal berikutnya' : n.reminder.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: accentFont(size: 22, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  n == null
                      ? 'Tekan tombol ✦ di bawah lalu bilang "ingatkan…" untuk mulai.'
                      : '${dayLabel(n.at, now)} · ${fmtTime(n.at)}${n.reminder.repeat != RepeatType.once ? ' · ${n.reminder.repeatLabel}' : ''}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14),
                ),
                if (n != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text(countdown(n.at, now),
                          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: onOpen,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: .14),
                        side: BorderSide(color: Colors.white.withValues(alpha: .35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Lihat', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ],
        ),
      ),
    );
  }
}

class _AskBar extends StatelessWidget {
  const _AskBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      radius: 18,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.auto_awesome_rounded, color: context.muted, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Ketik atau ucapkan pengingat…', style: TextStyle(color: context.muted, fontSize: 14))),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
        ),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: context.isDark ? .2 : .11),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white.withValues(alpha: .08) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: context.isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 4), spreadRadius: -6)],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _ParkingCard extends ConsumerWidget {
  const _ParkingCard({required this.parking});
  final Reminder parking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tickerProvider); // perbarui durasi tiap 30 detik
    final c = ReminderCategory.parkir.color;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      onTap: () => showReminderDetail(context, ref, parking, parking.scheduledAt),
      child: Row(children: [
        if (parking.photoPath != null)
          PhotoThumb(parking.photoPath!, height: 72, width: 72, radius: 14)
        else
          const CategoryIcon(ReminderCategory.parkir, size: 72),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.local_parking_rounded, size: 14, color: c),
              const SizedBox(width: 4),
              Text('Lokasi parkir kamu', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Text(parking.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.timer_outlined, size: 14, color: c),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${elapsed(parking.createdAt)} · sejak ${fmtTime(parking.createdAt)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
              ),
            ]),
            if (parking.hasTicket)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => openTicket(context, parking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text('Tampilkan tiket', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: () => completeWithUndo(ScaffoldMessenger.of(context), ref, parking, parking.scheduledAt),
          style: TextButton.styleFrom(foregroundColor: c, visualDensity: VisualDensity.compact),
          child: const Text('Sudah\ndiambil', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
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


/// Kotak fitur ringkas di beranda — satu kotak per fitur, isi lengkap dibuka saat diketuk.
class _FeatureGrid extends ConsumerWidget {
  const _FeatureGrid({required this.onOpenAi, required this.itemCount, required this.onItems});
  final VoidCallback onOpenAi;
  final int itemCount;
  final VoidCallback onItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final muslim = ref.watch(muslimProvider);
    ref.watch(moodProvider);
    final mood = ref.read(moodProvider.notifier).today;
    final habits = ref.watch(habitsProvider);
    final habitsDone = habits.where((h) => h.doneOn(now)).length;
    final notes = ref.watch(notesProvider);
    final secretCount = notes.where((n) => n.secret).length;
    final cycle = ref.watch(cycleProvider);
    final cycleInfo = cycle.enabled ? CycleInfo.from(cycle) : null;
    final next = muslim.next(now);
    final kal = ref.watch(calorieProvider);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    final tiles = <Widget>[
      _FeatureTile(
        emoji: '🕌',
        title: 'Muslim Harian',
        subtitle: '${prayerNames[next.key]} ${fmtTime(next.at)}',
        gradient: kMuslimGradient,
        onTap: () => push(const MuslimScreen()),
      ),
      _FeatureTile(
        emoji: mood == null ? '🌿' : MoodAdvice.moodEmoji[mood.mood - 1],
        title: 'Ruang Tenang',
        subtitle: mood == null ? 'Cek mood hari ini' : (habits.isEmpty ? 'Mood tercatat ✓' : 'Kebiasaan $habitsDone/${habits.length}'),
        gradient: kCalmGradient,
        onTap: () => push(CalmScreen(onOpenChat: onOpenAi)),
      ),
      _FeatureTile(
        emoji: '🥗',
        title: 'Kalori & Diet',
        subtitle: calorieSummary(kal),
        gradient: kKalGradient,
        onTap: () => push(const CalorieScreen()),
      ),
      _FeatureTile(
        emoji: '📝',
        title: 'Catatan',
        subtitle: notes.isEmpty ? 'Belum ada catatan' : '${notes.length} catatan${secretCount > 0 ? ' · $secretCount 🔒' : ''}',
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
        onTap: () => push(const NotesScreen()),
      ),
      _FeatureTile(
        emoji: '🎒',
        title: 'Barang',
        subtitle: itemCount == 0 ? 'Belum ada barang' : '$itemCount barang disimpan',
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
        onTap: onItems,
      ),
      if (cycleInfo != null)
        _FeatureTile(
          emoji: '🩸',
          title: 'Siklus haid',
          subtitle: cycleInfo.status().title,
          gradient: kHaidGradient,
          onTap: () => push(const CycleScreen()),
        ),
      _FeatureTile(
        emoji: '🧠',
        title: 'Tes psikologi',
        subtitle: 'Kenali dirimu',
        gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF97316)]),
        onTap: () => push(const TestsScreen()),
      ),
    ];
    if (tiles.length.isOdd) {
      tiles.add(_FeatureTile(
        emoji: '📊',
        title: 'Statistik',
        subtitle: 'Lihat progresmu',
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
        onTap: () => push(const _StatsPage()),
      ));
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: tiles,
    );
  }
}

class _StatsPage extends StatelessWidget {
  const _StatsPage();
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Statistik')), body: const StatsScreen());
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.emoji, required this.title, required this.subtitle, required this.gradient, required this.onTap});
  final String emoji, title, subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 10), spreadRadius: -12)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(11)),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white.withValues(alpha: .85)),
              ]),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
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
                    child: Container(height: 8, decoration: const BoxDecoration(gradient: AppColors.gradient)),
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
          const EmptyState(title: 'Semua selesai 🎉', subtitle: 'Kerja bagus! Tidak ada lagi pengingat hari ini.', icon: Icons.task_alt_rounded)
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
          title: 'Hari ini kosong',
          subtitle: 'Nikmati harimu, atau tambahkan pengingat baru.',
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
            const Icon(Icons.upcoming_rounded, color: AppColors.primary, size: 20),
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
                    TextButton(onPressed: w.onCalendar, child: const Text('Buka kalender')),
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
