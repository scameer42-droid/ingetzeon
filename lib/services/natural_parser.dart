import '../core/utils/date_utils.dart';
import '../data/models/reminder.dart';
import 'vocab.dart';

/// Hasil pemahaman kalimat menjadi data pengingat.
class ParsedReminder {
  const ParsedReminder({
    required this.title,
    this.note,
    required this.scheduledAt,
    required this.repeat,
    required this.category,
    this.alarm = true,
  });

  final String title;
  final String? note;
  final DateTime scheduledAt;
  final RepeatType repeat;
  final ReminderCategory category;

  /// false = catatan tanpa bunyi (mis. catatan parkir tanpa jam).
  final bool alarm;

  @override
  String toString() => '$title | ${toLocalIso(scheduledAt)} | ${repeat.name} | ${category.name}';
}

/// Pemahaman bahasa alami (Bahasa Indonesia) yang bekerja tanpa internet.
/// Dipakai saat kunci Gemini belum diisi atau Gemini gagal dihubungi.
class NaturalParser {
  NaturalParser._();

  static const _dayMap = {
    'minggu': 0, 'ahad': 0, 'senin': 1, 'selasa': 2, 'rabu': 3,
    'kamis': 4, 'jumat': 5, "jum'at": 5, 'sabtu': 6,
  };

  static const _monthMap = {
    'januari': 1, 'jan': 1, 'februari': 2, 'feb': 2, 'pebruari': 2, 'maret': 3, 'mar': 3,
    'april': 4, 'apr': 4, 'mei': 5, 'juni': 6, 'jun': 6, 'juli': 7, 'jul': 7,
    'agustus': 8, 'agu': 8, 'agt': 8, 'ags': 8, 'september': 9, 'sep': 9, 'sept': 9,
    'oktober': 10, 'okt': 10, 'november': 11, 'nov': 11, 'nopember': 11, 'desember': 12, 'des': 12,
  };

  static const _numWords = {
    'se': 1, 'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5, 'enam': 6, 'tujuh': 7,
    'delapan': 8, 'sembilan': 9, 'sepuluh': 10, 'sebelas': 11, 'dua belas': 12,
    'lima belas': 15, 'dua puluh': 20, 'tiga puluh': 30, 'empat puluh lima': 45,
  };

  static const _numRe =
      r'(\d+|se|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh|sebelas|dua belas|lima belas|dua puluh|tiga puluh|empat puluh lima)';

  static const Map<ReminderCategory, List<String>> _catWords = {
    ReminderCategory.parkir: ['parkir', 'parkiran', 'basement', 'lahan parkir', 'tempat parkir'],
    ReminderCategory.kesehatan: [
      'obat', 'olahraga', 'olah raga', 'minum air', 'air putih', 'vitamin', 'dokter', 'gym', 'fitness',
      'lari', 'jogging', 'joging', 'senam', 'yoga', 'tidur', 'istirahat', 'check up', 'kontrol', 'periksa',
      'suntik', 'vaksin', 'diet', 'sarapan', 'makan siang', 'makan malam', 'jalan pagi', 'renang',
      'bersepeda', 'sepeda', 'stretching', 'peregangan', 'terapi', 'gigi',
    ],
    ReminderCategory.kerja: [
      'meeting', 'rapat', 'kerja', 'kantor', 'klien', 'client', 'laporan', 'deadline', 'presentasi',
      'invoice', 'email', 'proposal', 'kontrak', 'stok', 'order', 'pesanan', 'kirim paket', 'packing',
      'toko', 'shopee', 'tiktok', 'live', 'gaji karyawan', 'karyawan', 'supplier', 'produksi', 'admin',
      'closing', 'target', 'penjualan', 'zoom', 'wawancara', 'interview',
    ],
    ReminderCategory.edukasi: [
      'belajar', 'kuliah', 'kelas', 'ujian', 'tugas', 'pr ', 'baca', 'membaca', 'kursus', 'les', 'skripsi',
      'sekolah', 'webinar', 'latihan soal', 'hafalan', 'ngaji', 'mengaji', 'kajian', 'seminar',
      'bahasa inggris', 'tutorial', 'materi',
    ],
    ReminderCategory.pribadi: [
      'ulang tahun', 'ultah', 'keluarga', 'ibu', 'ayah', 'mama', 'papa', 'istri', 'suami', 'anak', 'pacar',
      'teman', 'belanja', 'bayar', 'arisan', 'jemput', 'antar', 'telepon', 'telpon', 'video call', 'masak',
      'cuci', 'setrika', 'bersih', 'sholat', 'salat', 'shalat', 'ibadah', 'gereja', 'jemuran', 'listrik',
      'pdam', 'cicilan', 'tabung', 'nabung', 'servis', 'motor', 'mobil', 'potong rambut', 'nikahan',
      'kondangan', 'liburan', 'tiket', 'paket',
    ],
  };

