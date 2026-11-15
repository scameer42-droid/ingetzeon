/// Merapikan teks untuk suara — sinkron dengan versi website (index.html).
class SpeechText {
  static const _hari = {'Min': 'Minggu', 'Sen': 'Senin', 'Sel': 'Selasa', 'Rab': 'Rabu', 'Kam': 'Kamis', 'Jum': 'Jumat', 'Sab': 'Sabtu'};
  static const _bulan = {
    'Jan': 'Januari', 'Feb': 'Februari', 'Mar': 'Maret', 'Apr': 'April', 'Mei': 'Mei', 'Jun': 'Juni',
    'Jul': 'Juli', 'Agu': 'Agustus', 'Sep': 'September', 'Okt': 'Oktober', 'Nov': 'November', 'Des': 'Desember',
  };
  static final List<(RegExp, String)> _abbr = [
    (RegExp(r'\bgr\b', caseSensitive: false), 'gram'),
    (RegExp(r'\bkg\b', caseSensitive: false), 'kilo'),
    (RegExp(r'\brb\b', caseSensitive: false), 'ribu'),
    (RegExp(r'\bjt\b', caseSensitive: false), 'juta'),
    (RegExp(r'\bdll\b\.?', caseSensitive: false), 'dan lain-lain'),
    (RegExp(r'\bdsb\b\.?', caseSensitive: false), 'dan sebagainya'),
    (RegExp(r'\bmis\.\s?', caseSensitive: false), 'misalnya '),
    (RegExp(r'\byg\b', caseSensitive: false), 'yang'),
    (RegExp(r'\btgl\b', caseSensitive: false), 'tanggal'),
    (RegExp(r'\bno\.\s?', caseSensitive: false), 'nomor '),
    (RegExp(r'\bHP\b'), 'ha pe'),
    (RegExp(r'\bQR\b'), 'kiu ar'),
    (RegExp(r'\bAPK\b'), 'a pe ka'),
    (RegExp(r'\bIngetZeon\b'), 'Inget Zeon'),
    (RegExp(r'\bAI\b'), 'a i'),
    (RegExp(r'\bOK\b'), 'oke'),
    (RegExp(r'\bWA\b'), 'we a'),
    (RegExp(r'\bFB\b', caseSensitive: false), 'facebook'),
    (RegExp(r'\bIG\b'), 'instagram'),
    (RegExp(r'\bvs\b', caseSensitive: false), 'lawan'),
    (RegExp(r'\bsdt\b', caseSensitive: false), 'sendok teh'),
    (RegExp(r'\bsdm\b', caseSensitive: false), 'sendok makan'),
    (RegExp(r'\bdkk\b', caseSensitive: false), 'dan kawan-kawan'),
  ];

