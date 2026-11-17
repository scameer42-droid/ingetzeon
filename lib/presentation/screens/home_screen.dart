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
import 'calm/calm_screen.dart';
import 'calm/tests_screen.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/muslim_provider.dart';
import 'muslim/muslim_screen.dart';
import 'calorie/calorie_screen.dart';
import 'workout/workout_screen.dart';
import '../../providers/workout_provider.dart';
import '../../providers/calorie_provider.dart';
import 'calm/calm_tools.dart';
import 'cycle_screen.dart';
import 'item_sheet.dart';
import 'notes_screen.dart';
import 'parking_sheet.dart';
import 'ticket_screens.dart';
import 'reminder_form_screen.dart';
import 'stats_screen.dart';
import 'translate_screen.dart';
import '../../services/islam_logic.dart';
import '../../services/calorie_logic.dart';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.card.withValues(alpha: context.isDark ? .6 : .85),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: context.line),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(child: Text(fmtDateLong(now), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text('${greeting(now)},', style: accentFont(size: 26, color: context.ink)),
                  ShaderMask(
                    shaderCallback: (r) => AppColors.aurora.createShader(r),
                    child: Text('${name.isEmpty ? tr('Kamu') : name} 👋', translate: false, style: accentFont(size: 26, color: Colors.white)),
                  ),
                ]),
              ),
              Column(children: [
                GestureDetector(
                  onTap: () => onGoTo(3),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.aurora),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: context.bg),
                      child: UserAvatar(name: name, path: ref.watch(settingsProvider).avatarPath, size: 46, radius: 23),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const _LangChip(),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          _HeroCard(next: next, now: now, onOpen: next == null ? null : () => showReminderDetail(context, ref, next.reminder, next.at)),
          const SizedBox(height: 16),
          _AskBar(onTap: onOpenAi),
          const SizedBox(height: 14),
          _MenuCard(onOpenAi: onOpenAi, onGoTo: onGoTo, onItems: () => _showItems(context, items), onNew: () => _openForm(context)),
          const SizedBox(height: 12),
          const _TranslateBanner(),
          if (parking != null) ...[
            const SizedBox(height: 12),
            _ParkingCard(parking: parking),
          ],
          const SectionHeader('Ringkasan hari ini'),
          _SummaryRow(onItems: () => _showItems(context, items)),
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
    return Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: .55),
          AppColors.magenta.withValues(alpha: .45),
          AppColors.sky.withValues(alpha: .45),
        ]),
        boxShadow: context.softShadow,
      ),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(18.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.5),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(children: [
              ShaderMask(
                shaderCallback: (r) => AppColors.aurora.createShader(r),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Ketik atau ucapkan pengingat…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 14))),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: AppColors.aurora, borderRadius: BorderRadius.circular(13), boxShadow: context.colorShadow(AppColors.violetMid)),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 21),
              ),
            ]),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: context.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.language_rounded, size: 13, color: context.muted),
            const SizedBox(width: 4),
            Text(lang == 'en' ? 'EN' : 'ID', translate: false, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }
}

/// Kartu fitur Terjemah Indonesia ⇄ Inggris.
class _TranslateBanner extends StatelessWidget {
  const _TranslateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: kTrGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: context.colorShadow(kTrColor, strength: .4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => openTranslate(context),
          child: Stack(children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.translate_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Terjemahkan', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('🇮🇩 Indonesia ⇄ Inggris 🇬🇧 · ketik atau ucapkan', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
                  ]),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: kTrColor, size: 19),
                ),
              ]),
            ),
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


class _StatsPage extends StatelessWidget {
  const _StatsPage();
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Statistik')), body: const StatsScreen());
}

