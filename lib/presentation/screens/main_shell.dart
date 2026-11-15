import 'dart:async';

import 'package:flutter/material.dart';
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
import 'profile_screen.dart';
import 'stats_screen.dart';
import '../widgets/common.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final notif = NotificationService.instance;
    _sub = notif.responses.listen(_onNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await notif.requestPermissions();
      final notifier = ref.read(remindersProvider.notifier);
      await notifier.rescheduleAll();
      await ref.read(cycleProvider.notifier).reschedule();
      await ref.read(calmSettingsProvider.notifier).reschedule();
      await ref.read(habitsProvider.notifier).reschedule();
      await ref.read(muslimProvider.notifier).reschedule();
      await ref.read(notesProvider.notifier).migrateSecrets();
      final launch = notif.takeLaunchResponse();
      if (launch != null) await _onNotification(launch);
    });
  }

  /// Notifikasi diketuk → layar alarm; tombol Selesai/Tunda → langsung diproses.
  Future<void> _onNotification(NotificationResponse r) async {
    final id = r.payload;
    if (id == null) return;
    if (id == 'cycle') {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CycleScreen()));
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: const Color(0xFF28286E).withValues(alpha: .14), blurRadius: 24, offset: const Offset(0, -8), spreadRadius: -12)],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
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
              decoration: BoxDecoration(color: active ? AppColors.primary.withValues(alpha: .12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 23),
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
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
