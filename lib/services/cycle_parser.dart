/// Mengenali obrolan seputar haid, termasuk bahasa gaul & salah ketik.
/// Contoh: "haid aku mulai hari ini", "lagi dapet nih", "udah bersih kemarin",
/// "kapan haid saya selesai?", "kapan mens lagi?", "aku telat haid ga?",
/// "masa subur kapan", "ingetin aku kalau mau haid".
enum CycleCmd { start, end, askNext, askEnd, askDay, askFertile, askLate, remindOn, remindOff }

class CycleIntent {
  const CycleIntent(this.cmd, [this.daysAgo = 0]);
  final CycleCmd cmd;
  final int daysAgo;
  @override
  String toString() => 'CycleIntent($cmd, $daysAgo)';
}

class CycleParser {
  /// Kata (tanpa akhiran -nya/-ku/-mu) yang berarti haid.
  static const _haidWords = {
    'haid', 'haidh', 'hait', 'haed', 'haidd', 'hayd', 'haaid', 'menstruasi', 'mensturasi', 'menstrusi', 'mentruasi',
    'menstruas', 'menstruation', 'menstruasii', 'mens', 'menses', 'mensnya', 'mentsruasi', 'halangan', 'berhalangan',
  };

  static const _numWords = {
    'satu': 1, 'se': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10,
  };

