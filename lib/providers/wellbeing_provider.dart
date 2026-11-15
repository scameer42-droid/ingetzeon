import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

/// ---------- Mood & energi ----------
class MoodEntry {
  const MoodEntry({required this.day, required this.mood, required this.energy, this.note = '', required this.at});
  final String day; // yyyy-MM-dd
  final int mood; // 1..5
  final int energy; // 1..5
  final String note;
  final DateTime at;
  Map<String, dynamic> toMap() => {'d': day, 'm': mood, 'e': energy, 'n': note, 't': at.millisecondsSinceEpoch};
  static MoodEntry? fromMap(Map m) {
    final d = m['d']?.toString();
    if (d == null) return null;
    return MoodEntry(
      day: d,
      mood: ((m['m'] as num?) ?? 3).toInt().clamp(1, 5).toInt(),
      energy: ((m['e'] as num?) ?? 3).toInt().clamp(1, 5).toInt(),
      note: (m['n'] ?? '').toString(),
      at: DateTime.fromMillisecondsSinceEpoch(((m['t'] as num?) ?? 0).toInt()),
    );
  }
}

class MoodNotifier extends Notifier<List<MoodEntry>> {
  @override
  List<MoodEntry> build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('moods', const []);
    return raw.whereType<Map>().map(MoodEntry.fromMap).whereType<MoodEntry>().toList()..sort((a, b) => a.day.compareTo(b.day));
  }

  MoodEntry? get today {
    final k = dayKey(DateTime.now());
    for (final e in state) {
      if (e.day == k) return e;
    }
    return null;
  }

  /// Satu catatan per hari (yang baru menggantikan).
  Future<void> log(int mood, int energy, {String note = ''}) async {
    final now = DateTime.now();
    final k = dayKey(now);
    final list = [...state.where((e) => e.day != k), MoodEntry(day: k, mood: mood, energy: energy, note: note, at: now)];
    state = list.length > 400 ? list.sublist(list.length - 400) : list;
    await ref.read(settingsRepositoryProvider).set('moods', state.map((e) => e.toMap()).toList());
  }

  Future<void> clear() async {
    state = [];
    await ref.read(settingsRepositoryProvider).set('moods', const []);
  }
}

final moodProvider = NotifierProvider<MoodNotifier, List<MoodEntry>>(MoodNotifier.new);

/// ---------- Kebiasaan ----------
class Habit {
  const Habit({required this.id, required this.name, required this.emoji, this.hour, this.minute = 0, this.done = const {}, required this.createdAt});
  final String id;
  final String name;
  final String emoji;
  final int? hour; // jam pengingat (null = tanpa pengingat)
  final int minute;
  final Set<String> done; // dayKey
  final DateTime createdAt;

  bool doneOn(DateTime d) => done.contains(dayKey(d));