  static const _stopWords = {
    'tolong', 'tlg', 'please', 'plis', 'hai', 'halo', 'hei', 'hey', 'bro', 'sis', 'kak', 'min',
    'ingatkan', 'ingetin', 'ingatin', 'ingetkan', 'ingat', 'inget', 'remind', 'reminder', 'jadwalkan',
    'catat', 'pengingat', 'bikin', 'alarm', 'jadwalkan', 'setel',
    'aku', 'saya', 'gue', 'gua', 'gw', 'daku', 'kami', 'kita', 'ku',
    'ya', 'yah', 'yaa', 'dong', 'deh', 'nih', 'ok', 'oke', 'okey', 'yuk', 'ntar', 'lagi', 'pada',
    'hari', 'jam', 'pukul', 'setiap', 'tiap', 'nya',
  };

  static const _leadingWords = {
    'untuk', 'utk', 'tuk', 'buat', 'agar', 'supaya', 'biar', 'kalau', 'klo', 'kalo', 'bahwa', 'soal',
    'tentang', 'mengenai', 'harus', 'mau', 'akan', 'ada',
  };

  /// Menebak kategori dari kata kunci.
  static ReminderCategory? guessCategory(String text) {
    final t = ' ${text.toLowerCase()} ';
    for (final e in _catWords.entries) {
      if (e.value.any(t.contains)) return e.key;
    }
    return null;
  }

  static int? _wordNum(String s) => int.tryParse(s) ?? _numWords[s];

  static ParsedReminder parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    input = Vocab.normalize(input).trim();
    var t = input
        .toLowerCase()
        .replaceAll(RegExp(r'[,!?;"]'), ' ')
        .replaceAllMapped(RegExp(r'(\d)\s*[:.]\s*(\d{2})(?!\d)'), (m) => '${m[1]}:${m[2]}')
        .replaceAll(RegExp(r'\s+'), ' ');
    t = ' $t ';

    void cut(RegExp re) => t = t.replaceFirst(re, ' ');

    var repeat = RepeatType.once;
    int? weekday; // 0 = Minggu
    int? monthDay;
    DateTime? date;
    var explicitDate = false;
    int? hour;
    var minute = 0;
    String? period;
    Duration? rel;
    int? hourOverride;
    RegExpMatch? m;

    // ---------- pengulangan ----------
    final weeklyDay = RegExp(
        r" (?:setiap|tiap|tiap-tiap) (?:hari )?(senin|selasa|rabu|kamis|jumat|jum'at|sabtu|ahad)(?: (?:pagi|siang|sore|malam))? ");
    if ((m = weeklyDay.firstMatch(t)) != null) {
      repeat = RepeatType.weekly;
      weekday = _dayMap[m!.group(1)];
      cut(RegExp(r" (?:setiap|tiap|tiap-tiap) (?:hari )?(?:senin|selasa|rabu|kamis|jumat|jum'at|sabtu|ahad)"));
    } else if (RegExp(r' (?:setiap|tiap) (?:hari )?minggu (?:pagi|siang|sore|malam) ').hasMatch(t) ||
        RegExp(r' (?:setiap|tiap) hari minggu ').hasMatch(t)) {
      repeat = RepeatType.weekly;
      weekday = 0;
      cut(RegExp(r' (?:setiap|tiap) (?:hari )?minggu'));
    } else if ((m = RegExp(r' (?:setiap|tiap) (hari|pagi|siang|sore|malam|subuh) ').firstMatch(t)) != null) {
      repeat = RepeatType.daily;
      if (m!.group(1) != 'hari') period = m.group(1);
      cut(RegExp(r' (?:setiap|tiap) (?:hari|pagi|siang|sore|malam|subuh)'));
    } else if (RegExp(r' (sehari-hari|harian|tiap-tiap hari|sehari sekali) ').hasMatch(t)) {
      repeat = RepeatType.daily;
      cut(RegExp(r' (sehari-hari|harian|tiap-tiap hari|sehari sekali)'));
    } else if (RegExp(r' ((?:setiap|tiap) (?:minggu|pekan)|seminggu sekali|mingguan) ').hasMatch(t)) {
      repeat = RepeatType.weekly;
      cut(RegExp(r' ((?:setiap|tiap) (?:minggu|pekan)|seminggu sekali|mingguan)'));
    } else if ((m = RegExp(r' (?:setiap|tiap) tanggal (\d{1,2}) ').firstMatch(t)) != null) {
      repeat = RepeatType.monthly;
      monthDay = int.parse(m!.group(1)!).clamp(1, 31);
      cut(RegExp(r' (?:setiap|tiap) tanggal \d{1,2}'));
    } else if (RegExp(r' ((?:setiap|tiap) bulan|sebulan sekali|bulanan) ').hasMatch(t)) {
      repeat = RepeatType.monthly;
      cut(RegExp(r' ((?:setiap|tiap) bulan|sebulan sekali|bulanan)'));
    }

