import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool? _notifOn;
  bool? _exactOn;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final n = NotificationService.instance;
    final on = await n.notificationsEnabled();
    final ex = await n.canExact();
    if (mounted) {
      setState(() {
        _notifOn = on;
        _exactOn = ex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final count = ref.watch(remindersProvider).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Text('Pengaturan', style: TextStyle(fontSize: 13, color: context.muted, fontWeight: FontWeight.w500)),
          const Text('Profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          MeshCard(
            child: Row(children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text((s.name.isEmpty ? 'I' : s.name[0]).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name.isEmpty ? 'Pengguna IngetZeon' : s.name, style: accentFont(size: 18, color: context.ink)),
                  Text('$count pengingat tersimpan', style: TextStyle(color: context.muted, fontSize: 13)),
                ]),
              ),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: context.card2),
                icon: Icon(Icons.edit_rounded, color: context.ink, size: 20),
                onPressed: () async {
                  final v = await inputDialog(context, title: 'Nama kamu', message: 'Dipakai untuk sapaan di beranda.', initial: s.name, hint: 'Nama panggilan');
                  if (v != null) notifier.setName(v);
                },
              ),
            ]),
          ),
          _groupTitle('Tampilan'),
          SoftCard(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide(color: context.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Terang')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Gelap')),
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_rounded, size: 18), label: Text('Otomatis')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => notifier.setTheme(v.first),
              ),
            ),
          ),
          _groupTitle('Asisten & suara'),
          _Group(children: [
            _Row(
              icon: Icons.key_rounded,
              color: AppColors.primary,
              title: 'Kunci API Gemini',
              subtitle: s.hasAi ? 'Terpasang · model ${s.model}' : 'Belum diisi — asisten pakai mode offline',
              onTap: () async {
                final v = await inputDialog(
                  context,
                  title: 'Kunci API Gemini',
                  message: 'Buat gratis di aistudio.google.com → Get API key. Kunci hanya disimpan di HP ini. Kosongkan untuk mode offline.',
                  initial: s.apiKey,
                  hint: 'AIza…',
                );
                if (v == null) return;
                await notifier.setApiKey(v);
                if (context.mounted) showToast(context, v.trim().isEmpty ? 'Mode offline aktif' : 'Kunci tersimpan. Asisten pakai Gemini.');
              },
            ),
            _Row(
              icon: Icons.memory_rounded,
              color: AppColors.violetMid,
              title: 'Model Gemini',
              subtitle: s.model,
              onTap: () async {
                final v = await inputDialog(context, title: 'Model Gemini', message: 'Biarkan "gemini-flash-latest" kalau ragu.', initial: s.model);
                if (v != null) notifier.setModel(v);
              },
            ),
            _Row(
              icon: Icons.volume_up_rounded,
              color: AppColors.pink,
              title: 'Balasan suara',
              subtitle: 'Asisten membacakan jawabannya',
              trailing: Switch(value: s.voice, onChanged: notifier.setVoice),
              onTap: () => notifier.setVoice(!s.voice),
            ),
          ]),
          _groupTitle('Bunyi alarm'),
          _Group(children: [
            for (final a in AlarmSound.values)
              _Row(
                icon: a == AlarmSound.melodi
                    ? Icons.music_note_rounded
                    : a == AlarmSound.hp
                        ? Icons.alarm_rounded
                        : Icons.notifications_none_rounded,
                color: a == s.alarmSound ? AppColors.primary : context.faint,
                title: a.label,
                subtitle: a.description,
                trailing: Icon(
                  a == s.alarmSound ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: a == s.alarmSound ? AppColors.primary : context.faint,
                ),
                onTap: () async {
                  await notifier.setAlarmSound(a);
                  await ref.read(remindersProvider.notifier).rescheduleAll();
                },
              ),
            _Row(
              icon: Icons.play_circle_outline_rounded,
              color: AppColors.pink,
              title: 'Tes alarm',
              subtitle: 'Berbunyi 5 detik lagi · kunci layar untuk melihat layar alarm',
              onTap: () async {
                await NotificationService.instance.testAlarm(s.alarmSound);
                if (context.mounted) showToast(context, 'Alarm berbunyi 5 detik lagi…');
              },
            ),
            _Row(
              icon: Icons.screen_lock_portrait_rounded,
              color: const Color(0xFF0EA5B7),
              title: 'Layar alarm saat HP terkunci',
              subtitle: 'Ketuk lalu izinkan "Notifikasi layar penuh"',
              onTap: () => NotificationService.instance.requestFullScreen(),
            ),
          ]),
          _groupTitle('Notifikasi'),
          _Group(children: [
            _Row(
              icon: Icons.notifications_active_outlined,
              color: const Color(0xFF1FB57A),
              title: 'Izin notifikasi',
              subtitle: _notifOn == null ? '…' : (_notifOn! ? 'Aktif · ketuk untuk tes' : 'Belum aktif — ketuk untuk mengizinkan'),
              onTap: () async {
                if (_notifOn == true) {
                  await NotificationService.instance.testAlarm(s.alarmSound);
                } else {
                  await NotificationService.instance.requestPermissions();
                  await _refreshPermissions();
                }
              },
            ),
            _Row(
              icon: Icons.alarm_rounded,
              color: const Color(0xFFF2A11B),
              title: 'Alarm tepat waktu',
              subtitle: _exactOn == null ? '…' : (_exactOn! ? 'Aktif' : 'Nonaktif — ketuk untuk mengizinkan'),
              onTap: () async {
                await NotificationService.instance.requestPermissions();
                await _refreshPermissions();
                await ref.read(remindersProvider.notifier).rescheduleAll();
              },
            ),
            _Row(
              icon: Icons.battery_saver_rounded,
              color: const Color(0xFF64748B),
              title: 'Tips: notifikasi telat/tidak muncul?',
              subtitle: 'Atur baterai IngetZeon ke "Tanpa batasan"',
              onTap: () => showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Supaya alarm selalu bunyi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  content: Text(
                    'Beberapa HP (Xiaomi, Oppo, Vivo, Realme, Samsung) mematikan aplikasi di latar untuk hemat baterai.\n\n'
                    '1. Buka Pengaturan HP → Aplikasi → IngetZeon\n'
                    '2. Baterai → pilih "Tanpa batasan" / "Tidak dibatasi"\n'
                    '3. Di Xiaomi: aktifkan juga "Mulai otomatis" (Autostart)',
                    style: TextStyle(color: c.muted, fontSize: 14),
                  ),
                  actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Mengerti'))],
                ),
              ),
            ),
          ]),
          _groupTitle('Data'),
          _Group(children: [
            _Row(
              icon: Icons.delete_outline_rounded,
              color: AppColors.pink,
              title: 'Hapus semua data',
              subtitle: 'Pengingat dan riwayat chat',
              danger: true,
              onTap: () async {
                final ok = await confirmDialog(context,
                    title: 'Hapus semua data?', message: 'Semua pengingat dan riwayat chat akan dihapus dan tidak bisa dikembalikan.', ok: 'Hapus', danger: true);
                if (!ok) return;
                await ref.read(remindersProvider.notifier).clearAll();
                await ref.read(chatProvider.notifier).clear();
                if (context.mounted) showToast(context, 'Semua data dihapus');
              },
            ),
          ]),
          _groupTitle('Tentang'),
          const _Group(children: [
            _Row(
              icon: Icons.info_outline_rounded,
              color: AppColors.primary,
              title: 'IngetZeon versi 1.0',
              subtitle: 'Pengingat harian dengan asisten AI & suara',
            ),
          ]),
          const SizedBox(height: 20),
          Center(child: Text('Semua data tersimpan di HP kamu sendiri.', style: TextStyle(fontSize: 12, color: context.faint))),
        ],
      ),
    );
  }

  Widget _groupTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(t.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.muted, letterSpacing: .6)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.line, indent: 16, endIndent: 16),
          children[i],
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap, this.trailing, this.danger = false});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: danger ? AppColors.pink : null)),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted)),
            ]),
          ),
          trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: context.faint) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}
