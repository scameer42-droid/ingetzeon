import 'dart:math';

import '../core/utils/date_utils.dart';

/// Kosakata asisten tanpa internet: salah ketik, singkatan, angka kata,
/// penebak maksud kalimat, dan obrolan ringan.
class Vocab {
  Vocab._();

  static const Map<String, String> typo = {
    // perintah mengingatkan (termasuk salah ketik)
    'ingkatkan': 'ingatkan', 'ingtkan': 'ingatkan', 'igatkan': 'ingatkan', 'ingatkn': 'ingatkan', 'ingatkann': 'ingatkan',
    'ingatakan': 'ingatkan', 'inagtkan': 'ingatkan', 'ingetkn': 'ingatkan', 'ingetkan': 'ingatkan', 'ingetin': 'ingatkan',
    'ingatin': 'ingatkan', 'ngingetin': 'ingatkan', 'ngingatin': 'ingatkan', 'ingetinn': 'ingatkan', 'ingtin': 'ingatkan',
    'igetin': 'ingatkan', 'ingetn': 'ingatkan', 'remindin': 'ingatkan', 'remind': 'ingatkan', 'reminder': 'ingatkan',
    'remainder': 'ingatkan', 'jadwalin': 'jadwalkan', 'jadwalkn': 'jadwalkan', 'jdwlkan': 'jadwalkan', 'jdwl': 'jadwal',
    'jadwl': 'jadwal', 'jdwal': 'jadwal', 'jawdal': 'jadwal', 'bangunin': 'bangunkan', 'bangunkn': 'bangunkan',
    'alarem': 'alarm', 'alaram': 'alarm', 'alrm': 'alarm', 'catet': 'catat', 'catetin': 'catat', 'catatin': 'catat',
    'tambahin': 'tambah', 'bikinin': 'buat', 'buatin': 'buat', 'bkin': 'bikin',
    // waktu
    'jm': 'jam', 'jem': 'jam', 'pkl': 'pukul', 'mnt': 'menit', 'menitt': 'menit', 'dtk': 'detik',
    'bsk': 'besok', 'besuk': 'besok', 'bsok': 'besok', 'besoq': 'besok', 'bsuk': 'besok', 'esok': 'besok', 'lsa': 'lusa',
    'skrg': 'sekarang', 'skrng': 'sekarang', 'skg': 'sekarang', 'ntar': 'nanti', 'entar': 'nanti', 'nnti': 'nanti',
    'nti': 'nanti', 'ntr': 'nanti', 'hr': 'hari', 'hri': 'hari', 'pgi': 'pagi', 'pagii': 'pagi', 'siank': 'siang',
    'soree': 'sore', 'malem': 'malam', 'mlem': 'malam', 'mlm': 'malam', 'mlam': 'malam', 'sre': 'sore', 'tgl': 'tanggal',
    'tggl': 'tanggal', 'bln': 'bulan', 'mgg': 'minggu', 'mggu': 'minggu', 'dpn': 'depan', 'dpan': 'depan', 'lg': 'lagi',
    'lgi': 'lagi', 'stiap': 'setiap', 'tiap2': 'tiap', 'sen': 'senin', 'sel': 'selasa', 'rab': 'rabu', 'kam': 'kamis',
    'jum': 'jumat', "jum'at": 'jumat', 'sab': 'sabtu',
    // kata umum
    'tlg': 'tolong', 'tolongin': 'tolong', 'yg': 'yang', 'utk': 'untuk', 'untk': 'untuk', 'dgn': 'dengan', 'sy': 'saya',
    'aq': 'aku', 'ak': 'aku', 'gw': 'gue', 'gua': 'gue', 'km': 'kamu', 'kmu': 'kamu', 'gak': 'tidak', 'ga': 'tidak',
    'nggak': 'tidak', 'engga': 'tidak', 'enggak': 'tidak', 'gk': 'tidak', 'tdk': 'tidak', 'blm': 'belum', 'udh': 'sudah',
    'udah': 'sudah', 'sdh': 'sudah', 'dmn': 'di mana', 'dimn': 'di mana', 'knp': 'kenapa', 'gmn': 'gimana',
    'bgmn': 'bagaimana', 'brp': 'berapa', 'mksh': 'makasih', 'makasi': 'makasih', 'trims': 'makasih', 'thx': 'makasih',
    'thanks': 'makasih', 'tq': 'makasih', 'shopefood': 'shopeefood', 'shoppefood': 'shopeefood', 'shoppe': 'shopee',
    'sopi': 'shopee', 'gofud': 'gofood', 'grabfud': 'grabfood',
  };

