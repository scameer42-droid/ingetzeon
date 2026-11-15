import 'dart:math' as math;

import 'islam_data.dart';

export 'islam_data.dart';

/// Waktu sholat — metode Kemenag RI (Subuh 20°, Isya 18°, Ashar mazhab Syafi'i, ihtiyat 2 menit).
/// Sinkron dengan versi website (index.html). Bisa beda 1–2 menit dengan jadwal masjid setempat.
class PrayerCalc {
  static const _d = math.pi / 180;
  static double _sin(double d) => math.sin(d * _d);
  static double _cos(double d) => math.cos(d * _d);
  static double _tan(double d) => math.tan(d * _d);
  static double _asin(double x) => math.asin(x) / _d;
  static double _acos(double x) => math.acos(x.clamp(-1.0, 1.0)) / _d;
  static double _atan2(double y, double x) => math.atan2(y, x) / _d;
  static double _acot(double x) => math.atan(1 / x) / _d;
  static double _fixA(double a) {
    a = a - 360 * (a / 360).floorToDouble();
    return a < 0 ? a + 360 : a;
  }

  static double _fixH(double h) {
    h = h - 24 * (h / 24).floorToDouble();
    return h < 0 ? h + 24 : h;
  }

  static double julianDay(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  static ({double decl, double eqt}) _sun(double jd) {
    final dd = jd - 2451545.0;
    final g = _fixA(357.529 + 0.98560028 * dd);
    final q = _fixA(280.459 + 0.98564736 * dd);
    final l = _fixA(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
    final e = 23.439 - 0.00000036 * dd;
    final ra = _fixH(_atan2(_cos(e) * _sin(l), _cos(l)) / 15);
    return (decl: _asin(_sin(e) * _sin(l)), eqt: q / 15 - ra);
  }

  /// Jam desimal waktu setempat (zona [tz]).
  static Map<String, double> times(DateTime date, double lat, double lng, double tz) {
    final jd = julianDay(date.year, date.month, date.day) - lng / (15 * 24);
    double midDay(double t) => _fixH(12 - _sun(jd + t).eqt);
    double angleTime(double ang, double t, {bool ccw = false}) {
      final dec = _sun(jd + t).decl;
      final noon = midDay(t);
      final tt = _acos((-_sin(ang) - _sin(dec) * _sin(lat)) / (_cos(dec) * _cos(lat))) / 15;
      return noon + (ccw ? -tt : tt);
    }

    double asr(double f, double t) {
      final dec = _sun(jd + t).decl;
      return angleTime(-_acot(f + _tan((lat - dec).abs())), t);
    }

    var p = {'fajr': 5.0, 'sunrise': 6.0, 'dhuhr': 12.0, 'asr': 13.0, 'maghrib': 18.0, 'isha': 18.0};
    for (var i = 0; i < 2; i++) {
      final t = p.map((k, v) => MapEntry(k, v / 24));
      p = {
        'fajr': angleTime(20, t['fajr']!, ccw: true),
        'sunrise': angleTime(0.833, t['sunrise']!, ccw: true),
        'dhuhr': midDay(t['dhuhr']!),
        'asr': asr(1, t['asr']!),
        'maghrib': angleTime(0.833, t['maghrib']!),
        'isha': angleTime(18, t['isha']!),
      };
    }
    final adj = tz - lng / 15;
    const ih = 2 / 60;
    return {
      'imsak': p['fajr']! + adj + ih - 10 / 60,
      'subuh': p['fajr']! + adj + ih,
      'terbit': p['sunrise']! + adj - ih,
      'dzuhur': p['dhuhr']! + adj + ih,
      'ashar': p['asr']! + adj + ih,
      'maghrib': p['maghrib']! + adj + ih,
      'isya': p['isha']! + adj + ih,
    };
  }

  /// Ubah jam desimal ke DateTime pada tanggal [date] (dibulatkan ke menit).
  static DateTime at(DateTime date, double hours) {
    final mins = (hours * 60).round();
    return DateTime(date.year, date.month, date.day, 0, mins);
  }

  static String hm(double hours) {
    final t = (hours * 60).round();
    return '${((t ~/ 60) % 24).toString().padLeft(2, '0')}.${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Arah kiblat dari utara (derajat, searah jarum jam).
  static double qibla(double lat, double lng) {
    const kLat = 21.4225, kLng = 39.8262;
    final dl = (kLng - lng) * _d, p1 = lat * _d, p2 = kLat * _d;
    return _fixA(math.atan2(math.sin(dl), math.cos(p1) * math.tan(p2) - math.sin(p1) * math.cos(dl)) / _d);
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final a = math.pow(math.sin((lat2 - lat1) * _d / 2), 2) + math.cos(lat1 * _d) * math.cos(lat2 * _d) * math.pow(math.sin((lng2 - lng1) * _d / 2), 2);
    return 2 * 6371 * math.asin(math.sqrt(a));
  }

  static City nearestCity(double lat, double lng) {
    var best = cities.first;
    var bd = double.infinity;
    for (final c in cities) {
      final d = distanceKm(lat, lng, c.lat, c.lng);
      if (d < bd) {
        bd = d;
        best = c;
      }
    }
    return best;
  }
}

/// Nama 5 waktu sholat wajib.
const prayerKeys = ['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya'];
const prayerNames = {'imsak': 'Imsak', 'subuh': 'Subuh', 'terbit': 'Terbit', 'dzuhur': 'Dzuhur', 'ashar': 'Ashar', 'maghrib': 'Maghrib', 'isya': 'Isya'};

/// Kalender Hijriah aritmetika (bisa beda ±1 hari dengan sidang isbat).
class Hijri {
  const Hijri(this.y, this.m, this.d);
  final int y, m, d;
  static const months = ['Muharram', 'Safar', 'Rabiul Awal', 'Rabiul Akhir', 'Jumadil Awal', 'Jumadil Akhir', 'Rajab', 'Syaban', 'Ramadan', 'Syawal', 'Zulkaidah', 'Zulhijah'];
  String get monthName => months[m - 1];
  @override
  String toString() => '$d $monthName $y H';

  static int _f(num x) => x.floor();

  static Hijri fromDate(DateTime date) {
    final jd = _f(PrayerCalc.julianDay(date.year, date.month, date.day) + 0.5);
    var l = jd - 1948440 + 10632;
    final n = _f((l - 1) / 10631);
    l = l - 10631 * n + 354;
    final j = _f((10985 - l) / 5316) * _f((50 * l) / 17719) + _f(l / 5670) * _f((43 * l) / 15238);
    l = l - _f((30 - j) / 15) * _f((17719 * j) / 50) - _f(j / 16) * _f((15238 * j) / 43) + 29;
    final m = _f((24 * l) / 709);
    final d = l - _f((709 * m) / 24);
    final y = 30 * n + j - 30;
    return Hijri(y, m, d);
  }

  static DateTime toDate(int y, int m, int d) {
    final jd = _f((11 * y + 3) / 30) + 354 * y + 30 * m - _f((m - 1) / 2) + d + 1948440 - 385;
    var l = jd + 68569;
    final n = _f((4 * l) / 146097);
    l = l - _f((146097 * n + 3) / 4);
    final i = _f((4000 * (l + 1)) / 1461001);
    l = l - _f((1461 * i) / 4) + 31;
    final j = _f((80 * l) / 2447);
    final dd = l - _f((2447 * j) / 80);
    l = _f(j / 11);
    return DateTime(100 * (n - 49) + i + l, j + 2 - 12 * l, dd);
  }

  static const _days = [(1, 1, 'Tahun Baru Islam'), (3, 12, 'Maulid Nabi'), (7, 27, 'Isra Mikraj'), (9, 1, 'Awal Ramadan'), (10, 1, 'Idulfitri'), (12, 10, 'Iduladha')];

  /// Hari besar Islam berikutnya (perkiraan).
  static List<({String name, DateTime date, int days, String hijri})> upcoming(DateTime from, {int count = 3}) {
    final h = fromDate(from);
    final start = DateTime(from.year, from.month, from.day);
    final out = <({String name, DateTime date, int days, String hijri})>[];
    for (final yy in [h.y, h.y + 1]) {
      for (final (m, d, name) in _days) {
        final g = toDate(yy, m, d);
        final days = DateTime.utc(g.year, g.month, g.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
        if (days >= 0) out.add((name: name, date: g, days: days, hijri: '$d ${months[m - 1]} $yy'));
      }
    }
    out.sort((a, b) => a.days.compareTo(b.days));
    return out.take(count).toList();
  }
}

/// Pertanyaan seputar sholat/kiblat/doa di chat.
class IslamAsk {
  /// 'jadwal' | 'kiblat' | 'hijri' | nama waktu (subuh…isya, imsak) | null
  static String? prayer(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(arah )?kiblat\b').hasMatch(t)) return 'kiblat';
    if (RegExp(r'\b(tanggal|kalender) (hijriah|hijriyah|islam)\b|\bhijriah\b|\bhijriyah\b').hasMatch(t)) return 'hijri';
    final ask = RegExp(r'\b(jam berapa|kapan|jadwal|waktu|berapa lama lagi|masuk|udah|sudah)\b').hasMatch(t) || t.contains('?');
    final m = RegExp(r'\b(subuh|shubuh|dzuhur|zuhur|duhur|dhuhur|ashar|asar|maghrib|magrib|isya|isha|imsak)\b').firstMatch(t);
    if (m != null && (ask || t.trim().split(RegExp(r'\s+')).length <= 3)) {
      return {'shubuh': 'subuh', 'zuhur': 'dzuhur', 'duhur': 'dzuhur', 'dhuhur': 'dzuhur', 'asar': 'ashar', 'magrib': 'maghrib', 'isha': 'isya'}[m[1]] ?? m[1]!;
    }
    if (RegExp(r'\b(jadwal|waktu) (sholat|salat|shalat|solat)\b|\b(sholat|salat|shalat|solat) (berikutnya|selanjutnya|hari ini)\b').hasMatch(t)) return 'jadwal';
    return null;
  }

  /// Cari doa: "doa sebelum tidur", "bacaan doa makan".
  static Doa? doa(String text) {
    final t = text.toLowerCase();
    if (!RegExp(r'\b(doa|do.a|bacaan|dzikir)\b').hasMatch(t)) return null;
    Doa? best;
    var score = 0;
    for (final d in doaHarian) {
      final words = d.judul.toLowerCase().split(RegExp(r'[\s&]+')).where((w) => w.length > 2);
      final s = words.where(t.contains).length;
      if (s > score) {
        score = s;
        best = d;
      }
    }
    return score > 0 ? best : null;
  }
}
