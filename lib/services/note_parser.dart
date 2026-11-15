/// Catatan bebas lewat chat — sinkron dengan versi website (index.html).
/// Contoh simpan : "tolong catat saya punya emas 10 gr", "catet ya: utang budi 50rb",
///                 "password fb saya Abc#123" (rahasia, dikunci sidik jari/PIN).
/// Contoh tanya  : "berapa emas saya?", "apa password fb saya", "aku lupa pin atm".
class NoteDraft {
  const NoteDraft({required this.text, required this.label, required this.value, required this.secret});
  final String text;
  final String label;
  final String value;
  final bool secret;
}

enum NoteQueryKind { find, list, delete }

class NoteQuery {
  const NoteQuery(this.kind, this.tokens, {this.personal = true});
  final NoteQueryKind kind;
  final List<String> tokens;
  final bool personal;
}

/// Data minimal yang dibutuhkan pencocokan.
abstract class NoteLike {
  String get label;
  String get value;
  bool get secret;
  DateTime get createdAt;
}

class NoteParser {
  static const Map<String, List<String>> _syn = {
    'password': ['password', 'pasword', 'passwrd', 'paswd', 'passwd', 'paswod', 'pass', 'pw', 'pwd', 'sandi', 'katasandi', 'paswordnya', 'passwordnya', 'sandinya'],
    'pin': ['pin', 'pinnya'],
    'facebook': ['fb', 'facebook', 'fesbuk', 'facebok', 'fbnya'],
    'instagram': ['ig', 'insta', 'instagram', 'instgram', 'ignya'],
    'whatsapp': ['wa', 'whatsapp', 'watsap', 'whatsap', 'wanya'],
    'email': ['email', 'gmail', 'imel', 'surel', 'emailnya', 'gmailnya', 'mail'],
    'tiktok': ['tiktok', 'tt'],
    'youtube': ['youtube', 'yt'],
    'tokopedia': ['tokopedia', 'tokped'],
    'shopee': ['shopee', 'shopeenya', 'sopi'],
    'twitter': ['twitter'],
    'rekening': ['rekening', 'rek', 'norek', 'rekeningnya'],
    'wifi': ['wifi', 'wifinya', 'wf'],
    'gram': ['gr', 'gram', 'g', 'grm'],
    'emas': ['emas', 'gold', 'emasnya', 'logam'],
    'uang': ['uang', 'duit', 'duitnya', 'uangnya'],
    'utang': ['utang', 'hutang', 'utangnya', 'hutangnya'],
    'nomor': ['no', 'nomor', 'nmr', 'nomer', 'nomornya'],
    'hp': ['hp', 'handphone', 'telepon', 'telp', 'tlp', 'hape'],
    'plat': ['plat', 'nopol', 'platnya'],
    'ukuran': ['ukuran', 'size', 'ukurannya'],
    'alamat': ['alamat', 'alamatnya'],
  };
  static final Map<String, String> _synMap = {
    for (final e in _syn.entries)
      for (final w in e.value) w: e.key,
  };
  static final Set<String> _stop = ('saya aku ku gue gw gua punya punyaku milik milikku apa apakah berapa ya dong deh sih nih tolong tlg minta coba catat catet cttn ctt catatin catetin catatkan dicatat '
          'tulis tulisin tuliskan note noted save simpan simpen ingat inget yang yg di ke dari dan itu ini adalah yaitu ialah nya mu kamu ada lihat liat tampilkan tunjukkan tunjukin kasih '
          'tau tahu cek buka sekarang berapakah mana dimana gimana bagaimana lagi udah sudah udh semua catatan catatanku info data kan aja saja tadi kemarin lupa jadi sebutkan cari '
          'siapa kapan sama the my is a ok oke makasih thanks dulu sebanyak sejumlah total jumlah segini seberapa tak tidak gak ga apaan aj')
      .split(' ')
      .toSet();
  static const _generic = {'password', 'pin', 'nomor', 'gram', 'kode', 'akun'};
  static bool isGeneric(String t) => _generic.contains(t);

