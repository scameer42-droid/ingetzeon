import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/islam_logic.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

class MuslimSettings {
  const MuslimSettings({
    this.city = 'Jakarta',
    this.lat = -6.2088,
    this.lng = 106.8456,
    this.tz = 7,
    this.auto = false,
    this.adzan = true,
    this.adzanSound = 'penuh',
    this.muted = const {},
    this.done = const {},
    this.tasbih = 0,
    this.lastSurah,
    this.lastAyah,
  });
  final String city;
  final double lat, lng;
  final double tz;
  final bool auto; // dari GPS
  final bool adzan;
  final String adzanSound; // penuh | pendek | notif | getar
  final Set<String> muted; // waktu sholat yang notifikasinya dimatikan
  final Map<String, List<String>> done; // dayKey → sholat yang sudah ditandai
  final int tasbih; // total hitungan tasbih
  final int? lastSurah;
  final int? lastAyah;

  MuslimSettings copyWith({
    String? city,
    double? lat,
    double? lng,
    double? tz,
    bool? auto,
    bool? adzan,
    String? adzanSound,
    Set<String>? muted,
    Map<String, List<String>>? done,
    int? tasbih,
    int? lastSurah,
    int? lastAyah,
  }) =>
      MuslimSettings(
        city: city ?? this.city,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        tz: tz ?? this.tz,
        auto: auto ?? this.auto,
        adzan: adzan ?? this.adzan,
        adzanSound: adzanSound ?? this.adzanSound,
        muted: muted ?? this.muted,
        done: done ?? this.done,
        tasbih: tasbih ?? this.tasbih,
        lastSurah: lastSurah ?? this.lastSurah,
        lastAyah: lastAyah ?? this.lastAyah,
      );

  Map<String, dynamic> toMap() => {
        'city': city,
        'lat': lat,
        'lng': lng,
        'tz': tz,
        'auto': auto,
        'adzan': adzan,
        'snd': adzanSound,
        'muted': muted.toList(),
        'done': done,
        'tasbih': tasbih,
        'ls': lastSurah,
        'la': lastAyah,
      };

  factory MuslimSettings.fromMap(Map m) => MuslimSettings(
        city: (m['city'] ?? 'Jakarta').toString(),
        lat: ((m['lat'] as num?) ?? -6.2088).toDouble(),
        lng: ((m['lng'] as num?) ?? 106.8456).toDouble(),
        tz: ((m['tz'] as num?) ?? 7).toDouble(),
        auto: m['auto'] == true,
        adzan: m['adzan'] != false,
        adzanSound: const ['penuh', 'pendek', 'notif', 'getar'].contains(m['snd']) ? m['snd'] as String : 'penuh',
        muted: {for (final x in (m['muted'] as List? ?? const [])) x.toString()},
        done: {
          for (final e in ((m['done'] as Map?) ?? const {}).entries) e.key.toString(): [for (final x in (e.value as List? ?? const [])) x.toString()],
        },
        tasbih: ((m['tasbih'] as num?) ?? 0).toInt(),
        lastSurah: (m['ls'] as num?)?.toInt(),
        lastAyah: (m['la'] as num?)?.toInt(),
      );

  Map<String, double> timesOn(DateTime d) => PrayerCalc.times(d, lat, lng, tz);

  /// Sholat wajib berikutnya dari [now] (bisa besok subuh).
  ({String key, DateTime at}) next(DateTime now) {
    for (var add = 0; add < 2; add++) {
      final day = DateTime(now.year, now.month, now.day + add);
      final t = timesOn(day);
      for (final k in prayerKeys) {
        final at = PrayerCalc.at(day, t[k]!);
        if (at.isAfter(now)) return (key: k, at: at);
      }
    }
    final day = DateTime(now.year, now.month, now.day + 1);
    return (key: 'subuh', at: PrayerCalc.at(day, timesOn(day)['subuh']!));
  }

  List<String> doneOn(DateTime d) => done[dayKey(d)] ?? const [];
}

class MuslimNotifier extends Notifier<MuslimSettings> {
  @override
  MuslimSettings build() => MuslimSettings.fromMap(ref.read(settingsRepositoryProvider).get<Map>('muslim', const {}));

  Future<void> _save(MuslimSettings s, {bool reschedule = true}) async {
    state = s;
    await ref.read(settingsRepositoryProvider).set('muslim', s.toMap());
    if (reschedule) await this.reschedule();
  }

  Future<void> setLocation({required String city, required double lat, required double lng, required double tz, bool auto = false}) =>
      _save(state.copyWith(city: city, lat: lat, lng: lng, tz: tz, auto: auto));

  Future<void> setAdzan(bool v) => _save(state.copyWith(adzan: v));
  Future<void> setAdzanSound(String v) => _save(state.copyWith(adzanSound: v, adzan: true));

  Future<void> toggleMute(String key) {
    final m = {...state.muted};
    if (!m.remove(key)) m.add(key);
    return _save(state.copyWith(muted: m));
  }

  Future<void> toggleDone(String key, [DateTime? day]) {
    final k = dayKey(day ?? DateTime.now());
    final cur = [...state.doneOn(day ?? DateTime.now())];
    if (!cur.remove(key)) cur.add(key);
    final done = {...state.done, k: cur};
    // simpan 60 hari terakhir saja
    final keys = done.keys.toList()..sort();
    while (keys.length > 60) {
      done.remove(keys.removeAt(0));
    }
    return _save(state.copyWith(done: done), reschedule: false);
  }

  /// Berapa hari berturut-turut 5 waktu lengkap.
  int get streak {
    var d = DateTime.now();
    if (state.doneOn(d).length < 5) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (state.doneOn(d).length >= 5) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  Future<void> addTasbih(int n) => _save(state.copyWith(tasbih: state.tasbih + n), reschedule: false);

  Future<void> setLastRead(int surah, int ayah) => _save(state.copyWith(lastSurah: surah, lastAyah: ayah), reschedule: false);

  /// Jadwalkan notifikasi adzan 7 hari ke depan.
  Future<void> reschedule() async {
    final s = state;
    final items = <({int id, String key, DateTime at, String title, String body})>[];
    if (s.adzan) {
      final now = DateTime.now();
      var i = 0;
      for (var add = 0; add < 3; add++) {
        final day = DateTime(now.year, now.month, now.day + add);
        final t = s.timesOn(day);
        for (final k in prayerKeys) {
          final at = PrayerCalc.at(day, t[k]!);
          if (!s.muted.contains(k) && at.isAfter(now)) {
            items.add((
              id: i,
              key: k,
              at: at,
              title: '🕌 Waktunya sholat ${prayerNames[k]}',
              body: '${prayerNames[k]} ${PrayerCalc.hm(t[k]!)} · ${s.city}. Yuk ambil wudhu, semoga Allah menerima ibadahmu 🤲',
            ));
          }
          i++;
        }
      }
    }
    await NotificationService.instance.schedulePrayers(items, sound: s.adzanSound);
  }
}

final muslimProvider = NotifierProvider<MuslimNotifier, MuslimSettings>(MuslimNotifier.new);
