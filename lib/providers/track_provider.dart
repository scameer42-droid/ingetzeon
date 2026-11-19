import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/i18n/i18n.dart';
import '../core/i18n/tr_text.dart';
import '../services/track_logic.dart';
import '../services/voice_service.dart';
import 'calorie_provider.dart';
import 'settings_provider.dart';
import 'workout_provider.dart';

/// Satu aktivitas GPS yang sudah disimpan.
class Activity {
  Activity({
    required this.id,
    required this.type,
    required this.start,
    required this.title,
    this.note = '',
    required this.segments,
    required this.elapsed,
    required this.kcal,
  });
  final String id;
  final ActivityType type;
  final DateTime start;
  final String title, note;
  final List<List<TrackPoint>> segments;
  final int elapsed; // detik, tanpa jeda manual
  final double kcal;

  TrackStats? _stats;
  TrackStats get stats => _stats ??= TrackStats.compute(segments, type);
  double get distance => stats.distance;
  int get moving => stats.moving;
  List<TrackPoint> get points => [for (final s in segments) ...s];

  Activity copyWith({String? title, String? note, ActivityType? type}) => Activity(
        id: id,
        type: type ?? this.type,
        start: start,
        title: title ?? this.title,
        note: note ?? this.note,
        segments: segments,
        elapsed: elapsed,
        kcal: kcal,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ty': type.name,
        'st': start.millisecondsSinceEpoch,
        'ti': title,
        'no': note,
        'el': elapsed,
        'kc': kcal,
        'sg': [for (final s in segments) [for (final p in s) p.toList()]],
      };

  static Activity? fromMap(Map m) {
    try {
      return Activity(
        id: '${m['id']}',
        type: ActivityType.from(m['ty'] as String?),
        start: DateTime.fromMillisecondsSinceEpoch((m['st'] as num).toInt()),
        title: '${m['ti'] ?? ''}',
        note: '${m['no'] ?? ''}',
        elapsed: (m['el'] as num?)?.toInt() ?? 0,
        kcal: (m['kc'] as num?)?.toDouble() ?? 0,
        segments: [for (final s in (m['sg'] as List? ?? const [])) [for (final p in (s as List)) TrackPoint.fromList(p as List)]],
      );
    } catch (_) {
      return null;
    }
  }
}

/// Rekor pribadi untuk satu jarak.
typedef BestEffort = ({String label, double meters, int secs, Activity activity});

class TrackState {
  const TrackState({this.activities = const [], this.weeklyGoalKm = 20, this.voice = true});
  final List<Activity> activities; // terbaru di depan
  final int weeklyGoalKm;
  final bool voice;

  TrackState copyWith({List<Activity>? activities, int? weeklyGoalKm, bool? voice}) =>
      TrackState(activities: activities ?? this.activities, weeklyGoalKm: weeklyGoalKm ?? this.weeklyGoalKm, voice: voice ?? this.voice);

  static DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  List<Activity> inWeek(DateTime anyDay) {
    final s = weekStart(anyDay), e = s.add(const Duration(days: 7));
    return activities.where((a) => !a.start.isBefore(s) && a.start.isBefore(e)).toList();
  }

  double weekKm(DateTime anyDay) => inWeek(anyDay).fold(0.0, (a, x) => a + x.distance) / 1000;

  /// Rekor tercepat per jarak, hanya untuk aktivitas lari.
  List<BestEffort> bestEfforts({ActivityType type = ActivityType.lari}) {
    final out = <BestEffort>[];
    for (final (m, label) in bestDistances) {
      BestEffort? best;
      for (final a in activities.where((a) => a.type == type)) {
        final t = a.stats.bestEffort(m);
        if (t != null && (best == null || t < best.secs)) best = (label: label, meters: m, secs: t, activity: a);
      }
      if (best != null) out.add(best);
    }
    return out;
  }

  Activity? get longest => activities.isEmpty ? null : activities.reduce((a, b) => a.distance >= b.distance ? a : b);
  Activity? get mostClimb => activities.isEmpty ? null : activities.reduce((a, b) => a.stats.elevGain >= b.stats.elevGain ? a : b);

  Map<String, dynamic> toMap() => {'a': activities.map((a) => a.toMap()).toList(), 'g': weeklyGoalKm, 'v': voice};
  factory TrackState.fromMap(Map m) => TrackState(
        activities: ((m['a'] as List?) ?? const []).whereType<Map>().map(Activity.fromMap).whereType<Activity>().toList(),
        weeklyGoalKm: (m['g'] as num?)?.toInt() ?? 20,
        voice: m['v'] != false,
      );
}