  static final secretRe = RegExp(r'\b(password|pasword|passwrd|paswd|passwd|pass|pw|pwd|sandi|kata sandi|kata kunci|pin|passcode|kode rahasia|kode akses|pola kunci|cvv)\w*\b', caseSensitive: false);
  static final _trigger = RegExp(
      r'^\s*(?:(?:tolong|tlg|minta|coba|bisa)\s+)?(?:(?:kamu|km)\s+)?(?:catat|catet|cttn|ctt|catatin|catetin|catatkan|dicatat|tulis|tulisin|tuliskan|note|noted|save|simpan catatan|simpen catatan|buat catatan|bikin catatan|tambah catatan|tambahkan catatan|masukkan catatan|catatan baru|ingat|inget|simpan|simpen|simpankan|rekam)\b\s*(?:(?:ya|yah|dong|deh|nih|ini|baik baik|baik2)\b\s*)*(?:(?:bahwa|kalau|kalo|klo|kl)\b\s*)?[:\-–]?\s*',
      caseSensitive: false);
  static final _q = RegExp(
      r'\?|\b(apa|apakah|apaan|berapa|brp|berapakah|siapa|kapan|mana|dimana|gimana|lihat|liat|tampilkan|tunjukkan|tunjukin|kasih tau|kasih tahu|kasi tau|cek|buka|cari|sebutkan|lupa|inget gak|ingat gak|ingat tidak|inget ga)\b',
      caseSensitive: false);

  static List<String> tokens(String text) {
    final t = text
        .toLowerCase()
        .replaceAll(RegExp(r'kata sandi|kata kunci'), ' password ')
        .replaceAll('plat nomor', ' plat ')
        .replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final out = <String>[];
    for (var w in t.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      w = _synMap[w] ?? w;
      if (_stop.contains(w)) continue;
      if (!_syn.containsKey(w) && w.length > 4 && w.endsWith('nya')) w = w.substring(0, w.length - 3);
      if (!out.contains(w)) out.add(w);
    }
    return out;
  }

  static String _clean(String s) => s
      .replaceFirst(RegExp(r'^(?:(?:ya|dong|deh|nih|bahwa|kalau|kalo|ini)\b\s*)+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*(?:\b(?:ya|yah|dong|deh|ok|oke|makasih|thanks|thx|tq)\b\s*|[.!,]\s*)+$', caseSensitive: false), '')
      .trim();

