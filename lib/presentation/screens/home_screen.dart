import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';
import '../widgets/reminder_tile.dart';
import 'item_sheet.dart';
import 'parking_sheet.dart';
import 'ticket_screens.dart';
import 'reminder_form_screen.dart';

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
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(16), boxShadow: context.glowShadow),
                  alignment: Alignment.center,
                  child: Text((name.isEmpty ? 'I' : name[0]).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
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
          if (items.isNotEmpty) ...[
            const SectionHeader('Barang yang kamu simpan'),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < items.length && i < 6; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.line),
                  _ItemRow(item: items[i]),
                ],
              ]),
            ),
          ],
          SectionHeader('Jadwal hari ini', action: '+ Tambah', onAction: () => _openForm(context)),
          if (totalCount > 0) ...[
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
                        widthFactor: doneCount / totalCount,
                        child: Container(height: 8, decoration: const BoxDecoration(gradient: AppColors.gradient)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 14),
                Text('$doneCount/$totalCount selesai', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 12),
            if (today.isEmpty)
              const EmptyState(title: 'Semua selesai 🎉', subtitle: 'Kerja bagus! Tidak ada lagi pengingat hari ini.', icon: Icons.task_alt_rounded)
            else
              ...today.map((x) => ReminderTile(x)),
          ] else
            EmptyState(
              title: 'Hari ini kosong',
              subtitle: 'Nikmati harimu, atau tambahkan pengingat baru.',
              actionLabel: 'Tambah pengingat',
              onAction: () => _openForm(context),
            ),
          if (upcoming.isNotEmpty) ...[
            SectionHeader('Akan datang', action: 'Kalender', onAction: () => onGoTo(1)),
            ...upcoming.take(6).map((x) => ReminderTile(x, showDay: true)),
          ],
        ],
      ),
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
            Text('${dayLabel(parking.createdAt)} · ${fmtTime(parking.createdAt)}', style: TextStyle(fontSize: 12, color: context.muted)),
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