    // ---------- waktu relatif ----------
    m = RegExp(' (?:dalam )?$_numRe ?(menit|mnt|jam) (?:lagi|kemudian|dari sekarang) ').firstMatch(t) ??
        RegExp(' dalam $_numRe ?(menit|mnt|jam) ').firstMatch(t);
    if (m != null) {
      final v = _wordNum(m.group(1)!);
      if (v != null) {
        rel = m.group(2) == 'jam' ? Duration(hours: v) : Duration(minutes: v);
        t = t.replaceFirst(m.group(0)!, ' ');
      }
    } else if ((m = RegExp(r' (?:dalam )?setengah jam (?:lagi )?').firstMatch(t)) != null) {
      rel = const Duration(minutes: 30);
      t = t.replaceFirst(m!.group(0)!, ' ');
    }

    // ---------- tanggal ----------
    final today = dateOnly(n);
    if ((m = RegExp(r' (\d+) hari lagi ').firstMatch(t)) != null) {
      date = addDays(today, int.parse(m!.group(1)!));
      explicitDate = true;
      t = t.replaceFirst(m.group(0)!, ' ');
    }
    if ((m = RegExp(r' (\d+) minggu lagi ').firstMatch(t)) != null) {
      date = addDays(today, 7 * int.parse(m!.group(1)!));
      explicitDate = true;
      t = t.replaceFirst(m.group(0)!, ' ');
    }
    if (RegExp(r' (akhir pekan|weekend|wiken) ').hasMatch(t)) {
      var d = today;
      while (jsDay(d) != 6) {
        d = addDays(d, 1);
      }
      date = d;
      explicitDate = true;
      cut(RegExp(r' (akhir pekan|weekend|wiken)( ini)?'));
    }
    if ((m = RegExp(r' (pagi|siang|sore|petang|malam) ini ').firstMatch(t)) != null) {
      date = today;
      explicitDate = true;
      period = m!.group(1);
      t = t.replaceFirst(m.group(0)!, ' ');
    }
    if (t.contains(' tengah malam ')) {
      hourOverride = 0;
      cut(RegExp(r' tengah malam'));
    }
    if (t.contains(' tengah hari ')) {
      hourOverride = 12;
      cut(RegExp(r' tengah hari'));
    }
    if (RegExp(r' lusa ').hasMatch(t)) {
      date = addDays(today, 2);
      explicitDate = true;
      cut(RegExp(r' (?:besok )?lusa'));
    } else if (RegExp(r' (besok|besuk|esok) ').hasMatch(t)) {
      date = addDays(today, 1);
      explicitDate = true;
      cut(RegExp(r' (?:hari )?(besok|besuk|esok)'));
    } else if (RegExp(r' (hari ini|nanti|sekarang) ').hasMatch(t)) {
      date = today;
      explicitDate = true;
      cut(RegExp(r' (hari ini|nanti|sekarang)'));
    }
    if (RegExp(r' (minggu|pekan) depan ').hasMatch(t)) {
      date = addDays(today, 7);
      explicitDate = true;
      cut(RegExp(r' (minggu|pekan) depan'));
    }
    if (RegExp(r' bulan depan ').hasMatch(t)) {
      date = DateTime(today.year, today.month + 1, today.day);
      explicitDate = true;
      cut(RegExp(r' bulan depan'));
    }
    final monthNames = _monthMap.keys.join('|');
    if ((m = RegExp(' (?:tanggal |tgl\\.? )?(\\d{1,2}) ($monthNames)(?: (\\d{4}))? ').firstMatch(t)) != null) {
      final y = m!.group(3) != null ? int.parse(m.group(3)!) : today.year;
      var d = DateTime(y, _monthMap[m.group(2)]!, int.parse(m.group(1)!));
      if (m.group(3) == null && d.isBefore(today)) d = DateTime(y + 1, d.month, d.day);
      date = d;
      explicitDate = true;
      t = t.replaceFirst(m.group(0)!, ' ');
    } else if ((m = RegExp(r' (\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))? ').firstMatch(t)) != null) {
      var y = m!.group(3) != null ? int.parse(m.group(3)!) : today.year;
      if (y < 100) y += 2000;
      var d = DateTime(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (m.group(3) == null && d.isBefore(today)) d = DateTime(y + 1, d.month, d.day);
      date = d;
      explicitDate = true;
      t = t.replaceFirst(m.group(0)!, ' ');
    } else if (repeat != RepeatType.monthly &&
        (m = RegExp(r' (?:tanggal|tgl\.?) (\d{1,2}) ').firstMatch(t)) != null) {
      final dd = int.parse(m!.group(1)!);
      var d = DateTime(today.year, today.month, dd);
      if (d.isBefore(today)) d = DateTime(today.year, today.month + 1, dd);
      date = d;
      explicitDate = true;
      t = t.replaceFirst(m.group(0)!, ' ');
    }
    if (weekday == null &&
        (m = RegExp(r" (?:hari )?(senin|selasa|rabu|kamis|jumat|jum'at|sabtu|minggu|ahad)( depan| ini)? ").firstMatch(t)) !=
            null) {
      weekday = _dayMap[m!.group(1)];
      t = t.replaceFirst(m.group(0)!, ' ');
      explicitDate = true;
      if (m.group(2) == ' depan') {
        var d = addDays(today, 1);
        while (jsDay(d) != weekday) {
          d = addDays(d, 1);
        }
        date = d;
      }
    }

    // ---------- jam ----------
    final kurang = RegExp(r' (?:jam |pukul )?(\d{1,2}) kurang (seperempat|\d{1,2}) ?(?:menit)? ').firstMatch(t);
    final lewatSeperempat = RegExp(r' (?:jam |pukul )(\d{1,2}) lewat seperempat ').firstMatch(t);
    if (kurang != null) {
      final k = kurang.group(2) == 'seperempat' ? 15 : int.parse(kurang.group(2)!);
      hour = (int.parse(kurang.group(1)!) - 1 + 24) % 24;
      minute = 60 - k;
      t = t.replaceFirst(kurang.group(0)!, ' ');
    } else if (lewatSeperempat != null) {
      hour = int.parse(lewatSeperempat.group(1)!);
      minute = 15;
      t = t.replaceFirst(lewatSeperempat.group(0)!, ' ');
    } else if ((m = RegExp(r' (?:jam|pukul|pkl\.?) setengah (\d{1,2}) ').firstMatch(t) ??
            RegExp(r' setengah (\d{1,2}) ').firstMatch(t)) !=
        null) {
      hour = (int.parse(m!.group(1)!) - 1 + 24) % 24;
      minute = 30;
      t = t.replaceFirst(m.group(0)!, ' ');
    } else if ((m = RegExp(r' (?:jam|pukul|pkl\.?) ?(\d{1,2})(?::(\d{2}))?(?: ?(?:lewat|lebih) (\d{1,2}) ?(?:menit)?)? ')
            .firstMatch(t)) !=
        null) {
      hour = int.parse(m!.group(1)!);
      minute = m.group(2) != null ? int.parse(m.group(2)!) : (m.group(3) != null ? int.parse(m.group(3)!) : 0);
      t = t.replaceFirst(m.group(0)!, ' ');
    } else if ((m = RegExp(r' (\d{1,2}):(\d{2}) ').firstMatch(t)) != null) {
      hour = int.parse(m!.group(1)!);
      minute = int.parse(m.group(2)!);
      t = t.replaceFirst(m.group(0)!, ' ');
    } else if ((m = RegExp(r' (\d{1,2}) (pagi|siang|sore|malam|subuh|petang) ').firstMatch(t)) != null) {
      hour = int.parse(m!.group(1)!);
      period = m.group(2);
      t = t.replaceFirst(m.group(0)!, ' ');
    }
    if ((m = RegExp(r' (pagi|siang|sore|petang|malam|subuh|dini hari) ').firstMatch(t)) != null) {
      period ??= m!.group(1);
      cut(RegExp(r' (pagi|siang|sore|petang|malam|subuh|dini hari)'));
    }
    if (hour == null && hourOverride != null) {
      hour = hourOverride;
      minute = 0;
      period = null;
    }
    if (hour != null && hourOverride == null) {
      if (period == 'siang' && hour >= 1 && hour <= 5) {
        hour += 12;
      } else if ((period == 'sore' || period == 'petang') && hour < 12) {
        hour += 12;
      } else if (period == 'malam') {
        if (hour == 12) {
          hour = 0;
        } else if (hour >= 6 && hour < 12) {
          hour += 12;
        }
      } else if (period == 'pagi' && hour == 12) {
        hour = 0;
      } else if (period == null && hour >= 1 && hour <= 4) {
        hour += 12; // "jam 3" biasanya sore
      }
      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);
    } else if (hour == null && period != null) {
      hour = const {'pagi': 7, 'siang': 12, 'sore': 16, 'petang': 17, 'malam': 19, 'subuh': 5, 'dini hari': 3}[period];
    }

