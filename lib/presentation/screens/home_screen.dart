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
import 'english/english_screen.dart';
import 'vital_screen.dart';
import '../../providers/vital_provider.dart';
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

    final phase = SkyPhase.of(now);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // A. langit: salam, foto profil, pengingat berikutnya
        SkyHeader(
          phase: phase,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDateLong(now), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .82), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text('${tr(greeting(now))}, ${name.isEmpty ? tr('Kamu') : name}',
                      translate: false, maxLines: 2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.5, height: 1.25, color: Colors.white)),
                ]),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: tr('Profil'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onGoTo(3),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: UserAvatar(name: name, path: ref.watch(settingsProvider).avatarPath, size: 42, radius: 21),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 26),
            _NextCard(next: next, now: now, phase: phase, onNew: () => _openForm(context), onOpenAi: onOpenAi),
          ]),
        ),
        // B. lembar isi yang menumpuk di atas bukit
        Container(
          transform: Matrix4.translationValues(0, -28, 0),
          decoration: BoxDecoration(color: context.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader('Fitur favorit', action: 'Semua', onAction: () => onGoTo(2)),
            _QuickAccess(onNew: () => _openForm(context), onAll: () => onGoTo(2)),
            if (parking != null) ...[
              const SizedBox(height: 16),
              _ParkingCard(parking: parking),
            ],
            SectionHeader('Jadwal hari ini', action: 'Tambah', onAction: () => _openForm(context)),
            _TodaySection(
              today: today,
              upcoming: upcoming,
              doneCount: doneCount,
              totalCount: totalCount,
              onAdd: () => _openForm(context),
              onCalendar: () => onGoTo(1),
            ),
            const SectionHeader('Ringkasan harian'),
            const _DailySummary(),
          ]),
        ),
      ],
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


/// Pengingat berikutnya, tampil langsung di atas langit beranda.
class _NextCard extends ConsumerWidget {
  const _NextCard({required this.next, required this.now, required this.phase, required this.onNew, required this.onOpenAi});
  final Occurrence? next;
  final DateTime now;
  final SkyPhase phase;
  final VoidCallback onNew, onOpenAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = next;
    final dim = Colors.white.withValues(alpha: .85);
    Widget btn(String label, VoidCallback onTap, {bool primary = false}) => Expanded(
          child: SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: primary ? Colors.white : Colors.white.withValues(alpha: .16),
                foregroundColor: primary ? phase.ink : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: primary ? null : BorderSide(color: Colors.white.withValues(alpha: .3)),
                shape: const StadiumBorder(),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    // sisakan ruang kanan untuk matahari / bulan
    Widget narrow(Widget w) => Padding(padding: const EdgeInsets.only(right: 112), child: w);
    final label = narrow(Text('Pengingat berikutnya', style: TextStyle(color: dim, fontSize: 13, fontWeight: FontWeight.w600)));

    if (n == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label,
        const SizedBox(height: 8),
        narrow(const Text('Belum ada agenda berikutnya.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3))),
        const SizedBox(height: 6),
        Text('Tambahkan pengingat pertamamu, atau minta Asisten membuatkannya.', style: TextStyle(color: dim, fontSize: 13.5, height: 1.45)),
        const SizedBox(height: 18),
        Row(children: [
          btn('Tambah pengingat', onNew, primary: true),
          const SizedBox(width: 8),
          btn('Buka Asisten', onOpenAi),
        ]),
      ]);
    }

    final r = n.reminder;
    final isToday = dateOnly(n.at) == dateOnly(now);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      label,
      narrow(FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(fmtTime(n.at), translate: false,
            style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -1.5, fontFeatures: [FontFeature.tabularFigures()])),
      )),
      const SizedBox(height: 4),
      Text(r.title, translate: false, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
      const SizedBox(height: 4),
      Text('${tr(dayLabel(n.at, now))} · ${countdown(n.at, now)}${r.repeat != RepeatType.once ? ' · ${tr(r.repeatLabel)}' : ''}',
          translate: false, style: TextStyle(color: dim, fontSize: 13.5)),
      const SizedBox(height: 18),
      Row(children: [
        if (isToday) ...[
          btn('Tandai selesai', () => completeWithUndo(ScaffoldMessenger.of(context), ref, r, n.at), primary: true),
          const SizedBox(width: 8),
        ],
        btn('Lihat detail', () => showReminderDetail(context, ref, r, n.at), primary: !isToday),
      ]),
    ]);
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
                style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// C. Delapan fitur favorit: ikon putih di lingkaran berwarna.
