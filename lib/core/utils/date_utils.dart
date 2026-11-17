/// Alat bantu tanggal & waktu berbahasa Indonesia.
library;

import '../i18n/i18n.dart';

const hariList = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const hariShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
const bulanList = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const bulanShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// 0 = Minggu ... 6 = Sabtu.
int jsDay(DateTime d) => d.weekday % 7;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String fmtTime(DateTime d) => '${two(d.hour)}.${two(d.minute)}';

const dayListEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const dayShortEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const monthListEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const monthShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Nama hari/bulan sesuai bahasa tampilan.
String dayName(DateTime d) => (I18n.isEn ? dayListEn : hariList)[jsDay(d)];
String dayShortName(DateTime d) => (I18n.isEn ? dayShortEn : hariShort)[jsDay(d)];
String monthName(int m) => (I18n.isEn ? monthListEn : bulanList)[m - 1];
String monthShortName(int m) => (I18n.isEn ? monthShortEn : bulanShort)[m - 1];

String fmtDateLong(DateTime d) => I18n.isEn
    ? '${dayName(d)}, ${monthName(d.month)} ${d.day}, ${d.year}'
    : '${hariList[jsDay(d)]}, ${d.day} ${bulanList[d.month - 1]} ${d.year}';

String fmtDateShort(DateTime d) => I18n.isEn
    ? '${dayShortName(d)}, ${monthShortName(d.month)} ${d.day}'
    : '${hariShort[jsDay(d)]}, ${d.day} ${bulanShort[d.month - 1]}';

String toLocalIso(DateTime d) => '${dayKey(d)}T${two(d.hour)}:${two(d.minute)}';

/// Membaca "YYYY-MM-DDTHH:mm" (boleh ada detik/zona, diabaikan) sebagai waktu lokal.
DateTime? parseLocalIso(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
  );
}

String dayLabel(DateTime d, [DateTime? now]) {
  final t = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(d).difference(t).inHours / 24;
  final days = diff.round();
  if (days == 0) return 'Hari ini';
  if (days == 1) return 'Besok';
  if (days == 2) return 'Lusa';
  if (days == -1) return 'Kemarin';
  return fmtDateShort(d);
}

String countdown(DateTime d, [DateTime? now]) {
  final ms = d.difference(now ?? DateTime.now()).inMilliseconds;
  if (ms <= 0) return 'sekarang';
  final min = (ms / 60000).round();
  if (min < 1) return 'kurang dari 1 menit lagi';
  if (min < 60) return '$min menit lagi';
  final h = min ~/ 60, m = min % 60;
  if (h < 24) return m > 0 ? '$h jam $m menit lagi' : '$h jam lagi';
  return '${(h / 24).round()} hari lagi';
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 4 && h < 11) return 'Selamat Pagi';
  if (h >= 11 && h < 15) return 'Selamat Siang';
  if (h >= 15 && h < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

/// "07.30" → "7 lewat 30" agar enak dibacakan suara.
String speakTime(DateTime d) => d.minute == 0 ? '${d.hour}' : '${d.hour} lewat ${d.minute}';

/// Durasi sejak [from], mis. "1 jam 23 menit".
String elapsed(DateTime from, [DateTime? now]) {
  final m = (now ?? DateTime.now()).difference(from).inMinutes;
  if (m < 1) return 'baru saja';
  final h = m ~/ 60, mm = m % 60;
  if (h == 0) return '$mm menit';
  return mm == 0 ? '$h jam' : '$h jam $mm menit';
}
