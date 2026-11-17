import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/english_data.dart';
import 'settings_provider.dart';

/// Progres Belajar Inggris: XP, runtutan hari, XP hari ini, dan bintang per topik.
class EngProgress {
  const EngProgress({this.xp = 0, this.streak = 0, this.last = '', this.day = '', this.dayXp = 0, this.stars = const {}});
  final int xp, streak, dayXp;
  final String last, day;
  final Map<String, int> stars;

  Map<String, dynamic> toMap() => {'xp': xp, 'streak': streak, 'last': last, 'day': day, 'dayXp': dayXp, 'stars': stars};

  static EngProgress fromMap(Map m) => EngProgress(
        xp: (m['xp'] as num?)?.toInt() ?? 0,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
        last: (m['last'] ?? '').toString(),
        day: (m['day'] ?? '').toString(),
        dayXp: (m['dayXp'] as num?)?.toInt() ?? 0,
        stars: {
          for (final e in ((m['stars'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0,
        },
      );

  /// Nilai yang sudah disesuaikan dengan hari ini (XP harian & runtutan yang terputus).
  EngProgress normalized(DateTime now) {
    final k = _key(now), y = _key(addDays(dateOnly(now), -1));
    return EngProgress(
      xp: xp,
      streak: (last == k || last == y) ? streak : 0,
      last: last,
      day: k,
      dayXp: day == k ? dayXp : 0,
      stars: stars,
    );
  }

  bool unlocked(int i) => i == 0 || (stars[engTopics[i - 1].id] ?? 0) > 0;

  EngTopic get nextTopic => engTopics.firstWhere((t) => (stars[t.id] ?? 0) == 0, orElse: () => engTopics.first);

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class EngNotifier extends Notifier<EngProgress> {
  @override
  EngProgress build() {
    final raw = ref.read(settingsRepositoryProvider).get<Map>('eng', const {});
    return EngProgress.fromMap(raw).normalized(DateTime.now());
  }

  /// Catat pelajaran yang selesai; mengembalikan progres baru.
  Future<EngProgress> finishLesson(String topicId, {required int stars, required int xp}) async {
    final now = DateTime.now();
    final p = state.normalized(now);
    final k = EngProgress._key(now), y = EngProgress._key(addDays(dateOnly(now), -1));
    final streak = p.last == k ? p.streak : (p.last == y ? p.streak + 1 : 1);
    final next = EngProgress(
      xp: p.xp + xp,
      streak: streak,
      last: k,
      day: k,
      dayXp: p.dayXp + xp,
      stars: {...p.stars, topicId: stars > (p.stars[topicId] ?? 0) ? stars : (p.stars[topicId] ?? 0)},
    );
    state = next;
    await ref.read(settingsRepositoryProvider).set('eng', next.toMap());
    return next;
  }

  void refreshDay() => state = state.normalized(DateTime.now());
}

final engProvider = NotifierProvider<EngNotifier, EngProgress>(EngNotifier.new);