  /// Menyeragamkan teks: sinonim haid → "haid", angka kata → digit.
  static String normalize(String input) {
    var t = ' ${input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9?\- ]'), ' ').replaceAll('-', ' ').replaceAll('?', ' ? ')} '.replaceAll(RegExp(r'\s+'), ' ');
    const phrases = {
      'kedatangan tamu bulanan': 'haid datang', 'datang bulan': 'haid datang', 'dtg bulan': 'haid', 'dateng bulan': 'haid', 'tamu bulanan': 'haid', 'kedatangan tamu': 'haid datang',
      'dapet tamu': 'haid datang', 'dapat tamu': 'haid datang', 'lagi merah': 'lagi haid', 'red day': 'haid', 'my period': 'haid',
      'tadi malam': 'hari ini', 'tadi pagi': 'hari ini', 'tadi siang': 'hari ini', 'barusan': 'hari ini', 'td pagi': 'hari ini',
      'kemarin lusa': '2 hari lalu', 'lusa kemarin': '2 hari lalu', 'kemarin dulu': '2 hari lalu', 'seminggu': '7 hari', 'sepekan': '7 hari',
    };
    t = t.split(' ').map((w) {
      if (w.isEmpty) return w;
      final base = w.replaceFirst(RegExp(r'(nya|ku|mu|an)$'), '');
      if (_haidWords.contains(w) || _haidWords.contains(base)) return 'haid';
      if (w == 'period' || w == 'periodku') return 'haid';
      if (_numWords.containsKey(w)) return '${_numWords[w]}';
      if (const {'kemaren', 'kmrn', 'kmarin', 'kemrin', 'kmren', 'semalam', 'kemarin'}.contains(w)) return 'kemarin';
      if (const {'kpn', 'kapn', 'kpan'}.contains(w)) return 'kapan';
      if (const {'brp', 'brapa', 'berpa'}.contains(w)) return 'berapa';
      if (const {'udh', 'udah', 'dah', 'sdh', 'sudah', 'uda'}.contains(w)) return 'sudah';
      if (const {'blm', 'belom', 'belum', 'blom'}.contains(w)) return 'belum';
      if (const {'gak', 'ga', 'nggak', 'ngga', 'enggak', 'engga', 'tdk', 'tidak', 'gk', 'g'}.contains(w)) return 'tidak';
      if (const {'ingetin', 'ingatin', 'ingatkan', 'ingetkan', 'ingtkan', 'ingatkn'}.contains(w)) return 'ingatkan';
      if (const {'lg', 'lgi'}.contains(w)) return 'lagi';
      return w;
    }).join(' ');
    phrases.forEach((k, v) => t = t.replaceAll(' $k ', ' $v '));
    // "lagi dapet (nih)" = sedang haid
    t = t.replaceAllMapped(RegExp(r' (lagi|sedang|baru) (dapet|dapat|dpt)( nih| ni| ya| hari ini| kemarin| \d| ?$| )'), (m) => ' ${m[1]} haid${m[3] ?? ''}');
    return t.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _has(String t, String pattern) => RegExp(pattern).hasMatch(t);

  /// [ongoing]: haid sedang berlangsung — "udah bersih" saja sudah cukup jelas.
  static CycleIntent? parse(String input, {bool ongoing = false}) {
    final t = normalize(input);
    final topic = _has(t, r' haid ') || _has(t, r'masa subur|ovulasi') || (_has(t, r' subur ') && _has(t, r' (kapan|aku|saya|ku|gue|gw) '));
    if (!topic && ongoing && _has(t, r'^ (aku |saya |alhamdulillah )?(sudah )?(bersih|bersih total)( hari ini| kemarin| \d+ hari lalu)?( ya| nih| kok)? $')) {
      return CycleIntent(CycleCmd.end, _daysAgo(t, start: false));
    }
    if (!topic) return null;

    final q = t.contains('?') ||
        _has(t, r' (kapan|berapa|perkiraan|prediksi|perkiraannya|kira|kira kira|apakah|gimana|bagaimana|tanggal berapa|jadwal|kapankah) ') ||
        _has(t, r'^ (apa|masih) ');
    final cond = _has(t, r' (kalau|kalo|klo|jika|nanti|saat|ketika|pas|sebelum|menjelang|mau) ');
    final remind = _has(t, r' (ingatkan|pengingat|notif|notifikasi|kabari|kasih tau|kasih tahu|kasi tau|alarm) ');
    final remindOff = _has(t, r' (jangan|tidak usah|tak usah|matikan|stop|hentikan|nonaktifkan) (lagi )?(ingatkan|pengingat|notif|notifikasi|kabari|alarm)');
    final fertile = _has(t, r'subur|ovulasi');
    final late = _has(t, r' (telat|terlambat|ketinggalan|mundur) ') || _has(t, r' (belum|tidak) (haid|datang|dateng|dapet|dapat|keluar)') || _has(t, r' haid (belum|tidak (datang|dateng|keluar|muncul|dapet))');
    final end = _has(t, r' (selesai|slesai|seles|selsai|udahan|sudahan|berhenti|brenti|beres|kelar|habis|abis|bersih|tuntas|berakhir|hari terakhir|stop) ') ||
        (_has(t, r' (sudah|tidak) (keluar )?lagi ') && !_has(t, r' haid lagi '));
    final start = _has(t, r' (mulai|datang|dateng|dtg|dapet|dapat|dpt|keluar|kluar|hari pertama|kena|kedatangan|muncul|nongol|baru haid|lagi haid|sedang haid|lagi menstruasi) ') ||
        _has(t, r' hari ke ?\d') ||
        _has(t, r' sudah \d+ hari ');
    final dayQ = _has(t, r' (hari ke ?berapa|hari keberapa|sudah berapa hari|berapa hari|berapa lama|sudah hari|masih) ');

    if (remindOff) return const CycleIntent(CycleCmd.remindOff);
    if (q) {
      if (remind) return const CycleIntent(CycleCmd.remindOn);
      if (fertile) return const CycleIntent(CycleCmd.askFertile);
      if (late) return const CycleIntent(CycleCmd.askLate);
      if (end) return const CycleIntent(CycleCmd.askEnd);
      if (dayQ) return const CycleIntent(CycleCmd.askDay);
      return const CycleIntent(CycleCmd.askNext);
    }
    if (remind && (cond || !(start || end))) return const CycleIntent(CycleCmd.remindOn);
    if (cond && !remind && (start || end)) {
      // "nanti kalau haid selesai…" tanpa pernyataan → jawab perkiraan
      return CycleIntent(end ? CycleCmd.askEnd : CycleCmd.askNext);
    }
    if (end) return CycleIntent(CycleCmd.end, _daysAgo(t, start: false));
    if (late) return const CycleIntent(CycleCmd.askLate);
    if (start) return CycleIntent(CycleCmd.start, _daysAgo(t, start: true));
    if (fertile) return const CycleIntent(CycleCmd.askFertile);
    return const CycleIntent(CycleCmd.askNext);
  }

  static int _daysAgo(String t, {required bool start}) {
    if (start) {
      final k = RegExp(r' hari ke ?(\d{1,2})').firstMatch(t);
      if (k != null) return (int.parse(k[1]!) - 1).clamp(0, 15).toInt();
      final u = RegExp(r' sudah (\d{1,2}) hari ').firstMatch(t);
      if (u != null && !t.contains(' lalu')) return (int.parse(u[1]!) - 1).clamp(0, 15).toInt();
    }
    final n = RegExp(r' (\d{1,2}) hari (yang |yg )?(lalu|lalu|sebelumnya|kebelakang|kemarin)').firstMatch(t);
    if (n != null) return int.parse(n[1]!).clamp(0, 45).toInt();
    final tg = RegExp(r' (tanggal|tgl|tg) (\d{1,2})\b').firstMatch(t);
    if (tg != null) {
      final now = DateTime.now();
      final d = int.parse(tg[2]!);
      var date = DateTime(now.year, now.month, d);
      if (date.isAfter(now)) date = DateTime(now.year, now.month - 1, d);
      return DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(date.year, date.month, date.day)).inDays.clamp(0, 45).toInt();
    }
    if (t.contains(' kemarin ')) return 1;
    return 0;
  }
}
