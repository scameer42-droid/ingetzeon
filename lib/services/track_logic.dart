import 'dart:math' as math;

/// Perhitungan rekam aktivitas GPS (gaya Strava): jarak, waktu bergerak, pace, elevasi,
/// split per km, rekor jarak (best effort), kalori, dan ekspor GPX. Murni Dart, mudah dites.

enum ActivityType {
  lari('Lari', '🏃', 12.0, .9),
  jalan('Jalan', '🚶', 4.5, .5),
  sepeda('Sepeda', '🚴', 25.0, 1.5),
  hiking('Hiking', '🥾', 4.5, .4);

  const ActivityType(this.label, this.emoji, this.maxSpeed, this.minMoving);
  final String label, emoji;

  /// Kecepatan maksimum wajar (m/s); titik yang lebih cepat dianggap GPS meloncat.
  final double maxSpeed;

  /// Kecepatan minimum (m/s) supaya dihitung sebagai bergerak (jeda otomatis di bawahnya).
  final double minMoving;

  /// Sepeda ditampilkan sebagai km/jam, yang lain sebagai pace menit/km.
  bool get usesSpeed => this == ActivityType.sepeda;

  static ActivityType from(String? n) => ActivityType.values.firstWhere((t) => t.name == n, orElse: () => ActivityType.lari);

  /// MET (Compendium of Physical Activities) menurut kecepatan rata-rata km/jam.
  double met(double kmh) {
    switch (this) {
      case ActivityType.lari:
        return kmh < 8 ? 8.3 : kmh < 9.7 ? 9.8 : kmh < 11.3 ? 11.0 : kmh < 12.9 ? 11.8 : 12.8;
      case ActivityType.jalan:
        return kmh < 4 ? 3.0 : kmh < 5.6 ? 3.5 : 5.0;
      case ActivityType.sepeda:
        return kmh < 16 ? 4.0 : kmh < 19 ? 6.8 : kmh < 22.5 ? 8.0 : kmh < 25.7 ? 10.0 : 12.0;
      case ActivityType.hiking:
        return 6.0;
    }
  }
}

/// Satu titik GPS.
class TrackPoint {
  const TrackPoint(this.lat, this.lon, this.t, {this.alt, this.acc = 5});
  final double lat, lon;
  final double? alt;
  final double acc; // akurasi (meter)
  final DateTime t;

  List<num> toList() => [double.parse(lat.toStringAsFixed(6)), double.parse(lon.toStringAsFixed(6)), alt == null ? -9999 : alt!.round(), t.millisecondsSinceEpoch];
  static TrackPoint fromList(List l) => TrackPoint((l[0] as num).toDouble(), (l[1] as num).toDouble(), DateTime.fromMillisecondsSinceEpoch((l[3] as num).toInt()),
      alt: (l[2] as num) <= -9999 ? null : (l[2] as num).toDouble());
}

