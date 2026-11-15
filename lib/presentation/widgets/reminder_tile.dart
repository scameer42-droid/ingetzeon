import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../screens/reminder_form_screen.dart';
import 'common.dart';
import 'photo_view.dart';
import '../screens/ticket_screens.dart';

/// Satu baris pengingat dengan tombol centang selesai.
class ReminderTile extends ConsumerWidget {
  const ReminderTile(this.item, {super.key, this.showDay = false});
  final Occurrence item;
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = item.reminder;
    final now = DateTime.now();
    final late = !item.done && item.at.isBefore(now) && sameDay(item.at, now);
    final timeText = '${showDay ? '${dayLabel(item.at)} · ' : ''}${fmtTime(item.at)}${late ? ' · terlewat' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        radius: 14,
        onTap: () => showReminderDetail(context, ref, r, item.at),
        child: Row(
          children: [
            CategoryIcon(r.category, faded: item.done, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: item.done ? context.faint : null,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: late ? AppColors.pink : context.muted),
                      Text(timeText,
                          style: TextStyle(fontSize: 12.5, color: late ? AppColors.pink : context.muted, fontWeight: late ? FontWeight.w600 : null)),
                      if (r.repeat != RepeatType.once) _Pill(icon: Icons.repeat_rounded, text: r.repeatLabel),
                      if (r.photoPath != null) const _Pill(icon: Icons.photo_camera_outlined, text: 'Foto'),
                      if (r.hasTicket) const _Pill(icon: Icons.qr_code_2_rounded, text: 'Tiket'),
                      if (!r.alarm) const _Pill(icon: Icons.notifications_off_outlined, text: 'Catatan'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CheckButton(
              done: item.done,
              onTap: () async {
                if (item.done) {
                  await ref.read(remindersProvider.notifier).setDone(r, item.at, false);
                } else {
                  await completeWithUndo(ScaffoldMessenger.of(context), ref, r, item.at);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: context.muted),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.muted)),
      ]),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: done ? AppColors.primary : null,
          shape: BoxShape.circle,
          border: done ? null : Border.all(color: context.faint, width: 1.5),
        ),
        child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
      ),
    );
  }
}

/// Lembar detail pengingat: tandai selesai, ubah, hapus.
Future<void> showReminderDetail(BuildContext context, WidgetRef ref, Reminder r, DateTime day) {
  final at = r.occurrenceOn(day);
  final done = r.isDoneOn(day);
  final now = DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryIcon(r.category, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: r.category.soft, borderRadius: BorderRadius.circular(99)),
                      child: Text(r.category.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r.category.color)),
                    ),
                    const SizedBox(height: 6),
                    Text(r.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3)),
                  ]),
                ),
              ],
            ),
            if (r.note != null) ...[
              const SizedBox(height: 12),
              Text(r.note!, style: TextStyle(color: c.muted, fontSize: 14)),
            ],
            if (r.hasTicket) ...[
              const SizedBox(height: 14),
              TicketBox(text: r.ticketText!, format: r.ticketFormat, onShow: () => openTicket(context, r)),
            ],
            if (r.photoPath != null) ...[
              const SizedBox(height: 14),
              PhotoThumb(r.photoPath!, height: 200),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _metaRow(Icons.calendar_today_rounded, fmtDateLong(at)),
                const SizedBox(height: 10),
                _metaRow(Icons.schedule_rounded,
                    'Jam ${fmtTime(at)} · ${at.isAfter(now) ? countdown(at) : (done ? 'selesai' : 'sudah lewat')}'),
                const SizedBox(height: 10),
                _metaRow(Icons.repeat_rounded, r.repeatLabel),
                if (!r.alarm) ...[
                  const SizedBox(height: 10),
                  _metaRow(Icons.notifications_off_outlined, 'Catatan saja (tanpa alarm)'),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: done ? 'Batalkan selesai' : (r.repeat == RepeatType.once ? 'Selesai & hapus' : 'Selesai untuk hari ini'),
              icon: Icons.check_rounded,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(c);
                if (done) {
                  await ref.read(remindersProvider.notifier).setDone(r, day, false);
                } else {
                  await completeWithUndo(messenger, ref, r, day);
                }
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SoftButton(
                  label: 'Ubah',
                  icon: Icons.edit_rounded,
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReminderFormScreen(existing: r)));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftButton(
                  label: 'Hapus',
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.pink,
                  onPressed: () async {
                    final ok = await confirmDialog(c,
                        title: 'Hapus pengingat?',
                        message: '"${r.title}" akan dihapus${r.repeat != RepeatType.once ? ' beserta semua jadwal ulangnya' : ''}.',
                        ok: 'Hapus',
                        danger: true);
                    if (!ok) return;
                    if (c.mounted) Navigator.pop(c);
                    await ref.read(remindersProvider.notifier).remove(r.id);
                    if (context.mounted) showToast(context, 'Pengingat dihapus');
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

Widget _metaRow(IconData icon, String text) => Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
    ]);

/// Selesaikan pengingat + tampilkan tombol "Urungkan" (pengingat sekali langsung terhapus).
Future<void> completeWithUndo(ScaffoldMessengerState messenger, WidgetRef ref, Reminder r, DateTime day) async {
  final notifier = ref.read(remindersProvider.notifier);
  final removed = await notifier.complete(r, day);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(seconds: removed != null ? 5 : 2),
      content: Text(removed != null ? '"${r.title}" selesai & dihapus ✓' : '"${r.title}" selesai untuk hari ini ✓'),
      action: removed != null ? SnackBarAction(label: 'Urungkan', onPressed: () => notifier.undoComplete(removed)) : null,
    ));
}
