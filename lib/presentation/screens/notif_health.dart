import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/muslim_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/common.dart';

/// Cek & perbaiki semua hal yang bikin notifikasi telat.
Future<void> showNotifHealth(BuildContext context, WidgetRef ref) =>
    showAppSheet(context: context, builder: (_) => const _NotifHealth());

class _NotifHealth extends ConsumerStatefulWidget {
  const _NotifHealth();
  @override
  ConsumerState<_NotifHealth> createState() => _NotifHealthState();
}

class _NotifHealthState extends ConsumerState<_NotifHealth> with WidgetsBindingObserver {
  bool? _notif, _exact, _battery;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // kembali dari Pengaturan HP → cek ulang
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final n = NotificationService.instance;
    final a = await n.notificationsEnabled(), b = await n.canExact(), c = await n.batteryUnrestricted();
    if (!mounted) return;
    final wasBad = _exact == false || _battery == false;
    setState(() {
      _notif = a;
      _exact = b;
      _battery = c;
    });
    if (wasBad && b && c) await _reschedule();
  }

  Future<void> _reschedule() async {
    await ref.read(remindersProvider.notifier).rescheduleAll();
    await ref.read(muslimProvider.notifier).reschedule();
  }

  bool get _allOk => _notif == true && _exact == true && _battery == true;

  @override
  Widget build(BuildContext context) {
    final n = NotificationService.instance;
    final brand = Platform.isAndroid ? 'Xiaomi/Redmi/POCO, Oppo, Vivo, Realme' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (_allOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_allOk ? Icons.verified_rounded : Icons.notifications_paused_rounded,
                color: _allOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Notifikasi tepat waktu', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(_allOk ? 'Semua beres — pengingat akan berbunyi tepat waktu' : 'Selesaikan langkah di bawah supaya tidak telat',
                  style: TextStyle(color: context.muted, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _Step(
          n: 1,
          ok: _notif,
          title: 'Izin notifikasi',
          desc: 'Supaya pengingat boleh muncul.',
          action: 'Izinkan',
          onTap: () async {
            await n.requestPermissions();
            await _check();
          },
        ),
        _Step(
          n: 2,
          ok: _exact,
          title: 'Alarm & pengingat tepat waktu',
          desc: 'Tanpa ini Android boleh menunda notifikasi sampai puluhan menit.',
          action: 'Izinkan',
          onTap: () async {
            await n.requestPermissions();
            await _check();
          },
        ),
        _Step(
          n: 3,
          ok: _battery,
          title: 'Bebas dari hemat baterai',
          desc: 'Pilih "Izinkan" / "Tanpa batasan" supaya IngetZeon tidak "ditidurkan".',
          action: 'Atur',
          onTap: () async {
            await n.requestBatteryUnrestricted();
            await _check();
          },
        ),
        _Step(
          n: 4,
          ok: null,
          title: 'Mulai otomatis (Autostart)',
          desc: 'Khusus $brand: Pengaturan aplikasi → IngetZeon → aktifkan "Mulai otomatis", lalu Penghemat baterai → "Tanpa batasan".',
          action: 'Buka',
          onTap: () => openAppSettings(),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: _testing
              ? null
              : () async {
                  setState(() => _testing = true);
                  await n.testReminder(seconds: 60);
                  if (context.mounted) showToast(context, 'Tes dijadwalkan 1 menit lagi — kunci layar HP lalu tunggu ⏰');
                  if (mounted) setState(() => _testing = false);
                },
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Tes: bunyikan 1 menit lagi', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Text('Tips tes: setelah menekan tombol, kunci layar dan jangan buka aplikasi. Kalau notifikasi muncul tepat 1 menit kemudian, semuanya sudah beres.',
            textAlign: TextAlign.center, style: TextStyle(color: context.faint, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.ok, required this.title, required this.desc, required this.action, required this.onTap});
  final int n;
  final bool? ok; // null = tidak bisa dicek otomatis
  final String title, desc, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final good = ok == true;
    final c = good ? const Color(0xFF10B981) : ok == false ? const Color(0xFFF59E0B) : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: good ? Icon(Icons.check_rounded, size: 18, color: c) : Text('$n', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 8),
        if (good)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Aktif', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
          )
        else
          FilledButton.tonal(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: onTap,
            child: Text(ok == null && n != 4 ? '…' : action),
          ),
      ]),
    );
  }
}
