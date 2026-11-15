import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/photo_view.dart';

/// Layar alarm penuh: muncul saat alarm berbunyi / notifikasi diketuk.
/// Bunyi berhenti setelah memilih Selesai, Tunda, atau Matikan.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.reminderId});

  /// 'test' untuk tes alarm dari Profil.
  final String reminderId;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  Future<void> _close(Future<void> Function() action) async {
    await action();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isTest = widget.reminderId == 'test';
    final Reminder? r = isTest ? null : ref.watch(remindersProvider.notifier).byId(widget.reminderId);
    final notifier = ref.read(remindersProvider.notifier);
    final now = DateTime.now();
    final title = isTest ? 'Tes alarm IngetZeon' : (r?.title ?? 'Pengingat');
    final photo = r?.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close(() async => isTest ? NotificationService.instance.stopTest() : notifier.dismissAlarm(widget.reminderId));
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Text(fmtDateLong(now), style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14)),
                  Text(fmtTime(now), style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w700, height: 1.1)),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (_, child) {
                      final t = _ring.value;
                      final wobble = t < .5 ? (0.25 * (1 - t * 2)) * (t * 40).remainder(2) - .12 : 0.0;
                      return Transform.rotate(angle: wobble, child: child);
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
                      ),
                      child: Icon(
                        r?.category == ReminderCategory.parkir ? Icons.local_parking_rounded : Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.25)),
                  if (r?.note != null) ...[
                    const SizedBox(height: 6),
                    Text(r!.note!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 15)),
                  ],
                  if (hasPhoto) ...[
                    const SizedBox(height: 18),
                    PhotoThumb(photo, height: 170, radius: 20),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(isTest ? 'Matikan' : 'Selesai', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      onPressed: () => _close(() async {
                        if (isTest) return NotificationService.instance.stopTest();
                        if (r == null) return;
                        await NotificationService.instance.stopSnooze(r);
                        await notifier.setDone(r, now, true);
                      }),
                    ),
                  ),
                  if (!isTest) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: _GhostButton(
                          label: 'Tunda 10 menit',
                          onTap: () => _close(() => notifier.snooze(widget.reminderId)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GhostButton(
                          label: 'Matikan',
                          onTap: () => _close(() => notifier.dismissAlarm(widget.reminderId)),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: .6), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
