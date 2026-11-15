import '../data/models/reminder.dart';

/// Hasil pemahaman kalimat "saya simpan X di Y".
class StoredItem {
  const StoredItem(this.item, this.place);
  final String item; // mis. "kunci motor"
  final String place; // mis. "di laci meja"
}

/// Memahami kalimat penyimpanan barang & pertanyaan "di mana …?" (tanpa internet).
class MemoryParser {
  MemoryParser._();

  static const _verb =
      r'(?:simpan|simpen|nyimpen|nyimpan|menyimpan|taruh|taro|tarok|naruh|naro|menaruh|letakkan|letakin|letakan|meletakkan|tinggalin|ninggalin|titip|titipin|titipkan|masukin|masukkan|gantung|gantungin|selipin|selipkan)';
  static const _prep =
      r'(di dalam|di atas|di bawah|di belakang|di samping|di sebelah|di depan|ke dalam|di|ke|dalam)';

  static String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _cleanItem(String s) => s
      .replaceAll(RegExp(r'^(barang |si |sebuah |satu |punya(ku)? )+'), '')
      .replaceAll(RegExp(r'( (saya|aku|ku|gue|gw|punyaku|punya saya|ya|nya))+$'), '')
      .replaceAll(RegExp(r'^(saya|aku|gue|gw) '), '')
      .trim();

  static String _cleanPlace(String prep, String place) {
    final p = place
        .replaceAll(
            RegExp(r'( (ya|yaa|dong|deh|nih|tolong ingat(kan)?( saya| aku)?|ingat(kan)?( saya| aku)?( ya)?|biar (ga|gak|nggak|tidak) lupa|supaya (ga|gak|nggak|tidak) lupa))+$'),
            '')
        .trim();
    final pre = prep == 'ke' ? 'di' : (prep == 'ke dalam' || prep == 'dalam') ? 'di dalam' : prep;
    return '$pre $p'.trim();
  }

  /// "saya simpan kunci motor di laci meja" → StoredItem('kunci motor', 'di laci meja').
  static StoredItem? parseStore(String text) {
    var t = ' ${text.toLowerCase().replaceAll(RegExp(r'[!?.,;:"]+'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';
    if (RegExp(r' (jam|pukul|besok|lusa|menit lagi|jam lagi|setiap|tiap|nanti sore|nanti malam) ').hasMatch(t)) return null;
    t = t
        .replaceAll(RegExp(r' (tolong|tlg|catat|ingat|inget|ingatkan|ingetin|ok|oke|ya|eh|nih|bahwa|kalau|kalo)(?= )'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    t = ' ${t.trim()} ';
    var m = RegExp(' (?:aku |saya |gue |gw |ku )?(?:sudah |udah |barusan |tadi |baru |lagi )?$_verb (.+?) $_prep (.+?) \$').firstMatch(t);
    m ??= RegExp(' (.+?) (?:aku |saya |gue |gw |ku )?(?:sudah |udah |tadi |barusan )?(?:di)?$_verb(?:in|kan)? $_prep (.+?) \$').firstMatch(t);
    if (m != null) {
      final item = _cleanItem(m.group(1)!), place = _cleanPlace(m.group(2)!, m.group(3)!);
      if (item.isNotEmpty && place.length > 3) return StoredItem(item, place);
    }
    final a = RegExp(r' (.+?) (?:sekarang |lagi )?ada (di dalam|di atas|di bawah|di) (.+?) $').firstMatch(t);
    if (a != null && !RegExp(r' (rapat|meeting|acara) ').hasMatch(t)) {
      final item = _cleanItem(a.group(1)!), place = _cleanPlace(a.group(2)!, a.group(3)!);
      if (item.isNotEmpty) return StoredItem(item, place);
    }
    return null;
  }

  /// Apakah kalimat ini menanyakan letak sesuatu?
  static bool isWhereQuestion(String lower) =>
      RegExp(r'\b(di ?mana|dimana|ada di mana|taruh di ?mana|taro di ?mana|simpan di ?mana|letak(nya)?)\b').hasMatch(lower) ||
      RegExp(r'\bmana\b.*\?$').hasMatch(lower);

  static const _stop = {
    'di', 'mana', 'dimana', 'ada', 'saya', 'aku', 'ku', 'gue', 'gw', 'yang', 'tadi', 'kemarin', 'kemaren', 'barusan', 'taruh',
    'taro', 'simpan', 'nyimpen', 'naruh', 'letak', 'letaknya', 'ya', 'sih', 'dong', 'deh', 'kok', 'nya', 'aja', 'itu', 'ini',
    'lagi', 'sekarang', 'udah', 'sudah', 'tolong', 'cari', 'lupa', 'inget', 'ingat', 'barang', 'punyaku', 'punya', 'apa',
    'gimana', 'kemana', 'ke',
  };

  static List<String> _keywords(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'(nya|ku|mu)$'), ''))
      .where((w) => w.length > 1 && !_stop.contains(w))
      .toList();

  /// Catatan barang yang cocok dengan pertanyaan, paling cocok & terbaru dulu.
  static List<Reminder> findItems(List<Reminder> all, String question) {
    final kws = _keywords(question);
    if (kws.isEmpty) return [];
    final scored = <(Reminder, int)>[];
    for (final r in all) {
      if (r.item == null || r.done) continue;
      final iw = _keywords(r.item!);
      final score = kws.where((k) => iw.any((w) => w == k || (k.length > 3 && (w.startsWith(k) || k.startsWith(w))))).length;
      if (score > 0) scored.add((r, score));
    }
    scored.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$1.createdAt.compareTo(a.$1.createdAt));
    return scored.map((e) => e.$1).toList();
  }
}
