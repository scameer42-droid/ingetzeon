import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/muslim_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/wellbeing_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/notification_service.dart';
import 'ai_assistant_screen.dart';
import 'alarm_screen.dart';
import 'calendar_screen.dart';
import 'calm/calm_tools.dart';
import 'cycle_screen.dart';
import 'home_screen.dart';
import 'muslim/muslim_screen.dart';
import 'notif_health.dart';
import 'workout/workout_screen.dart';
import '../../providers/workout_provider.dart';
import '../../providers/settings_provider.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import '../widgets/common.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  /// Tab terakhir — tetap sama setelah ganti bahasa (layar dibangun ulang).
  static int _lastIndex = 0;
  int _index = _lastIndex;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _lastIndex = _index;
  }
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final notif = NotificationService.instance;
    _sub = notif.responses.listen(_onNotification);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch0 = notif.takeLaunchResponse();
      if (launch0 != null) await _onNotification(launch0);
      // biarkan layar tampil dulu, baru urus jadwal di belakang
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await notif.requestPermissions();
      await _refreshSchedules();
      await ref.read(notesProvider.notifier).migrateSecrets();
      if (launch0 == null && mounted) await _askBatteryOnce();
    });
  }

  /// Sekali saja: ajak atur supaya notifikasi tidak telat (hemat baterai / alarm tepat).
  Future<void> _askBatteryOnce() async {
    final repo = ref.read(settingsRepositoryProvider);
    if (repo.get<bool>('askedNotifHealth', false)) return;
    final n = NotificationService.instance;
    if (await n.batteryUnrestricted() && await n.canExact()) return;
    await repo.set('askedNotifHealth', true);
    if (mounted) await showNotifHealth(context, ref);
  }

  bool _busy = false;
  DateTime _lastRefresh = DateTime.now();

  /// Daftarkan jadwal. Hanya yang berubah yang dikirim ke sistem, jadi ringan.
  Future<void> _refreshSchedules() async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(remindersProvider.notifier).rescheduleAll();
      await ref.read(muslimProvider.notifier).reschedule();
      await ref.read(cycleProvider.notifier).reschedule();
      await ref.read(calmSettingsProvider.notifier).reschedule();
      await ref.read(habitsProvider.notifier).reschedule();
      await ref.read(workoutProvider.notifier).reschedule();
      _lastRefresh = DateTime.now();
    } catch (e) {
      debugPrint('Gagal menyegarkan jadwal: $e');
    } finally {
      _busy = false;
    }
  }

  // dibuka lagi setelah lama di latar (mis. besoknya) → segarkan jadwal sholat dkk.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (DateTime.now().difference(_lastRefresh) < const Duration(hours: 3)) return;
    Future.delayed(const Duration(seconds: 1), _refreshSchedules);
  }

  /// Notifikasi diketuk → layar alarm; tombol Selesai/Tunda → langsung diproses.
  Future<void> _onNotification(NotificationResponse r) async {
    final id = r.payload;
    if (id == null) return;
    if (r.actionId == 'stop_adzan' || id == 'adzan_test') return;
    if (id == 'cycle') {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CycleScreen()));
      return;
    }
    if (id == 'olahraga') {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutScreen()));
      return;
    }
    if (id == 'muslim') {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MuslimScreen()));
      return;
    }
    if (id.startsWith('calm:')) {
      if (!mounted) return;
      final tool = id.substring(5);
      if (tool == 'fokus') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusScreen()));
      } else {
        await openTool(context, ref, tool);
      }
      return;
    }
    if (r.actionId == null || r.actionId!.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AlarmScreen(reminderId: id)));
    } else if (id == 'test') {
      await NotificationService.instance.stopTest();
    } else {
      await ref.read(remindersProvider.notifier).handleNotification(r);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openAi() => Navigator.of(context).push(_slideUp(const AiAssistantScreen()));

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(openChatRequestProvider, (_, __) => _openAi());
    final screens = [
      HomeScreen(onOpenAi: _openAi, onGoTo: (i) => setState(() => _index = i)),
      const CalendarScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AestheticBackground(child: IndexedStack(index: _index, children: screens)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(padding: const EdgeInsets.only(top: 24), child: _GradientFab(onTap: _openAi)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: context.isDark ? Border(top: BorderSide(color: context.line)) : null,
          boxShadow: [BoxShadow(color: const Color(0xFF3B2F8F).withValues(alpha: context.isDark ? .4 : .14), blurRadius: 28, offset: const Offset(0, -6), spreadRadius: -8)],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Beranda', active: _index == 0, onTap: () => setState(() => _index = 0)),
                _NavItem(icon: Icons.calendar_month_rounded, label: 'Kalender', active: _index == 1, onTap: () => setState(() => _index = 1)),
                const SizedBox(width: 72),
                _NavItem(icon: Icons.insert_chart_rounded, label: 'Statistik', active: _index == 2, onTap: () => setState(() => _index = 2)),
                _NavItem(icon: Icons.person_rounded, label: 'Profil', active: _index == 3, onTap: () => setState(() => _index = 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route _slideUp(Widget page) => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : context.faint;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(gradient: active ? AppColors.gradient : null, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: active ? Colors.white : color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.aurora,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .9), width: 3),
        boxShadow: [BoxShadow(color: AppColors.violetMid.withValues(alpha: .5), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -6)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}