  static const _numHour = {
    'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9,
    'sepuluh': 10, 'sebelas': 11, 'dua belas': 12,
  };

  static int _lev(String a, String b) {
    if ((a.length - b.length).abs() > 3) return 9;
    final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)].reduce(min);
      }
    }
    return d[a.length][b.length];
  }

  /// Rapikan kalimat: huruf kecil, salah ketik, singkatan, "jam tujuh" → "jam 7", "jam 7an" → "jam 7".
  static String normalize(String text) {
    var t = ' ${text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
    t = t.replaceAllMapped(RegExp(r'(\d)\s*an\b'), (m) => m[1]!);
    t = t.replaceAllMapped(RegExp(r'\b(\d{1,2})\s*(am|pm)\b'), (m) {
      final h = int.parse(m[1]!);
      return ' jam ${m[2] == 'pm' && h < 12 ? h + 12 : h} ';
    });
    t = t
        .replaceAll(RegExp(r'\bsejam\b'), '1 jam')
        .replaceAll(RegExp(r'\bsemenit\b'), '1 menit')
        .replaceAll(RegExp(r'\bsehari lagi\b'), 'besok')
        .replaceAll(RegExp(r'\bseminggu lagi\b'), '7 hari lagi')
        .replaceAll(RegExp(r'\bsebulan lagi\b'), 'bulan depan');
    t = t.split(' ').map((w) {
      if (w.isEmpty) return w;
      final clean = w.replaceAll(RegExp(r"[^\w'-]"), '');
      final fix = typo[clean];
      if (fix != null) return w.replaceFirst(clean, fix);
      if (RegExp(r'^n?g?i[nm]').hasMatch(clean) &&
          clean.length >= 6 &&
          clean.length <= 11 &&
          (_lev(clean, 'ingatkan') <= 2 || _lev(clean, 'ingetin') <= 2)) {
        return 'ingatkan';
      }
      return w;
    }).join(' ');
    t = t.replaceAllMapped(
        RegExp(r'\b(jam|pukul|setengah) (dua belas|sebelas|sepuluh|sembilan|delapan|tujuh|enam|lima|empat|tiga|dua|satu)\b'),
        (m) => '${m[1]} ${_numHour[m[2]]}');
    return t.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 'reminder' (buat pengingat), 'schedule' (tanya jadwal), atau 'other'.
  static String classify(String text) {
    final t = normalize(text);
    final isQuestion = RegExp(r'\?\s*$').hasMatch(text) ||
        RegExp(r'^ (apa|apakah|kapan|berapa|gimana|bagaimana|siapa|kenapa|mengapa|di mana|dimana|ada (jadwal|agenda|acara)|cek|lihat|tampilkan|tunjukkan) ')
            .hasMatch(t);
    final hasTrigger = RegExp(r' (ingatkan|ingat ya|jadwalkan|alarm|bangunkan|pasang|setel|set) ').hasMatch(t) ||
        RegExp(r' (buat|bikin|tambah|catat|masukkan|masukin) (jadwal|pengingat|agenda|alarm|reminder|acara) ').hasMatch(t);
    final words = t.trim().split(' ').length;
    final hasTime = RegExp(r' (jam|pukul) \d').hasMatch(t) ||
        RegExp(r' \d{1,2}[:.]\d{2} ').hasMatch(t) ||
        RegExp(r' \d+ ?(menit|jam|hari) lagi ').hasMatch(t) ||
        RegExp(r' setengah \d').hasMatch(t) ||
        RegExp(r' (tengah malam|tengah hari) ').hasMatch(t) ||
        (RegExp(r' (besok|lusa|nanti|minggu depan|bulan depan|akhir pekan|weekend) ').hasMatch(t) && words >= 3);
    final mentionsSchedule = RegExp(r' (jadwal|agenda|acara|kegiatan|rencana|pengingat|reminder|to ?do|tugas) ').hasMatch(t);
    if (hasTrigger) return 'reminder';
    if (mentionsSchedule && !hasTime) return 'schedule';
    if (hasTime && !isQuestion) return 'reminder';
    if (mentionsSchedule && isQuestion) return 'schedule';
    return 'other';
  }

  static final _rnd = Random();
  static String _pick(List<String> a) => a[_rnd.nextInt(a.length)];

  /// Kalkulator sederhana: "250 x 12", "berapa 100 bagi 4".
  static num? calc(String text) {
    var m = text
        .toLowerCase()
        .replaceAll(RegExp(r'berapa|hasil|hitung(kan)?|sama dengan|=|\?'), ' ')
        .replaceAll(RegExp(r'kali|x|×'), '*')
        .replaceAll(RegExp(r'bagi|:|÷'), '/')
        .replaceAll(RegExp(r'tambah|plus'), '+')
        .replaceAll(RegExp(r'kurang|minus'), '-')
        .replaceAll(',', '.')
        .replaceAll(' ', '');
    if (!RegExp(r'^[\d.+\-*/()]+$').hasMatch(m) || !RegExp(r'\d[+\-*/]\d').hasMatch(m)) return null;
    try {
      final p = _Expr(m);
      final v = p.parse();
      if (v.isNaN || v.isInfinite) return null;
      return (v * 1e6).round() / 1e6;
    } catch (_) {
      return null;
    }
  }

  /// Obrolan ringan tanpa internet. Null bila tidak ada jawaban yang cocok.
  static String? smallTalk(String text, {String name = '', required String greeting}) {
    final t = ' ${normalize(text).replaceAll(RegExp(r'[!?.,]'), ' ').replaceAll(RegExp(r'\s+'), ' ')} ';
    final n = name.isEmpty ? '' : ' $name';
    final words = t.trim().split(' ').length;
    bool has(String re) => RegExp(re).hasMatch(t);
    final v = calc(text);
    if (v != null) return 'Hasilnya **${v % 1 == 0 ? v.toInt() : v}** 🧮';
    if (has(r" (assalamualaikum|assalamu'alaikum|asalamualaikum|salam) ")) return 'Waalaikumsalam$n! 😊 Ada yang bisa aku bantu atau ingatkan?';
    if (has(r' (halo|hai|hi|hello|hey|hei|helo|hallo|p|pagi|siang|sore|malam|selamat (pagi|siang|sore|malam)) ') && words <= 4) {
      return _pick(['$greeting$n! 👋 Mau aku ingatkan sesuatu hari ini?', 'Hai$n! Ada yang bisa aku bantu? Coba bilang "ingatkan jam 4 sore jemput anak".', '$greeting! Semoga harimu lancar. Ada jadwal yang mau dicatat?']);
    }
    if (has(r' (apa kabar|gimana kabar|kabarnya|how are you) ')) return _pick(['Kabarku baik, siap membantu! 😄 Kamu sendiri gimana?', 'Baik dong! Ada yang mau aku ingatkan hari ini?']);
    if (has(r' (siapa kamu|kamu siapa|nama kamu|namamu|kamu itu apa) ')) {
      return 'Aku **Asisten IngetZeon** 🤖 — aku bisa membuat pengingat, mencatat lokasi parkir & tiketnya, mengingat letak barang, dan memberi tahu jadwalmu.';
    }
    if (has(r' (bisa apa|fitur|bantu apa|cara pakai|caranya|help|bantuan) ')) {
      return 'Ini yang bisa aku lakukan:\n'
          '• Buat pengingat: "ingatkan besok jam 7 olahraga", "tiap hari jam 8 malam minum obat", "10 menit lagi angkat jemuran"\n'
          '• Tanya jadwal: "jadwal hari ini?", "besok ada apa?"\n'
          '• Parkir: "saya parkir di B2", "di mana aku parkir?", "tampilkan tiket parkir"\n'
          '• Barang: "saya simpan kunci di laci", "di mana kunci saya?"\n'
          '• Lainnya: hitung "250 x 12", tanya jam/tanggal, atau minta motivasi 💪';
    }
    if (has(r' (makasih|terima kasih|terimakasih|thank) ')) return _pick(['Sama-sama! 😊', 'Sama-sama, senang bisa bantu!', 'Siap, sama-sama! Kabari kalau ada yang perlu diingatkan lagi.']);
    if (has(r' (oke|ok|okey|sip|siap|mantap|mantab|keren|bagus|good|nice|wkwk|haha|hehe) ') && words <= 3) return _pick(['Siap! 👍', 'Sip! Aku standby kalau butuh pengingat.', 'Mantap! 😄']);
    if (has(r' (jam berapa|pukul berapa|sekarang jam) ')) return 'Sekarang jam **${fmtTime(DateTime.now())}**.';
    if (has(r' besok hari apa ')) return 'Besok **${fmtDateLong(addDays(DateTime.now(), 1))}**.';
    if (has(r' (tanggal berapa|hari apa|hari ini tanggal) ')) return 'Hari ini **${fmtDateLong(DateTime.now())}**.';
    if (has(r' (capek|cape|lelah|letih|penat|stres|stress|pusing|sedih|galau|burnout) ')) {
      return _pick([
        'Kamu sudah berusaha keras hari ini 🤍 Coba istirahat sebentar, minum air, dan tarik napas dalam-dalam. Mau aku ingatkan istirahat 15 menit lagi?',
        'Wajar kok merasa lelah. Ambil jeda sebentar ya. Kalau mau, bilang "ingatkan 20 menit lagi lanjut kerja" biar kamu bisa rehat tenang.',
      ]);
    }
    if (has(r' (semangat|motivasi|kata kata|quote|inspirasi) ')) {
      return _pick([
        '"Sedikit demi sedikit, lama-lama menjadi bukit." Satu tugas selesai hari ini sudah kemajuan! 💪',
        'Fokus pada satu hal dulu, sisanya menyusul. Kamu pasti bisa! 🚀',
        '"Disiplin adalah jembatan antara tujuan dan pencapaian." Yuk, cek jadwal hari ini!',
        'Mulai saja dulu — tidak harus sempurna, yang penting jalan. ✨',
      ]);
    }
    if (has(r' (bosan|bosen|gabut) ')) return _pick(['Gabut? Coba rapikan meja 10 menit, baca beberapa halaman buku, atau jalan sebentar. Mau aku buatkan pengingatnya?', 'Waktu yang pas buat beres-beres jadwal minggu ini 😄 Bilang saja kegiatanmu, nanti aku catat.']);
    if (has(r' (lapar|laper|makan apa) ')) return _pick(['Waktunya makan! 🍛 Jangan sampai telat makan ya. Mau aku ingatkan makan siang tiap hari jam 12?', 'Isi tenaga dulu 🍜 — kalau sering lupa, bilang "ingatkan makan siang setiap hari jam 12".']);
    if (has(r' (ngantuk|mengantuk|mau tidur|tidur dulu) ')) return 'Istirahat yang cukup itu penting 😴 Mau aku pasang alarm bangun? Contoh: "bangunkan besok jam 5 pagi".';
    if (has(r' (lucu|lelucon|jokes|joke|candaan|ngelawak) ')) {
      return _pick(['Kenapa jam dinding selalu sabar? Karena dia tahu semua ada waktunya. ⏰😄', 'Aku asisten pengingat, tapi kadang aku juga lupa… lupa kalau aku tidak bisa lupa. 🤖', 'Kalender itu hidupnya pendek ya… hari-harinya sudah ditentukan. 📅😆']);
    }
    if (has(r' (aku cinta kamu|sayang kamu|love you|kangen) ')) return 'Hehe, makasih 😊 Aku senang bisa menemani dan membantu mengatur harimu!';
    if (has(r' (cuaca|hujan|panas) ')) return 'Aku belum bisa cek cuaca tanpa Gemini 🌦️ Tapi aku bisa ingatkan bawa payung: "ingatkan besok jam 7 bawa payung".';
    return null;
  }
}

/// Pengurai ekspresi + - * / dengan kurung.
class _Expr {
  _Expr(this.s);
  final String s;
  int i = 0;

  double parse() {
    final v = _sum();
    if (i != s.length) throw const FormatException();
    return v;
  }

  double _sum() {
    var v = _prod();
    while (i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final r = _prod();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double _prod() {
    var v = _atom();
    while (i < s.length && (s[i] == '*' || s[i] == '/')) {
      final op = s[i++];
      final r = _atom();
      v = op == '*' ? v * r : v / r;
    }
    return v;
  }

  double _atom() {
    if (i < s.length && s[i] == '(') {
      i++;
      final v = _sum();
      if (i >= s.length || s[i] != ')') throw const FormatException();
      i++;
      return v;
    }
    if (i < s.length && s[i] == '-') {
      i++;
      return -_atom();
    }
    final start = i;
    while (i < s.length && RegExp(r'[\d.]').hasMatch(s[i])) {
      i++;
    }
    return double.parse(s.substring(start, i));
  }
}