  /// Hari berturut-turut sampai hari ini (atau kemarin bila hari ini belum).
  int get streak {
    var d = DateTime.now();
    if (!doneOn(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (doneOn(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  Habit copyWith({String? name, String? emoji, int? hour, bool clearHour = false, int? minute, Set<String>? done}) => Habit(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        hour: clearHour ? null : (hour ?? this.hour),
        minute: minute ?? this.minute,
        done: done ?? this.done,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {'id': id, 'n': name, 'e': emoji, 'h': hour, 'mi': minute, 'd': done.toList(), 'c': createdAt.millisecondsSinceEpoch};
  static Habit? fromMap(Map m) {
    final id = m['id']?.toString();
    if (id == null) return null;
    return Habit(
      id: id,
      name: (m['n'] ?? '').toString(),
      emoji: (m['e'] ?? '✅').toString(),
      hour: (m['h'] as num?)?.toInt(),
      minute: ((m['mi'] as num?) ?? 0).toInt(),
      done: {for (final x in (m['d'] as List? ?? const [])) x.toString()},
      createdAt: DateTime.fromMillisecondsSinceEpoch(((m['c'] as num?) ?? 0).toInt()),
    );
  }

  static const presets = [
    ('💧', 'Minum 8 gelas air', 9),
    ('🏃', 'Olahraga 20 menit', 17),
    ('😴', 'Tidur sebelum jam 23.00', 22),
    ('📖', 'Baca 10 menit', 20),
    ('🚶', 'Jalan kaki', 7),
    ('🙏', 'Ibadah / bersyukur', 5),
    ('📵', '1 jam tanpa HP', 21),
    ('🥗', 'Makan sayur & buah', 12),
  ];
}

class HabitsNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('habits', const []);
    return raw.whereType<Map>().map(Habit.fromMap).whereType<Habit>().toList();
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).set('habits', state.map((h) => h.toMap()).toList());
    await NotificationService.instance.scheduleHabits([
      for (var i = 0; i < state.length; i++)
        if (state[i].hour != null) (index: i, title: '${state[i].emoji} ${state[i].name}', hour: state[i].hour!, minute: state[i].minute),
    ]);
  }

  Future<void> add(String emoji, String name, {int? hour, int minute = 0}) async {
    state = [...state, Habit(id: 'h${DateTime.now().microsecondsSinceEpoch}', name: name, emoji: emoji, hour: hour, minute: minute, createdAt: DateTime.now())];
    await _save();
  }

  Future<void> update(Habit h) async {
    state = [for (final x in state) x.id == h.id ? h : x];
    await _save();
  }

  Future<void> toggleToday(String id) async {
    final k = dayKey(DateTime.now());
    state = [
      for (final h in state)
        if (h.id == id) h.copyWith(done: h.done.contains(k) ? ({...h.done}..remove(k)) : {...h.done, k}) else h,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((h) => h.id != id).toList();
    await _save();
  }

  Future<void> reschedule() => _save();

  Future<void> clear() async {
    state = [];
    await _save();
  }
}

final habitsProvider = NotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

/// ---------- Jurnal ----------
class JournalEntry {
  const JournalEntry({required this.id, required this.at, required this.prompt, required this.text, this.mood});
  final String id;
  final DateTime at;
  final String prompt;
  final String text;
  final int? mood;
  Map<String, dynamic> toMap() => {'id': id, 't': at.millisecondsSinceEpoch, 'p': prompt, 'x': text, 'm': mood};
  static JournalEntry? fromMap(Map m) {
    final id = m['id']?.toString();
    if (id == null) return null;
    return JournalEntry(
      id: id,
      at: DateTime.fromMillisecondsSinceEpoch(((m['t'] as num?) ?? 0).toInt()),
      prompt: (m['p'] ?? '').toString(),
      text: (m['x'] ?? '').toString(),
      mood: (m['m'] as num?)?.toInt(),
    );
  }

  static const prompts = [
    'Tulis 3 hal yang kamu syukuri hari ini.',
    'Apa momen terbaik hari ini, sekecil apa pun?',
    'Apa yang sedang membebani pikiranmu? Tulis saja semuanya.',
    'Apa yang kamu pelajari tentang dirimu hari ini?',
    'Apa satu hal baik yang kamu lakukan untuk orang lain atau dirimu sendiri?',
    'Kalau hari ini diulang, apa yang ingin kamu lakukan berbeda?',
    'Apa yang ingin kamu lepaskan sebelum tidur malam ini?',
  ];
  static String promptOfDay([DateTime? d]) {
    final x = d ?? DateTime.now();
    return prompts[(x.year * 372 + x.month * 31 + x.day) % prompts.length];
  }
}

class JournalNotifier extends Notifier<List<JournalEntry>> {
  @override
  List<JournalEntry> build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('journal', const []);
    return raw.whereType<Map>().map(JournalEntry.fromMap).whereType<JournalEntry>().toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  Future<void> _save() => ref.read(settingsRepositoryProvider).set('journal', state.map((e) => e.toMap()).toList());

  Future<JournalEntry> add(String prompt, String text, {int? mood}) async {
    final e = JournalEntry(id: 'j${DateTime.now().microsecondsSinceEpoch}', at: DateTime.now(), prompt: prompt, text: text, mood: mood);
    state = [e, ...state];
    await _save();
    return e;
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> clear() async {
    state = [];
    await _save();
  }
}

final journalProvider = NotifierProvider<JournalNotifier, List<JournalEntry>>(JournalNotifier.new);

/// ---------- Hasil tes ----------
class TestRecord {
  const TestRecord({required this.test, required this.score, required this.max, required this.level, required this.at});
  final String test;
  final int score;
  final int max;
  final String level;
  final DateTime at;
  Map<String, dynamic> toMap() => {'k': test, 's': score, 'x': max, 'l': level, 't': at.millisecondsSinceEpoch};
  static TestRecord? fromMap(Map m) {
    final k = m['k']?.toString();
    if (k == null) return null;
    return TestRecord(
      test: k,
      score: ((m['s'] as num?) ?? 0).toInt(),
      max: ((m['x'] as num?) ?? 0).toInt(),
      level: (m['l'] ?? '').toString(),
      at: DateTime.fromMillisecondsSinceEpoch(((m['t'] as num?) ?? 0).toInt()),
    );
  }
}

class TestsNotifier extends Notifier<List<TestRecord>> {
  @override
  List<TestRecord> build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('psytests', const []);
    return raw.whereType<Map>().map(TestRecord.fromMap).whereType<TestRecord>().toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  Future<void> add(TestRecord r) async {
    state = [r, ...state].take(100).toList();
    await ref.read(settingsRepositoryProvider).set('psytests', state.map((e) => e.toMap()).toList());
  }

  Future<void> clear() async {
    state = [];
    await ref.read(settingsRepositoryProvider).set('psytests', const []);
  }
}

final testsProvider = NotifierProvider<TestsNotifier, List<TestRecord>>(TestsNotifier.new);

/// ---------- Pengaturan pengingat Ruang Tenang ----------
class CalmSettings {
  const CalmSettings({this.checkin = true, this.checkinH = 8, this.journal = true, this.journalH = 21});
  final bool checkin;
  final int checkinH;
  final bool journal;
  final int journalH;
  CalmSettings copyWith({bool? checkin, int? checkinH, bool? journal, int? journalH}) => CalmSettings(
        checkin: checkin ?? this.checkin,
        checkinH: checkinH ?? this.checkinH,
        journal: journal ?? this.journal,
        journalH: journalH ?? this.journalH,
      );
  Map<String, dynamic> toMap() => {'c': checkin, 'ch': checkinH, 'j': journal, 'jh': journalH};
  factory CalmSettings.fromMap(Map m) => CalmSettings(
        checkin: m['c'] != false,
        checkinH: ((m['ch'] as num?) ?? 8).toInt(),
        journal: m['j'] != false,
        journalH: ((m['jh'] as num?) ?? 21).toInt(),
      );
}

class CalmSettingsNotifier extends Notifier<CalmSettings> {
  @override
  CalmSettings build() => CalmSettings.fromMap(ref.read(settingsRepositoryProvider).get<Map>('calm', const {}));

  Future<void> save(CalmSettings s) async {
    state = s;
    await ref.read(settingsRepositoryProvider).set('calm', s.toMap());
    await reschedule();
  }

  Future<void> reschedule() => NotificationService.instance.scheduleCalm(
        checkinHour: state.checkin ? state.checkinH : null,
        journalHour: state.journal ? state.journalH : null,
      );
}

final calmSettingsProvider = NotifierProvider<CalmSettingsNotifier, CalmSettings>(CalmSettingsNotifier.new);