  static NoteDraft? parseStore(String input) {
    final raw = input.trim();
    final m = _trigger.firstMatch(raw);
    String content;
    if (m != null) {
      content = _clean(raw.substring(m.end));
      final verb = m[0]!.trim().replaceFirst(RegExp(r'^(tolong|tlg|minta|coba|bisa)\s+', caseSensitive: false), '');
      if (RegExp(r'^(simpan|simpen|simpankan|ingat|inget)', caseSensitive: false).hasMatch(verb) &&
          !secretRe.hasMatch(content) &&
          !RegExp(r'\d').hasMatch(content) &&
          !RegExp(r'\b(punya|nomor|no|alamat|ukuran|nama|utang|hutang|tanggal|ultah|ulang tahun)\b', caseSensitive: false).hasMatch(content)) {
        return null;
      }
    } else {
      if (!secretRe.hasMatch(raw) ||
          RegExp(r'\?|\b(apa|berapa|brp|lupa|mana|lihat|liat|tampilkan|kasih tau|kasih tahu|ganti|cara|gimana|bagaimana|lupa)\b', caseSensitive: false).hasMatch(raw)) {
        return null;
      }
      final words = raw.split(RegExp(r'\s+'));
      if (words.length < 2 ||
          !RegExp(r'^(password|pasword|passwrd|paswd|passwd|pass|pw|pwd|sandi|kata sandi|pin|kode)', caseSensitive: false)
              .hasMatch(raw.replaceFirst(RegExp(r'^(saya|aku|gue|gw)\s+', caseSensitive: false), ''))) {
        return null;
      }
      content = _clean(raw);
    }
    if (content.replaceAll(RegExp(r'\W'), '').length < 2) return null;
    final secret0 = secretRe.hasMatch(content);
    if (!secret0 &&
        RegExp(r'\b(jam \d|pukul|besok|lusa|nanti (pagi|siang|sore|malam)|\d+ (menit|jam) lagi|setiap|tiap (hari|minggu|bulan|senin|selasa|rabu|kamis|jumat|sabtu|minggu))\b', caseSensitive: false)
            .hasMatch(content) &&
        !RegExp(r'\b(punya|nomor|alamat|ukuran)\b', caseSensitive: false).hasMatch(content)) {
      return null;
    }
    if (!secret0) return NoteDraft(text: content, label: content, value: content, secret: false);
    String label, value;
    final ms = RegExp(r'^(.*?)\s*(?:[:=]|\s(?:adalah|yaitu|ialah|itu|nya|sama dengan|=)\s)\s*(.+)$', caseSensitive: false).firstMatch(content);
    if (ms != null && ms[1]!.trim().isNotEmpty && ms[2]!.trim().isNotEmpty) {
      label = ms[1]!.trim();
      value = ms[2]!.trim();
    } else {
      final i = content.lastIndexOf(' ');
      if (i < 0) return null;
      label = content.substring(0, i).trim();
      value = content.substring(i + 1).trim();
    }
    value = value.replaceAll(RegExp(r'^["'“]|["'”]$'), '');
    if (value.isEmpty || tokens(label).isEmpty) return null;
    return NoteDraft(text: content, label: label, value: value, secret: true);
  }

  static NoteQuery? parseQuery(String input) {
    final t = input.toLowerCase().trim();
    final del = RegExp(r'^(?:tolong\s+)?(?:hapus|buang|lupakan|delete|hilangkan)\s+(?:catatan\s+)?(?:tentang\s+|soal\s+)?(.+)$').firstMatch(t);
    if (del != null && (RegExp(r'catatan|lupakan').hasMatch(t) || secretRe.hasMatch(t))) {
      return NoteQuery(NoteQueryKind.delete, tokens(del[1]!));
    }
    if (RegExp(r'\b(semua|daftar|list|lihat|liat|tampilkan|buka|cek)\s+(?:semua\s+)?catatan').hasMatch(t) ||
        RegExp(r'^catatan\s*(saya|aku|ku)?\s*(apa\s*(aja|saja)?)?\s*\??$').hasMatch(t) ||
        RegExp(r'catatan\s*(saya|aku|ku)\s*(apa|ada apa)').hasMatch(t)) {
      return const NoteQuery(NoteQueryKind.list, []);
    }
    if (!_q.hasMatch(t)) return null;
    final tk = tokens(t);
    final personal = RegExp(r'\b(saya|aku|gue|gw|gua|ku|punyaku|milikku)\b|ku\b').hasMatch(t) || secretRe.hasMatch(t);
    return tk.isEmpty ? null : NoteQuery(NoteQueryKind.find, tk, personal: personal);
  }

  static List<String> _specific(List<String> tk) => tk.where((x) => !_generic.contains(x) && !RegExp(r'^\d+$').hasMatch(x)).toList();

  static List<String> _noteTokens(NoteLike n) => tokens(n.label + (n.secret ? '' : ' ${n.value}'));

  /// Catatan yang cocok, paling relevan & terbaru dulu.
  static List<T> match<T extends NoteLike>(List<T> notes, List<String> tk, {bool personal = true}) {
    final specific = _specific(tk);
    final need = personal ? (specific.length / 2).ceil() : specific.length;
    final scored = <(T, double)>[];
    for (final n in notes) {
      final nt = _noteTokens(n);
      final hit = tk.where(nt.contains).toList();
      if (hit.isEmpty) continue;
      if (specific.isNotEmpty && specific.where(nt.contains).length < need) continue;
      if (specific.isEmpty && !hit.any(_generic.contains)) continue;
      scored.add((n, hit.length / tk.length));
    }
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : b.$1.createdAt.compareTo(a.$1.createdAt);
    });
    return scored.map((e) => e.$1).toList();
  }

  /// Semua kata khusus di pertanyaan ada di catatan? (kalau tidak, biar AI yang menjawab)
  static bool fullMatch(NoteLike n, List<String> tk) {
    final nt = _noteTokens(n);
    return _specific(tk).every(nt.contains);
  }

  /// "saya punya emas 10 gr" → "kamu punya emas 10 gr"
  static String you(String s) => s
      .replaceFirst(RegExp(r'^(saya|aku|gue|gw|gua)\b', caseSensitive: false), 'kamu')
      .replaceAll(RegExp(r'\b(saya|aku|gue|gw|gua)\b', caseSensitive: false), 'kamu');
}
