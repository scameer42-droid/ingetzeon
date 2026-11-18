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
import 'features_screen.dart';

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
    void goTo(int i) => setState(() => _index = i);
    final screens = [
      HomeScreen(onOpenAi: _openAi, onGoTo: goTo),
      const CalendarScreen(),
      FeaturesScreen(onGoTo: goTo),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: context.bg,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: context.card, border: Border(top: BorderSide(color: context.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Beranda', active: _index == 0, onTap: () => goTo(0)),
                _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Agenda', active: _index == 1, onTap: () => goTo(1)),
                _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'Asisten', active: false, onTap: _openAi),
                _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Fitur', active: _index == 2, onTap: () => goTo(2)),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', active: _index == 3, onTap: () => goTo(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route _slideUp(Widget page) => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, anim, __, child) {
        if (MediaQuery.of(context).disableAnimations) return child;
        return SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.accent : context.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: tr(label),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 56,
                height: 32,
                decoration: const BoxDecoration(),
                child: Icon(active ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