    final hasTime = hour != null || rel != null;

    // ---------- susun waktu ----------
    DateTime at;
    if (rel != null) {
      final x = n.add(rel);
      at = DateTime(x.year, x.month, x.day, x.hour, x.minute);
    } else {
      final h = hour ?? 9;
      final mi = hour != null ? minute : 0;
      var base = date ?? today;
      if (weekday != null && date == null) {
        for (var i = 0; i < 8; i++) {
          final d = addDays(today, i);
          if (jsDay(d) == weekday && DateTime(d.year, d.month, d.day, h, mi).isAfter(n)) {
            base = d;
            break;
          }
        }
      }
      if (repeat == RepeatType.monthly && monthDay != null) {
        base = DateTime(today.year, today.month, monthDay);
        if (!DateTime(base.year, base.month, base.day, h, mi).isAfter(n)) {
          base = DateTime(today.year, today.month + 1, monthDay);
        }
      }
      at = DateTime(base.year, base.month, base.day, h, mi);
      // waktu sudah lewat & tanggal tidak disebut → geser ke kesempatan berikutnya
      if (!at.isAfter(n) && (!explicitDate || repeat != RepeatType.once)) {
        if (repeat == RepeatType.weekly) {
          at = addDays(at, 7);
        } else if (repeat == RepeatType.monthly) {
          at = DateTime(at.year, at.month + 1, at.day, h, mi);
        } else {
          at = addDays(at, 1);
        }
      }
    }