class TrackNotifier extends Notifier<TrackState> {
  @override
  TrackState build() {
    final raw = ref.read(settingsRepositoryProvider).get<String>('track', '');
    if (raw.isEmpty) return const TrackState();
    try {
      return TrackState.fromMap(jsonDecode(raw) as Map);
    } catch (_) {
      return const TrackState();
    }
  }

  Future<void> _save(TrackState s) async {
    state = s;
    await ref.read(settingsRepositoryProvider).set('track', jsonEncode(s.toMap()));
  }

  Future<Activity> add(Activity a) async {
    await _save(state.copyWith(activities: [a, ...state.activities].take(200).toList()));
    // ikut tercatat di Olahraga → menit mingguan & kalori terbakar
    await ref.read(workoutProvider.notifier).add(name: a.title, secs: a.moving, kcal: a.kcal, program: 'gps', emoji: a.type.emoji, at: a.start);
    return a;
  }

  Future<void> update(Activity a) => _save(state.copyWith(activities: [for (final x in state.activities) x.id == a.id ? a : x]));
  Future<void> remove(String id) => _save(state.copyWith(activities: state.activities.where((a) => a.id != id).toList()));
  Future<void> setGoal(int km) => _save(state.copyWith(weeklyGoalKm: km.clamp(1, 1000).toInt()));
  Future<void> setVoice(bool v) => _save(state.copyWith(voice: v));
}

final trackProvider = NotifierProvider<TrackNotifier, TrackState>(TrackNotifier.new);

// ---------------------------------------------------------------- perekam

enum RecStatus { idle, recording, paused }

class RecState {
  const RecState({this.status = RecStatus.idle, this.type = ActivityType.lari, this.segments = const [], this.elapsedMs = 0, this.here, this.stats, this.gpsOk = false, this.error});
  final RecStatus status;
  final ActivityType type;
  final List<List<TrackPoint>> segments;
  final int elapsedMs;
  final TrackPoint? here; // posisi terkini (walau tidak disimpan)
  final TrackStats? stats;
  final bool gpsOk; // akurasi sudah cukup
  final String? error;

  bool get active => status != RecStatus.idle;
  RecState copyWith({RecStatus? status, ActivityType? type, List<List<TrackPoint>>? segments, int? elapsedMs, TrackPoint? here, TrackStats? stats, bool? gpsOk, String? error}) => RecState(
        status: status ?? this.status,
        type: type ?? this.type,
        segments: segments ?? this.segments,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        here: here ?? this.here,
        stats: stats ?? this.stats,
        gpsOk: gpsOk ?? this.gpsOk,
        error: error,
      );
}

/// Mengatur GPS saat merekam: izin, aliran lokasi (dengan notifikasi tetap supaya jalan saat layar mati),
/// saringan titik, jeda/lanjut, dan aba-aba suara tiap 1 km.
class RecorderNotifier extends Notifier<RecState> {
  StreamSubscription<Position>? _sub;
  Timer? _tick;
  PointFilter? _filter;
  DateTime? _since; // awal potongan waktu berjalan
  int _accMs = 0;
  int _lastKm = 0;
  DateTime? _startedAt;

  @override
  RecState build() {
    ref.onDispose(_stopStream);
    return const RecState();
  }

  void setType(ActivityType t) {
    if (state.status == RecStatus.idle) state = state.copyWith(type: t);
  }