  /// Teks balasan → teks yang enak dibacakan TTS (jam, tanggal, singkatan, emoji).
  static String forTts(String s) {
    var t = s
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'•{3,}'), '')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]', unicode: true), '')
        .replaceAll(RegExp(r'[*_#`>~]'), '')
        .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'^\s*(\d+)[.)]\s+', multiLine: true), (m) => '${m[1]}, ');
    t = t.replaceAllMapped(RegExp(r'\bRp\.?\s?([\d.,]+)', caseSensitive: false), (m) => '${m[1]} rupiah');
    t = t.replaceAllMapped(RegExp(r'(\b(?:jam|pukul)\s+)?(?<![\d.,])([01]?\d|2[0-4])[.:]([0-5]\d)(?![\d.,]*\d)', caseSensitive: false), (m) {
      final pre = m[1], h = int.parse(m[2]!), mm = int.parse(m[3]!);
      return '${pre != null ? '${pre.trim()} ' : 'jam '}$h${mm != 0 ? ' lewat $mm' : ''}';
    });
    t = t.replaceAll(RegExp(r'\bjam\s+jam\b', caseSensitive: false), 'jam');
    final thousands = RegExp(r'(\d)\.(\d{3})(?!\d)');
    while (thousands.hasMatch(t)) {
      t = t.replaceAllMapped(thousands, (m) => '${m[1]}${m[2]}');
    }
    t = t.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]} koma ${m[2]}');
    t = t.replaceAllMapped(RegExp(r'\b(Min|Sen|Sel|Rab|Kam|Jum|Sab),'), (m) => '${_hari[m[1]]},');
    t = t.replaceAllMapped(RegExp(r'\b(\d{1,2}) (Jan|Feb|Mar|Apr|Mei|Jun|Jul|Agu|Sep|Okt|Nov|Des)\b'), (m) => '${m[1]} ${_bulan[m[2]]}');
    for (final (re, to) in _abbr) {
      t = t.replaceAll(re, to);
    }
    t = t
        .replaceAllMapped(RegExp(r'(\d)\s*[–-]\s*(\d)'), (m) => '${m[1]} sampai ${m[2]}')
        .replaceAll(RegExp(r'\s*–\s*'), ' sampai ')
        .replaceAll(RegExp(r'\s*—\s*'), ', ')
        .replaceAll(RegExp(r'\s*·\s*'), ', ')
        .replaceAll(RegExp(r'\b1/2\b'), 'setengah')
        .replaceAllMapped(RegExp(r'(\d)/(\d)'), (m) => '${m[1]} per ${m[2]}')
        .replaceAll('(', ', ')
        .replaceAll(')', ', ')
        .replaceAll(RegExp(r'±\s?'), 'sekitar ')
        .replaceAll('&', ' dan ')
        .replaceAll('%', ' persen')
        .replaceAllMapped(RegExp(r'(\d)\s?x\s?(\d)', caseSensitive: false), (m) => '${m[1]} kali ${m[2]}')
        .replaceAllMapped(RegExp(r'\bke-(\d)', caseSensitive: false), (m) => 'ke ${m[1]}')
        .replaceAll(RegExp(r'\s*/\s*'), ' atau ')
        .replaceAll('°C', ' derajat')
        .replaceAll(RegExp(r'[\[\]{}"“”]'), ' ');
    t = t
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAllMapped(RegExp(r',\s*([.!?])'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\s*([.,!?])(\s*[.,!?])+'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\s+([.,!?])'), (m) => m[1]!)
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim()
        .replaceFirst(RegExp(r',$'), '.');
    return t;
  }

  static const _num = {'nol': 0, 'kosong': 0, 'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10};
  static const _letter = {'be': 'B', 'bi': 'B', 'b': 'B', 'pe': 'P', 'p': 'P', 'el': 'L', 'l': 'L', 'g': 'G', 'ji': 'G', 'ge': 'G'};

  /// Hasil dengar (speech-to-text) → teks rapi: "parkir di be dua" → "Parkir di B2".
  static String fromStt(String s) {
    var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(r'parkir|lantai|basement|lt\b', caseSensitive: false).hasMatch(t)) {
      t = t.replaceAllMapped(RegExp(r'\b(lantai|basement|lt\.?)\s+(nol|kosong|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh)\b', caseSensitive: false),
          (m) => '${m[1]} ${_num[m[2]!.toLowerCase()]}');
      t = t.replaceAllMapped(RegExp(r'\b(be|bi|b|pe|p|el|l|g|ji|ge)\s*[- ]?\s*(nol|kosong|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|\d{1,2})\b', caseSensitive: false), (m) {
        final n = m[2]!.toLowerCase();
        return '${_letter[m[1]!.toLowerCase()]}${_num.containsKey(n) ? _num[n] : n}';
      });
      t = t.replaceAll(RegExp(r'\b(el ji|elji|lower ground)\b', caseSensitive: false), 'LG').replaceAll(RegExp(r'\b(upper ground|ap ji)\b', caseSensitive: false), 'UG');
    }
    t = t.replaceAllMapped(RegExp(r'(\d{1,2}):(\d{2})'), (m) => '${m[1]}.${m[2]}');
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}