    // ---------- judul ----------
    var words = t
        .replaceAll(RegExp(r'\b(ingatkan|ingat|inget|jadwalkan|catat|alarm|setel|pasang|set|bikin|buat|tambah|masukkan|masukin) (pengingat|jadwal|agenda|alarm|reminder|acara)\b'), ' ')
        .replaceAll(RegExp(r'^ ?(jadwal|agenda|acara|kegiatan|rencana) '), ' ')
        .replaceAll(RegExp(r'\bbangunkan\b'), 'bangun')
        .replaceAll(RegExp(r'\bdi hari\b'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .toList();
    for (var i = 0; i < 3 && words.isNotEmpty && _leadingWords.contains(words.first); i++) {
      words.removeAt(0);
    }
    while (words.isNotEmpty && const {'ya', 'dong', 'deh'}.contains(words.last)) {
      words.removeLast();
    }
    while (words.isNotEmpty && const {'ini', 'nanti', 'alarm', 'jadwal', 'agenda'}.contains(words.last)) {
      words.removeLast();
    }
    while (words.isNotEmpty && const {'ini', 'nanti', 'jadwal', 'agenda', 'acara'}.contains(words.first)) {
      words.removeAt(0);
    }
    var title = words.join(' ').trim();
    if (title.isEmpty) title = input.contains('bangun') ? 'Bangun' : 'Pengingat';
    title = title[0].toUpperCase() + title.substring(1);
    // kode lantai/blok: b2 → B2, p3a → P3A
    title = title.replaceAllMapped(RegExp(r'\b([a-z]{1,2}\d{1,3}[a-z]?)\b'), (m) => m[1]!.toUpperCase());

    final category = guessCategory(input) ?? ReminderCategory.lainnya;
    var alarm = true;
    if (category == ReminderCategory.parkir && !hasTime && !explicitDate) {
      // catatan parkir tanpa jam: disimpan sekarang, tanpa bunyi alarm
      at = DateTime(n.year, n.month, n.day, n.hour, n.minute);
      alarm = false;
    }

    return ParsedReminder(
      title: title,
      scheduledAt: at,
      repeat: repeat,
      category: category,
      alarm: alarm,
    );
  }
}