/// Jarak dua titik (meter), rumus haversine.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// Format pace (detik per km) → "5:32".
String fmtPace(double secPerKm) {
  if (!secPerKm.isFinite || secPerKm <= 0 || secPerKm > 3600) return '–:––';
  final s = secPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Format durasi → "1:02:05" atau "32:10".
String fmtDur(int secs) {
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
}

/// Format jarak meter → "5,23" (km, 2 desimal, koma).
String fmtKm(double m, [int dec = 2]) => (m / 1000).toStringAsFixed(dec).replaceAll('.', ',');

/// Satu split (biasanya per 1 km).
class Split {
  const Split(this.index, this.meters, this.secs, this.elev);
  final int index; // 1, 2, 3…
  final double meters; // panjang split (km terakhir bisa < 1000)
  final int secs; // waktu bergerak
  final double elev; // naik-turun bersih (m)
  double get pace => meters <= 0 ? 0 : secs / (meters / 1000);
}

/// Hasil perhitungan dari daftar segmen titik (segmen terpisah saat dijeda manual).
class TrackStats {
  TrackStats._(this.distance, this.moving, this.elevGain, this.cumDist, this.cumTime, this.cumAlt, this.splits);
  final double distance; // meter
  final int moving; // detik bergerak
  final double elevGain; // meter
  final List<double> cumDist, cumTime, cumAlt; // per titik yang dipakai (untuk grafik & rekor)
  final List<Split> splits;

  double get avgPace => distance < 10 ? 0 : moving / (distance / 1000);
  double get avgKmh => moving <= 0 ? 0 : distance / moving * 3.6;

  factory TrackStats.compute(List<List<TrackPoint>> segments, ActivityType type) {
    var dist = 0.0, moving = 0.0;
    final cumDist = <double>[], cumTime = <double>[], cumAlt = <double>[];
    // elevasi: rata-rata bergerak 5 titik, lalu histeresis 3 m supaya derau GPS tidak terhitung
    var gain = 0.0;
    double? ref;
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      final alts = _smooth(seg.map((p) => p.alt).toList());
      for (var i = 0; i < seg.length; i++) {
        if (i > 0) {
          final a = seg[i - 1], b = seg[i];
          final d = haversine(a.lat, a.lon, b.lat, b.lon);
          final dt = b.t.difference(a.t).inMilliseconds / 1000;
          dist += d;
          if (dt > 0 && dt <= 30 && d / dt >= type.minMoving) moving += dt;
        }
        final al = alts[i];
        if (al != null) {
          if (ref == null) {
            ref = al;
          } else if (al - ref >= 3) {
            gain += al - ref;
            ref = al;
          } else if (ref - al >= 3) {
            ref = al;
          }
        }
        cumDist.add(dist);
        cumTime.add(moving);
        cumAlt.add(al ?? (cumAlt.isEmpty ? 0 : cumAlt.last));
      }
    }
    // split per km dengan interpolasi di batas km
    final splits = <Split>[];
    var lastD = 0.0, lastT = 0.0, lastA = cumAlt.isEmpty ? 0.0 : cumAlt.first;
    var k = 1;
    for (var i = 1; i < cumDist.length; i++) {
      while (cumDist[i] >= k * 1000) {
        final f = (k * 1000 - cumDist[i - 1]) / math.max(1e-9, cumDist[i] - cumDist[i - 1]);
        final t = cumTime[i - 1] + f * (cumTime[i] - cumTime[i - 1]);
        final a = cumAlt[i - 1] + f * (cumAlt[i] - cumAlt[i - 1]);
        splits.add(Split(k, 1000, (t - lastT).round(), a - lastA));
        lastD = k * 1000.0;
        lastT = t;
        lastA = a;
        k++;
      }
    }
    if (dist - lastD >= 50 && cumDist.isNotEmpty) {
      splits.add(Split(k, dist - lastD, (moving - lastT).round(), cumAlt.last - lastA));
    }
    return TrackStats._(dist, moving.round(), gain, cumDist, cumTime, cumAlt, splits);
  }

  /// Waktu tercepat (detik) untuk menempuh [meters] di dalam aktivitas ini; null bila belum sejauh itu.
  int? bestEffort(double meters) {
    if (distance < meters || cumDist.length < 2) return null;
    double? best;
    var j = 0;
    for (var i = 0; i < cumDist.length; i++) {
      // geser awal jendela sejauh mungkin selama sisa jarak masih ≥ meters
      while (j + 1 < cumDist.length && cumDist[i] - cumDist[j + 1] >= meters) {
        j++;
      }
      if (cumDist[i] - cumDist[j] >= meters) {
        // interpolasi supaya jendela tepat sepanjang [meters]
        final over = cumDist[i] - cumDist[j] - meters;
        final segD = i > 0 ? cumDist[i] - cumDist[i - 1] : 0.0;
        final segT = i > 0 ? cumTime[i] - cumTime[i - 1] : 0.0;
        final t = (cumTime[i] - cumTime[j]) - (segD > 0 ? over / segD * segT : 0);
        if (best == null || t < best) best = t;
      }
    }
    return best?.round();
  }

  static List<double?> _smooth(List<double?> v) {
    return [
      for (var i = 0; i < v.length; i++)
        () {
          final w = [for (var j = math.max(0, i - 2); j <= math.min(v.length - 1, i + 2); j++) v[j]].whereType<double>().toList();
          return w.isEmpty ? null : w.reduce((a, b) => a + b) / w.length;
        }(),
    ];
  }
}

/// Saringan titik GPS saat merekam: buang titik tidak akurat, terlalu dekat, atau meloncat.
class PointFilter {
  PointFilter(this.type);
  final ActivityType type;
  TrackPoint? _last;