  /// Minta izin & nyalakan GPS (tanpa mulai merekam) supaya posisi siap. Mengembalikan pesan error bila gagal.
  Future<String?> warmUp() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return tr('Aktifkan GPS/lokasi di HP dulu ya');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return tr('Izin lokasi ditolak. Buka pengaturan aplikasi untuk mengizinkan lokasi.');
      _listen();
      return null;
    } catch (e) {
      return tr('GPS tidak bisa dipakai di perangkat ini.');
    }
  }

  void _listen() {
    if (_sub != null) return;
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: tr('IngetZeon sedang merekam aktivitas'),
              notificationText: tr('GPS tetap aktif walau layar mati'),
              notificationIcon: const AndroidResource(name: 'ic_notification', defType: 'drawable'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPos, onError: (_) {
      state = state.copyWith(error: tr('Sinyal GPS hilang. Coba di tempat terbuka.'));
    });
  }

  void _onPos(Position pos) {
    final p = TrackPoint(pos.latitude, pos.longitude, pos.timestamp, alt: pos.altitude == 0 ? null : pos.altitude, acc: pos.accuracy);
    final good = pos.accuracy <= 25;
    if (state.status != RecStatus.recording) {
      state = state.copyWith(here: p, gpsOk: good);
      return;
    }
    if (_filter!.accept(p)) {
      final segs = [...state.segments];
      segs[segs.length - 1] = [...segs.last, p];
      final st = TrackStats.compute(segs, state.type);
      state = state.copyWith(segments: segs, here: p, stats: st, gpsOk: good);
      _cue(st);
    } else {
      state = state.copyWith(here: p, gpsOk: good);
    }
  }

  void start() {
    _startedAt = DateTime.now();
    _filter = PointFilter(state.type);
    _accMs = 0;
    _since = DateTime.now();
    _lastKm = 0;
    state = RecState(status: RecStatus.recording, type: state.type, segments: const [[]], here: state.here, gpsOk: state.gpsOk);
    _listen();
    WakelockPlus.enable().catchError((_) {});
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == RecStatus.recording) state = state.copyWith(elapsedMs: _accMs + DateTime.now().difference(_since!).inMilliseconds);
    });
    _say('${tr('Mulai')} ${tr(state.type.label).toLowerCase()}');
  }

  void pause() {
    if (state.status != RecStatus.recording) return;
    _accMs += DateTime.now().difference(_since!).inMilliseconds;
    state = state.copyWith(status: RecStatus.paused, elapsedMs: _accMs);
    _say(tr('Dijeda'));
  }

  void resume() {
    if (state.status != RecStatus.paused) return;
    _since = DateTime.now();
    _filter!.reset();
    state = state.copyWith(status: RecStatus.recording, segments: [...state.segments, []]);
    _say(tr('Lanjutkan'));
  }

  /// Hentikan perekaman. Mengembalikan aktivitas (belum disimpan) bila ada jarak tercatat.
  Activity? finish() {
    if (state.status == RecStatus.recording) _accMs += DateTime.now().difference(_since!).inMilliseconds;
    final segs = state.segments.where((s) => s.length >= 2).map((s) => thin(s, 2500)).toList();
    final type = state.type;
    final started = _startedAt ?? DateTime.now();
    final elapsed = (_accMs / 1000).round();
    _reset();
    if (segs.isEmpty) return null;
    final st = TrackStats.compute(segs, type);
    if (st.distance < 20) return null;
    final kg = ref.read(calorieProvider).profile?.kg ?? 65;
    return Activity(
      id: '${started.millisecondsSinceEpoch}',
      type: type,
      start: started,
      title: tr(autoTitle(type, started)),
      segments: segs,
      elapsed: elapsed,
      kcal: activityKcal(type, st.distance, st.moving, kg),
    );
  }

  void discard() => _reset();

  void _reset() {
    _stopStream();
    WakelockPlus.disable().catchError((_) {});
    state = RecState(type: state.type);
  }

  void _stopStream() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
  }

  void _cue(TrackStats st) {
    final km = (st.distance / 1000).floor();
    if (km <= _lastKm || st.splits.isEmpty) return;
    _lastKm = km;
    final sp = st.splits[km - 1];
    final speed = state.type.usesSpeed ? '${tr('kecepatan')} ${(1000 / sp.secs * 3.6).toStringAsFixed(1).replaceAll('.', ',')} ${tr('kilometer per jam')}' : '${tr('pace')} ${_paceWords(sp.pace)}';
    _say('$km ${tr('kilometer')}. ${tr('Waktu')} ${_durWords(st.moving)}. $speed');
  }

  String _paceWords(double p) => '${p ~/ 60} ${tr('menit')} ${(p % 60).round()} ${tr('detik')}';
  String _durWords(int s) => s >= 3600 ? '${s ~/ 3600} ${tr('jam')} ${(s % 3600) ~/ 60} ${tr('menit')}' : '${s ~/ 60} ${tr('menit')} ${s % 60} ${tr('detik')}';

  void _say(String t) {
    if (!ref.read(trackProvider).voice) return;
    VoiceService.instance.speakIn(t, I18n.isEn ? 'en' : 'id').catchError((_) {});
  }
}

final recorderProvider = NotifierProvider<RecorderNotifier, RecState>(RecorderNotifier.new);