class _QuickAccess extends ConsumerWidget {
  const _QuickAccess({required this.onNew, required this.onAll});
  final VoidCallback onNew, onAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final menu = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (icon: Icons.notifications_none_rounded, label: 'Pengingat', color: FeatureColors.reminder, onTap: onNew),
      (icon: Icons.local_parking_rounded, label: 'Parkir', color: FeatureColors.parking, onTap: () => startParkingFlow(context, ref)),
      (icon: Icons.mosque_outlined, label: 'Muslim', color: FeatureColors.muslim, onTap: () => push(const MuslimScreen())),
      (icon: Icons.directions_run_rounded, label: 'Olahraga', color: FeatureColors.workout, onTap: () => push(const WorkoutScreen())),
      (icon: Icons.description_outlined, label: 'Catatan', color: FeatureColors.notes, onTap: () => push(const NotesScreen())),
      (icon: Icons.restaurant_rounded, label: 'Kalori', color: FeatureColors.calorie, onTap: () => push(const CalorieScreen())),
      (icon: Icons.spa_outlined, label: 'Tenang', color: FeatureColors.calm, onTap: () => push(const CalmScreen())),
      (icon: Icons.school_outlined, label: 'Inggris', color: FeatureColors.english, onTap: () => openEnglish(context)),
    ];
    Widget item(({IconData icon, String label, Color color, VoidCallback onTap}) m) => Expanded(
          child: Semantics(
            button: true,
            label: tr(m.label),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: m.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  CircleIcon(icon: m.icon, color: m.color, size: 54),
                  const SizedBox(height: 8),
                  Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.ink)),
                ]),
              ),
            ),
          ),
        );
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final m in menu.take(4)) item(m)]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final m in menu.skip(4)) item(m)]),
    ]);
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
    final vit = ref.watch(vitalProvider);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    final tiles = <Widget>[
      _Tile(
        icon: Icons.sentiment_satisfied_alt_rounded,
        color: FeatureColors.calm,
        title: 'Mood',
        sub: mood == null ? 'Belum dicatat hari ini' : '${MoodAdvice.moodEmoji[mood.mood - 1]} ${tr(MoodAdvice.moodLabel[mood.mood - 1])}',
        action: mood == null ? 'Catat' : null,
        onTap: () => showMoodCheckin(context, ref),
      ),
      _Tile(
        icon: Icons.task_alt_rounded,
        color: FeatureColors.reminder,
        title: 'Kebiasaan',
        sub: habits.isEmpty ? 'Belum ada kebiasaan' : '$habitsDone dari ${habits.length} selesai',
        progress: habits.isEmpty ? null : habitsDone / habits.length,
        action: habits.isEmpty ? 'Buat' : null,
        onTap: () => push(const HabitsScreen()),
      ),
      _Tile(
        icon: Icons.mosque_rounded,
        color: FeatureColors.muslim,
        title: '${tr('Sholat')} ${tr(prayerNames[nx.key]!)}',
        sub: '${fmtTime(nx.at)} · ${tr(countdownText(nx.at.difference(now)))}',
        onTap: () => push(const MuslimScreen()),
      ),
      if (t != null)
        _Tile(
          icon: Icons.restaurant_rounded,
          color: FeatureColors.calorie,
          title: 'Kalori',
          sub: t.target - eaten >= 0 ? 'Sisa ${fmtKcal(t.target - eaten)} kkal' : 'Lebih ${fmtKcal(eaten - t.target)} kkal',
          progress: eaten / t.target,
          onTap: () => push(const CalorieScreen()),
        ),
      if (wk.weekMinutes > 0)
        _Tile(
          icon: Icons.directions_run_rounded,
          color: FeatureColors.workout,
          title: 'Olahraga',
          sub: '${wk.weekMinutes}/${wk.weeklyGoal} menit minggu ini',
          progress: wk.weekMinutes / wk.weeklyGoal,
          onTap: () => push(const WorkoutScreen()),
        ),
      if (ci != null)
        _Tile(icon: Icons.water_drop_rounded, color: FeatureColors.cycle, title: 'Siklus haid', sub: ci.status().title, onTap: () => push(const CycleScreen())),
      if (vit.lastBp != null || vit.lastGlu != null)
        _Tile(
          icon: Icons.monitor_heart_outlined,
          color: FeatureColors.vital,
          title: 'Tensi & gula',
          sub: [
            if (vit.lastBp != null) '${vit.lastBp!.sys}/${vit.lastBp!.dia} · ${tr(vit.lastBp!.level.label)}',
            if (vit.lastGlu != null) '${tr('Gula')} ${gluStr(vit.lastGlu!.kind, vit.lastGlu!.value)} · ${tr(vit.lastGlu!.level.label)}',
          ].join('\n'),
          onTap: () => push(VitalScreen(glucose: vit.lastBp == null)),
        ),
      if (items.isNotEmpty)
        _Tile(
          icon: ReminderCategory.barang.icon,
          color: FeatureColors.items,
          title: 'Barang',
          sub: '${items.length} disimpan · ${items.first.title}',
          onTap: () => showItemsSheet(context),
        ),
    ];
    if (tiles.length.isOdd) {
      tiles.add(_Tile(icon: Icons.school_rounded, color: FeatureColors.english, title: 'Belajar Inggris', sub: '5 menit sehari bersama Zeo', action: 'Mulai', onTap: () => openEnglish(context)));
    }
    return Column(children: [
      for (var i = 0; i < tiles.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 10),
            Expanded(child: tiles[i + 1]),
          ]),
        ),
      ],
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.title, required this.sub, this.progress, this.action, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, sub;
  final double? progress;
  final String? action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleIcon(icon: icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4)),
          const Spacer(),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress!.clamp(0, 1).toDouble(), minHeight: 6, color: color, backgroundColor: context.card2),
            ),
          ] else if (action != null) ...[
            const SizedBox(height: 8),
            Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.accent)),
          ],
        ]),
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