  void reset() => _last = null;

  /// true bila titik layak disimpan.
  bool accept(TrackPoint p) {
    if (p.acc > 35) return false;
    final l = _last;
    if (l == null) {
      _last = p;
      return true;
    }
    final d = haversine(l.lat, l.lon, p.lat, p.lon);
    final dt = p.t.difference(l.t).inMilliseconds / 1000;
    if (dt <= 0) return false;
    if (d / dt > type.maxSpeed) return false; // loncatan GPS
    if (d < math.max(3, p.acc * .4) && dt < 15) return false; // diam di tempat / derau kecil
    _last = p;
    return true;
  }
}

/// Kalori perkiraan: MET × berat (kg) × jam bergerak.
double activityKcal(ActivityType t, double meters, int movingSecs, double kg) {
  if (movingSecs <= 0) return 0;
  final kmh = meters / movingSecs * 3.6;
  return t.met(kmh) * kg * movingSecs / 3600;
}

/// Jarak rekor yang dilacak (meter, label).
const bestDistances = <(double, String)>[(1000, '1 km'), (5000, '5 km'), (10000, '10 km'), (21097.5, 'Half marathon')];

/// Ubah titik menjadi file GPX 1.1.
String toGpx({required String name, required ActivityType type, required List<List<TrackPoint>> segments}) {
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="IngetZeon" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('<trk><name>${esc(name)}</name><type>${type == ActivityType.sepeda ? 'cycling' : type == ActivityType.lari ? 'running' : type == ActivityType.hiking ? 'hiking' : 'walking'}</type>');
  for (final seg in segments) {
    if (seg.isEmpty) continue;
    b.writeln('<trkseg>');
    for (final p in seg) {
      b.write('<trkpt lat="${p.lat.toStringAsFixed(6)}" lon="${p.lon.toStringAsFixed(6)}">');
      if (p.alt != null) b.write('<ele>${p.alt!.toStringAsFixed(1)}</ele>');
      b.writeln('<time>${p.t.toUtc().toIso8601String()}</time></trkpt>');
    }
    b.writeln('</trkseg>');
  }
  b.writeln('</trk></gpx>');
  return b.toString();
}

/// Kurangi jumlah titik untuk disimpan (pertahankan bentuk rute): ambil tiap n titik + titik akhir.
List<TrackPoint> thin(List<TrackPoint> pts, int max) {
  if (pts.length <= max) return pts;
  final step = pts.length / max;
  return [for (var i = 0; i < max; i++) pts[(i * step).floor()], pts.last];
}

/// Judul otomatis seperti Strava: "Lari pagi", "Sepeda sore", dst.
String autoTitle(ActivityType t, DateTime at) {
  final h = at.hour;
  final part = h < 4 ? 'malam' : h < 11 ? 'pagi' : h < 15 ? 'siang' : h < 18 ? 'sore' : 'malam';
  return '${t.label} $part';
}

/// Pace km yang sedang berjalan (detik/km), seperti "Pace split" di Strava. 0 bila belum cukup jarak.
double currentSplitPace(TrackStats st) {
  final full = (st.distance / 1000).floor();
  final doneSecs = st.splits.where((s) => s.meters >= 999).take(full).fold(0, (a, s) => a + s.secs);
  final d = st.distance - full * 1000, t = st.moving - doneSecs;
  if (d < 50 || t <= 0) return full > 0 && st.splits.isNotEmpty ? st.splits[full - 1].pace : 0;
  return t / (d / 1000);
}

/// Lap dari penanda kumulatif [meter, detik bergerak] + sisa sampai akhir aktivitas.
List<Split> lapsFrom(List<(double, int)> marks, TrackStats st) {
  if (marks.isEmpty) return const [];
  final out = <Split>[];
  var pd = 0.0, pt = 0;
  for (final (m, s) in [...marks, (st.distance, st.moving)]) {
    if (m - pd < 10) continue;
    out.add(Split(out.length + 1, m - pd, s - pt, 0));
    pd = m;
    pt = s;
  }
  return out;
}

/// Label usaha (RPE 1–10) seperti "Perceived Exertion" Strava.
String rpeLabel(int v) => v <= 0 ? '' : v <= 3 ? 'Ringan' : v <= 6 ? 'Sedang' : v <= 8 ? 'Berat' : 'Maksimal';
