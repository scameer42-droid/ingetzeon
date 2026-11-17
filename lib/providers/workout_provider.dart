import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

class WorkoutLog {
  const WorkoutLog({required this.id, required this.at, required this.name, required this.secs, required this.kcal, this.program, this.emoji = '🏃'});
  final String id, name, emoji;
  final String? program;
  final DateTime at;
  final int secs;
  final double kcal;

  Map<String, dynamic> toMap() => {'id': id, 'at': at.millisecondsSinceEpoch, 'n': name, 's': secs, 'k': kcal, 'p': program, 'e': emoji};
  static WorkoutLog fromMap(Map m) => WorkoutLog(
        id: '${m['id']}',
        at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt()),
        name: '${m['n']}',
        secs: (m['s'] as num).toInt(),
        kcal: (m['k'] as num).toDouble(),
        program: m['p'] as String?,
        emoji: '${m['e'] ?? '🏃'}',
      );
}

class WorkoutState {
  const WorkoutState({this.logs = const [], this.weeklyGoal = 150, this.reminderHour, this.reminderMinute = 0, this.challengeStart, this.voice = true});
  final List<WorkoutLog> logs; // terbaru di depan
  final int weeklyGoal; // menit per minggu (WHO: 150)
  final int? reminderHour;
  final int reminderMinute;
  final DateTime? challengeStart;
  final bool voice;

  List<WorkoutLog> on(DateTime d) => logs.where((l) => sameDay(l.at, d)).toList();
  double kcalOn(DateTime d) => on(d).fold(0.0, (a, l) => a + l.kcal);
  int minutesOn(DateTime d) => (on(d).fold(0, (a, l) => a + l.secs) / 60).round();

  /// Menit olahraga minggu ini (Senin–Minggu).
  int get weekMinutes {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return (logs.where((l) => !l.at.isBefore(start)).fold(0, (a, l) => a + l.secs) / 60).round();
  }

  /// Hari berturut-turut berolahraga.
  int get streak {
    var n = 0;
    var d = DateTime.now();
    if (on(d).isEmpty) d = addDays(d, -1);
    while (on(d).isNotEmpty) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  /// Hari ke berapa tantangan 4 minggu (1–28), null bila belum mulai/selesai.
  int? get challengeDay {
    if (challengeStart == null) return null;
    final d = DateTime.now().difference(DateTime(challengeStart!.year, challengeStart!.month, challengeStart!.day)).inDays + 1;
    return d >= 1 && d <= 28 ? d : null;
  }

  /// Hari-hari tantangan yang sudah dikerjakan (1..28).
  Set<int> get challengeDone {
    if (challengeStart == null) return {};
    final s = DateTime(challengeStart!.year, challengeStart!.month, challengeStart!.day);
    return {
      for (final l in logs)
        if (l.program?.startsWith('tantangan') == true) DateTime(l.at.year, l.at.month, l.at.day).difference(s).inDays + 1,
    }..removeWhere((d) => d < 1 || d > 28);
  }

  WorkoutState copyWith({List<WorkoutLog>? logs, int? weeklyGoal, int? Function()? reminderHour, int? reminderMinute, DateTime? Function()? challengeStart, bool? voice}) =>
      WorkoutState(
        logs: logs ?? this.logs,
        weeklyGoal: weeklyGoal ?? this.weeklyGoal,
        reminderHour: reminderHour != null ? reminderHour() : this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        challengeStart: challengeStart != null ? challengeStart() : this.challengeStart,
        voice: voice ?? this.voice,
      );

  Map<String, dynamic> toMap() => {
        'logs': [for (final l in logs) l.toMap()],
        'goal': weeklyGoal,
        'rh': reminderHour,
        'rm': reminderMinute,
        'cs': challengeStart?.millisecondsSinceEpoch,
        'v': voice,
      };
  static WorkoutState fromMap(Map m) => WorkoutState(
        logs: [for (final x in (m['logs'] as List? ?? const [])) if (x is Map) WorkoutLog.fromMap(x)],
        weeklyGoal: (m['goal'] as num?)?.toInt() ?? 150,
        reminderHour: (m['rh'] as num?)?.toInt(),
        reminderMinute: (m['rm'] as num?)?.toInt() ?? 0,
        challengeStart: m['cs'] == null ? null : DateTime.fromMillisecondsSinceEpoch((m['cs'] as num).toInt()),
        voice: m['v'] != false,
      );
}

class WorkoutNotifier extends Notifier<WorkoutState> {
  @override
  WorkoutState build() {
    final raw = ref.read(settingsRepositoryProvider).get<String>('workout', '');
    if (raw.isEmpty) return const WorkoutState();
    try {
      return WorkoutState.fromMap(jsonDecode(raw) as Map);
    } catch (_) {
      return const WorkoutState();
    }
  }

  Future<void> _save(WorkoutState s) async {
    state = s;
    await ref.read(settingsRepositoryProvider).set('workout', jsonEncode(s.toMap()));
  }

  Future<void> add({required String name, required int secs, required double kcal, String? program, String emoji = '🏃', DateTime? at}) async {
    final l = WorkoutLog(id: '${DateTime.now().microsecondsSinceEpoch}', at: at ?? DateTime.now(), name: name, secs: secs, kcal: kcal, program: program, emoji: emoji);
    await _save(state.copyWith(logs: [l, ...state.logs].take(400).toList()));
  }

  Future<void> remove(String id) => _save(state.copyWith(logs: state.logs.where((l) => l.id != id).toList()));
  Future<void> setGoal(int minutes) => _save(state.copyWith(weeklyGoal: minutes));
  Future<void> setVoice(bool v) => _save(state.copyWith(voice: v));
  Future<void> startChallenge() => _save(state.copyWith(challengeStart: () => DateTime.now()));
  Future<void> stopChallenge() => _save(state.copyWith(challengeStart: () => null));

  Future<void> setReminder(int? hour, [int minute = 0]) async {
    await _save(state.copyWith(reminderHour: () => hour, reminderMinute: minute));
    await reschedule();
  }

  Future<void> reschedule() => NotificationService.instance.scheduleWorkout(hour: state.reminderHour, minute: state.reminderMinute);
}

final workoutProvider = NotifierProvider<WorkoutNotifier, WorkoutState>(WorkoutNotifier.new);