/// Menu ikon 4 kolom — satu tempat untuk semua fitur.
class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.onOpenAi, required this.onGoTo, required this.onItems, required this.onNew});
  final VoidCallback onOpenAi, onItems, onNew;
  final void Function(int) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = activeItems(ref.watch(remindersProvider)).length;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final menu = <({IconData icon, String label, Color color, VoidCallback onTap, int badge})>[
      (icon: Icons.add_alarm_rounded, label: 'Pengingat', color: const Color(0xFF6366F1), onTap: onNew, badge: 0),
      (icon: Icons.local_parking_rounded, label: 'Parkir', color: ReminderCategory.parkir.color, onTap: () => startParkingFlow(context, ref), badge: 0),
      (icon: ReminderCategory.barang.icon, label: 'Barang', color: const Color(0xFFF59E0B), onTap: onItems, badge: items),
      (icon: Icons.sticky_note_2_rounded, label: 'Catatan', color: const Color(0xFF8B5CF6), onTap: () => push(const NotesScreen()), badge: 0),
      (icon: Icons.mosque_rounded, label: 'Muslim', color: const Color(0xFF059669), onTap: () => push(const MuslimScreen()), badge: 0),
      (icon: Icons.restaurant_rounded, label: 'Kalori', color: kKal, onTap: () => push(const CalorieScreen()), badge: 0),
      (icon: Icons.directions_run_rounded, label: 'Olahraga', color: const Color(0xFFE11D48), onTap: () => push(const WorkoutScreen()), badge: 0),
      (icon: Icons.apps_rounded, label: 'Lainnya', color: const Color(0xFF64748B), onTap: () => _moreMenu(context, ref), badge: 0),
    ];
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        childAspectRatio: .92,
        children: [
          for (final m in menu)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: m.onTap,
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(gradient: AppColors.tint(m.color), borderRadius: BorderRadius.circular(17), boxShadow: context.colorShadow(m.color, strength: .4)),
                    child: Icon(m.icon, color: Colors.white, size: 25),
                  ),
                  if (m.badge > 0)
                    Positioned(
                      right: -6,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(99), border: Border.all(color: context.card, width: 2)),
                        child: Text('${m.badge}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
              ]),
            ),
        ],
      ),
    );
  }

  void _moreMenu(BuildContext context, WidgetRef ref) {
    final cycleOn = ref.read(cycleProvider).enabled;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final rows = <({IconData icon, String title, String sub, Color color, VoidCallback onTap})>[
      (icon: Icons.spa_rounded, title: 'Ruang Tenang', sub: 'Mood, kebiasaan, fokus, jurnal', color: const Color(0xFF14B8A6), onTap: () => push(CalmScreen(onOpenChat: onOpenAi))),
      (icon: Icons.psychology_rounded, title: 'Tes psikologi', sub: 'Kenali kondisi dirimu', color: const Color(0xFFEC4899), onTap: () => push(const TestsScreen())),
      (icon: Icons.water_drop_rounded, title: 'Siklus haid', sub: cycleOn ? 'Pengingat & perkiraan haid' : 'Aktifkan pengingat haid', color: kHaid, onTap: () => push(const CycleScreen())),
      (icon: Icons.calendar_month_rounded, title: 'Kalender', sub: 'Semua jadwal per tanggal', color: const Color(0xFF6366F1), onTap: () => onGoTo(1)),
      (icon: Icons.bar_chart_rounded, title: 'Statistik', sub: 'Progres & kebiasaanmu', color: const Color(0xFF0EA5E9), onTap: () => push(const _StatsPage())),
      (icon: Icons.translate_rounded, title: 'Terjemahkan', sub: 'Indonesia ⇄ Inggris', color: kTrColor, onTap: () => openTranslate(context)),
      (icon: Icons.auto_awesome_rounded, title: 'Asisten AI', sub: 'Tanya atau suruh apa saja', color: const Color(0xFF8B5CF6), onTap: onOpenAi),
      (icon: Icons.settings_rounded, title: 'Profil & pengaturan', sub: 'Tema, suara, cadangan data', color: const Color(0xFF64748B), onTap: () => onGoTo(3)),
    ];
    showAppSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetTitle('Semua fitur'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final r in rows)
                Material(
                  color: ctx.card2,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.pop(ctx);
                      r.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: r.color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                          child: Icon(r.icon, color: r.color, size: 21),
                        ),
                        const Spacer(),
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ctx.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Kartu ringkasan yang bisa digeser: sholat, kalori, mood, haid, barang.
class _SummaryRow extends ConsumerWidget {
  const _SummaryRow({required this.onItems});
  final VoidCallback onItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final nx = ref.watch(muslimProvider).next(now);
    final kal = ref.watch(calorieProvider);
    final t = kal.target;
    final eaten = kal.kcalOn(now) - ref.watch(workoutProvider).kcalOn(now);
    final wk = ref.watch(workoutProvider);
    ref.watch(moodProvider);
    final mood = ref.read(moodProvider.notifier).today;
    final cycle = ref.watch(cycleProvider);
    final ci = cycle.enabled ? CycleInfo.from(cycle) : null;
    final items = activeItems(ref.watch(remindersProvider));
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final cards = <Widget>[
      _SumCard(
        icon: Icons.mosque_rounded,
        color: const Color(0xFF059669),
        head: 'Sholat',
        big: prayerNames[nx.key]!,
        unit: fmtTime(nx.at),
        sub: countdownText(nx.at.difference(now)),
        onTap: () => push(const MuslimScreen()),
      ),
      _SumCard(
        icon: Icons.restaurant_rounded,
        color: kKal,
        head: 'Kalori',
        big: fmtKcal(kal.kcalOn(now)),
        unit: 'kkal',
        sub: t == null ? 'Atur target diet' : (t.target - eaten >= 0 ? 'sisa ${fmtKcal(t.target - eaten)} dari ${fmtKcal(t.target)}' : 'lebih ${fmtKcal(eaten - t.target)} kkal'),
        progress: t == null ? null : eaten / t.target,
        onTap: () => push(const CalorieScreen()),
      ),
      _SumCard(
        icon: Icons.directions_run_rounded,
        color: const Color(0xFFE11D48),
        head: 'Olahraga',
        big: '${wk.weekMinutes}',
        unit: '/ ${wk.weeklyGoal} mnt',
        sub: wk.minutesOn(now) > 0 ? 'Hari ini ${wk.minutesOn(now)} menit 🔥' : 'Minggu ini · ayo gerak!',
        progress: wk.weekMinutes / wk.weeklyGoal,
        onTap: () => push(const WorkoutScreen()),
      ),
      _SumCard(
        icon: Icons.spa_rounded,
        color: const Color(0xFF14B8A6),
        head: 'Mood',
        big: mood == null ? 'Belum dicek' : MoodAdvice.moodEmoji[mood.mood - 1],
        unit: mood == null ? '' : MoodAdvice.moodLabel[mood.mood - 1],
        sub: mood == null ? 'Ketuk untuk cek mood' : 'Tercatat hari ini ✓',
        small: mood == null,
        onTap: () => showMoodCheckin(context, ref),
      ),
      if (ci != null)
        _SumCard(
          icon: Icons.water_drop_rounded,
          color: kHaid,
          head: 'Siklus haid',
          big: ci.status().title,
          small: true,
          sub: ci.status().sub,
          onTap: () => push(const CycleScreen()),
        ),
      if (items.isNotEmpty)
        _SumCard(
          icon: ReminderCategory.barang.icon,
          color: const Color(0xFFF59E0B),
          head: 'Barang disimpan',
          big: '${items.length}',
          unit: 'barang',
          sub: items.first.title,
          onTap: onItems,
        ),
    ];
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  const _SumCard({required this.icon, required this.color, required this.head, required this.big, this.unit = '', required this.sub, this.progress, this.small = false, required this.onTap});
  final IconData icon;
  final Color color;
  final String head, big, unit, sub;
  final double? progress;
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const w70 = Color(0xD9FFFFFF);
    return Container(
      width: 156,
      decoration: BoxDecoration(
        gradient: AppColors.tint(color),
        borderRadius: BorderRadius.circular(22),
        boxShadow: context.colorShadow(color, strength: .45),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Positioned(
              right: -26,
              top: -30,
              child: Container(width: 86, height: 86, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .14))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(head, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: w70))),
                ]),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: big, style: TextStyle(fontSize: small ? 15 : 21, fontWeight: FontWeight.w800, letterSpacing: -.3, color: Colors.white)),
                    if (unit.isNotEmpty) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: w70)),
                  ]),
                  maxLines: small ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: w70)),
                const Spacer(),
                if (progress != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: progress!.clamp(0, 1).toDouble(), minHeight: 5, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: .25)),
                  ),
              ]),
            ),
          ]),
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
