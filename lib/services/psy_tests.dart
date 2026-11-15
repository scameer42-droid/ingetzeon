import 'dart:math' as math;

/// Tes psikologi (skrining) — sinkron dengan versi website (index.html).
/// Kuesioner yang dipakai bebas digunakan (domain publik / bebas tanpa izin):
/// PHQ-9, GAD-7, WHO-5, DASS-21, Copenhagen Burnout Inventory, UCLA-3, Rosenberg, PC-PTSD-5.
/// "Cek tidur" adalah cek mandiri buatan IngetZeon (bukan alat klinis).
/// Semua hasil = skrining, BUKAN diagnosis.
class PsyTest {
  const PsyTest({
    required this.id,
    required this.title,
    required this.short,
    required this.emoji,
    required this.colors,
    required this.intro,
    required this.items,
    required this.options,
    required this.source,
    this.optEmoji = const [],
    this.clinical = true,
    this.reverse = const {},
  });
  final String id;
  final String title;
  final String short;
  final String emoji;
  final List<int> colors; // gradasi 2 warna (ARGB)
  final String intro;
  final List<String> items;
  final List<(String, int)> options;
  final List<String> optEmoji;
  final String source;
  final bool clinical;
  final Set<int> reverse; // butir yang skornya dibalik

  int get minutes => math.max(1, (items.length / 4).ceil());

  static const _freq = [('Tidak pernah', 0), ('Beberapa hari', 1), ('Lebih dari separuh waktu', 2), ('Hampir setiap hari', 3)];
  static const _freqE = ['😊', '🙂', '😕', '😣'];

  static const phq9 = PsyTest(
    id: 'phq9',
    title: 'Suasana Hati',
    short: 'Skrining depresi (PHQ-9)',
    emoji: '🌤️',
    colors: [0xFF6366F1, 0xFF8B5CF6],
    intro: 'Selama 2 minggu terakhir, seberapa sering kamu terganggu oleh hal-hal berikut?',
    items: [
      'Kurang tertarik atau kurang senang dalam melakukan apa pun',
      'Merasa murung, sedih, atau putus asa',
      'Sulit tidur atau mudah terbangun, atau malah terlalu banyak tidur',
      'Merasa lelah atau kurang bertenaga',
      'Kurang nafsu makan atau makan berlebihan',
      'Merasa buruk tentang diri sendiri — merasa gagal atau telah mengecewakan diri sendiri maupun keluarga',
      'Sulit berkonsentrasi, misalnya saat membaca atau menonton televisi',
      'Bergerak atau bicara sangat lambat sampai orang lain memperhatikannya — atau sebaliknya, sangat gelisah sehingga lebih banyak bergerak dari biasanya',
      'Berpikir bahwa lebih baik mati, atau ingin menyakiti diri sendiri dengan cara apa pun',
    ],
    options: _freq,
    optEmoji: _freqE,
    source: 'Patient Health Questionnaire-9 (Kroenke, Spitzer & Williams)',
  );

  static const gad7 = PsyTest(
    id: 'gad7',
    title: 'Kecemasan',
    short: 'Skrining cemas (GAD-7)',
    emoji: '🍃',
    colors: [0xFF06B6D4, 0xFF3B82F6],
    intro: 'Selama 2 minggu terakhir, seberapa sering kamu terganggu oleh hal-hal berikut?',
    items: [
      'Merasa gugup, cemas, atau tegang',
      'Tidak mampu menghentikan atau mengendalikan rasa khawatir',
      'Terlalu mengkhawatirkan berbagai hal',
      'Sulit untuk merasa rileks',
      'Sangat gelisah sampai sulit untuk duduk diam',
      'Mudah kesal atau mudah tersinggung',
      'Merasa takut seolah-olah sesuatu yang buruk akan terjadi',
    ],
    options: _freq,
    optEmoji: _freqE,
    source: 'Generalized Anxiety Disorder-7 (Spitzer, Kroenke, Williams & Löwe)',
  );

  static const dass21 = PsyTest(
    id: 'dass21',
    title: 'Stres, Cemas & Depresi',
    short: 'Cek lengkap 3 sisi (DASS-21)',
    emoji: '🧭',
    colors: [0xFFF97316, 0xFFEC4899],
    intro: 'Selama 1 minggu terakhir, seberapa sesuai pernyataan berikut dengan dirimu?',
    items: [
      'Saya sulit untuk menenangkan diri',
      'Mulut saya terasa kering',
      'Saya sama sekali tidak bisa merasakan perasaan positif',
      'Saya mengalami kesulitan bernapas (misalnya napas cepat atau sesak padahal tidak sedang beraktivitas berat)',
      'Saya sulit memulai inisiatif untuk melakukan sesuatu',
      'Saya cenderung bereaksi berlebihan terhadap suatu situasi',
      'Saya merasa gemetar (misalnya pada tangan)',
      'Saya merasa menghabiskan banyak energi karena gelisah',
      'Saya khawatir akan situasi di mana saya bisa panik dan mempermalukan diri sendiri',
      'Saya merasa tidak ada hal yang bisa saya harapkan',
      'Saya merasa mudah gelisah',
      'Saya sulit untuk bersantai',
      'Saya merasa sedih dan murung',
      'Saya tidak bisa menoleransi hal apa pun yang menghalangi saya menyelesaikan pekerjaan',
      'Saya merasa hampir panik',
      'Saya tidak bisa merasa antusias terhadap hal apa pun',
      'Saya merasa tidak berharga sebagai manusia',
      'Saya merasa mudah tersinggung',
      'Saya merasakan detak jantung saya padahal tidak sedang beraktivitas fisik (misalnya berdebar)',
      'Saya merasa takut tanpa alasan yang jelas',
      'Saya merasa hidup ini tidak berarti',
    ],
    options: [('Tidak sesuai sama sekali', 0), ('Kadang-kadang sesuai', 1), ('Lumayan sering sesuai', 2), ('Sangat sesuai / sering sekali', 3)],
    optEmoji: ['😊', '🙂', '😕', '😣'],
    source: 'Depression Anxiety Stress Scales-21 (Lovibond & Lovibond), domain publik',
  );

  static const who5 = PsyTest(
    id: 'who5',
    title: 'Kebahagiaan',
    short: 'Indeks kesejahteraan (WHO-5)',
    emoji: '🌻',
    colors: [0xFFF59E0B, 0xFFF97316],
    intro: 'Selama 2 minggu terakhir, seberapa sesuai pernyataan berikut dengan dirimu?',
    items: [
      'Saya merasa ceria dan bersemangat',
      'Saya merasa tenang dan santai',
      'Saya merasa aktif dan bertenaga',
      'Saya bangun dengan perasaan segar dan cukup istirahat',
      'Hari-hari saya diisi dengan hal-hal yang menarik bagi saya',
    ],
    options: [('Sepanjang waktu', 5), ('Sering sekali', 4), ('Lebih dari separuh waktu', 3), ('Kurang dari separuh waktu', 2), ('Kadang-kadang', 1), ('Tidak pernah', 0)],
    optEmoji: ['🤩', '😄', '🙂', '😐', '😕', '😞'],
    source: 'WHO-5 Well-Being Index (WHO Collaborating Centre in Mental Health)',
  );

  static const burnout = PsyTest(
    id: 'burnout',
    title: 'Burnout',
    short: 'Kelelahan kerja & hidup (CBI)',
    emoji: '🔋',
    colors: [0xFFEF4444, 0xFFF59E0B],
    intro: 'Pikirkan keadaanmu belakangan ini. Seberapa sering kamu…',
    items: [
      'Merasa lelah?',
      'Merasa capek secara fisik?',
      'Merasa capek secara emosional?',
      'Berpikir "aku sudah tidak sanggup lagi"?',
      'Merasa terkuras habis?',
      'Merasa lemah dan mudah sakit?',
    ],
    options: [('Selalu', 100), ('Sering', 75), ('Kadang-kadang', 50), ('Jarang', 25), ('Tidak pernah / hampir tidak pernah', 0)],
    optEmoji: ['🪫', '😩', '😐', '🙂', '⚡'],
    source: 'Copenhagen Burnout Inventory — Personal Burnout (Kristensen dkk.)',
  );

  static const ucla3 = PsyTest(
    id: 'ucla3',
    title: 'Kesepian',
    short: 'Rasa terhubung dengan orang lain (UCLA-3)',
    emoji: '🤝',
    colors: [0xFF14B8A6, 0xFF22C55E],
    intro: 'Pertanyaan berikut tentang perasaanmu terhadap orang-orang di sekitarmu.',
    items: [
      'Seberapa sering kamu merasa kurang punya teman dekat untuk berbagi?',
      'Seberapa sering kamu merasa ditinggalkan atau tidak diajak?',
      'Seberapa sering kamu merasa terasing dari orang lain?',
    ],
    options: [('Hampir tidak pernah', 1), ('Kadang-kadang', 2), ('Sering', 3)],
    optEmoji: ['😊', '😐', '😔'],
    source: 'UCLA 3-Item Loneliness Scale (Hughes dkk., 2004)',
  );

  static const rses = PsyTest(
    id: 'rses',
    title: 'Percaya Diri',
    short: 'Harga diri & penerimaan diri (Rosenberg)',
    emoji: '💎',
    colors: [0xFFD946EF, 0xFF8B5CF6],
    intro: 'Seberapa setuju kamu dengan pernyataan berikut tentang dirimu?',
    items: [
      'Secara keseluruhan, saya puas dengan diri saya',
      'Kadang saya merasa diri saya sama sekali tidak baik',
      'Saya merasa punya beberapa kelebihan yang baik',
      'Saya mampu melakukan sesuatu sebaik kebanyakan orang lain',
      'Saya merasa tidak banyak hal yang bisa saya banggakan',
      'Kadang saya benar-benar merasa tidak berguna',
      'Saya merasa diri saya berharga, setidaknya setara dengan orang lain',
      'Saya berharap bisa lebih menghargai diri sendiri',
      'Secara keseluruhan, saya cenderung merasa sebagai orang yang gagal',
      'Saya bersikap positif terhadap diri saya sendiri',
    ],
    options: [('Sangat setuju', 3), ('Setuju', 2), ('Tidak setuju', 1), ('Sangat tidak setuju', 0)],
    optEmoji: ['💯', '👍', '👎', '🙅'],
    reverse: {1, 4, 5, 7, 8},
    source: 'Rosenberg Self-Esteem Scale (Rosenberg, 1965)',
  );

  static const ptsd5 = PsyTest(
    id: 'ptsd5',
    title: 'Trauma',
    short: 'Dampak kejadian berat (PC-PTSD-5)',
    emoji: '🕊️',
    colors: [0xFF0EA5E9, 0xFF6366F1],
    intro: 'Kadang hal yang sangat menakutkan atau mengguncang terjadi — misalnya kecelakaan serius, kebakaran, kekerasan, kematian mendadak orang tercinta, atau bencana alam.',
    items: [
      'Pernahkah kamu mengalami kejadian seperti itu?',
      'Dalam sebulan terakhir, apakah kamu mimpi buruk tentang kejadian itu, atau teringat padahal tidak ingin?',
      'Dalam sebulan terakhir, apakah kamu berusaha keras tidak memikirkannya, atau menghindari situasi yang mengingatkanmu?',
      'Dalam sebulan terakhir, apakah kamu terus waspada, berjaga-jaga, atau mudah kaget?',
      'Dalam sebulan terakhir, apakah kamu merasa mati rasa atau berjarak dari orang lain, aktivitas, atau lingkunganmu?',
      'Dalam sebulan terakhir, apakah kamu merasa bersalah atau terus menyalahkan diri sendiri/orang lain atas kejadian itu?',
    ],
    options: [('Ya', 1), ('Tidak', 0)],
    optEmoji: ['✔️', '✖️'],
    source: 'Primary Care PTSD Screen for DSM-5 (U.S. National Center for PTSD), domain publik',
  );

  static const sleep = PsyTest(
    id: 'tidur',
    title: 'Kualitas Tidur',
    short: 'Cek mandiri pola tidur',
    emoji: '🌙',
    colors: [0xFF4F46E5, 0xFF0EA5E9],
    intro: 'Selama 2 minggu terakhir, seberapa sering hal ini terjadi?',
    items: [
      'Butuh lebih dari 30 menit untuk bisa tertidur',
      'Terbangun di malam hari dan sulit tidur lagi',
      'Bangun terlalu pagi dan tidak bisa tidur kembali',
      'Bangun dengan badan tidak segar',
      'Mengantuk atau sulit fokus di siang hari',
      'Main HP di kasur sampai larut sebelum tidur',
    ],
    options: _freq,
    optEmoji: _freqE,
    clinical: false,
    source: 'Cek mandiri IngetZeon (bukan alat klinis)',
  );

  static const all = [dass21, phq9, gad7, burnout, who5, ucla3, rses, sleep, ptsd5];

  static PsyTest? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tes berhenti lebih awal? (PC-PTSD-5: bila tidak pernah mengalami kejadian traumatis)
  bool stopsAfter(List<int> answers) => id == 'ptsd5' && answers.length == 1 && answers.first == 0;

  /// Nilai butir setelah pembalikan skor.
  int valueOf(int index, int raw) {
    if (!reverse.contains(index)) return raw;
    final mx = options.map((o) => o.$2).reduce(math.max);
    final mn = options.map((o) => o.$2).reduce(math.min);
    return mx + mn - raw;
  }

  static const quotes = [
    'Kamu lebih kuat dari yang kamu kira 💪',
    'Langkah kecil tetap langkah maju 🌱',
    'Jangan pernah menyerah — kamu sudah sejauh ini! 🔥',
    'Mengenal diri sendiri adalah awal dari bangkit ✨',
    'Hari yang berat tidak akan bertahan selamanya 🌈',
    'Kamu layak bahagia, dan kamu sedang menuju ke sana ☀️',
    'Berani jujur pada diri sendiri itu tanda pejuang 🏅',
  ];

  /// Pesan semangat di sela pertanyaan.
  static String cheer(int answered, int total) {
    if (answered == 0) return 'Yuk mulai! Jawab sejujurnya, tidak ada jawaban benar atau salah 🌟';
    final p = answered / total;
    if (p >= .99) return 'Pertanyaan terakhir! Kamu hebat 🏁';
    if (p >= .75) return 'Sedikit lagi, semangat! 🚀';
    if (p >= .5) return 'Setengah jalan! Kamu keren 💪';
    if (p >= .25) return 'Bagus, lanjut terus! ✨';
    return 'Mantap, terus jujur ya 👍';
  }
}

class TestPart {
  const TestPart(this.label, this.score, this.max, this.level, this.severity);
  final String label;
  final int score;
  final int max;
  final String level;
  final int severity;
}

class TestResult {
  const TestResult({
    required this.score,
    required this.max,
    required this.level,
    required this.summary,
    required this.advice,
    required this.severity,
    this.crisis = false,
    this.parts = const [],
  });
  final int score;
  final int max;
  final String level;
  final String summary;
  final List<String> advice;
  final int severity; // 0 baik … 3 berat
  final bool crisis;
  final List<TestPart> parts;

  /// Kalimat penyemangat sesuai hasil.
  String get cheer => severity == 0
      ? 'Hebat! Kondisimu sedang baik. Pertahankan kebiasaan baikmu — kamu luar biasa! 🌟'
      : severity == 1
          ? 'Kamu sudah berani jujur pada diri sendiri, itu langkah pertama yang keren. Sedikit perhatian ekstra dan kamu pasti bisa bangkit! 🌱'
          : 'Terima kasih sudah berani jujur. Yang kamu rasakan itu nyata — dan bantuan itu ada. Mencari bantuan bukan tanda lemah, itu tanda kamu pejuang. Jangan menyerah ya, kamu tidak sendirian 💛';

  static const _seek = 'Konsultasi dengan psikolog/psikiater atau puskesmas, atau layanan gratis Healing119 (telepon 119 tekan 8).';

  static (String, int) _band(int s, List<(int, String, int)> bands) {
    for (final b in bands) {
      if (s <= b.$1) return (b.$2, b.$3);
    }
    return (bands.last.$2, bands.last.$3);
  }

  static TestResult evaluate(PsyTest t, List<int> raw) {
    final a = [for (var i = 0; i < raw.length; i++) t.valueOf(i, raw[i])];
    final score = a.fold<int>(0, (x, y) => x + y);
    switch (t.id) {
      case 'phq9':
        final crisis = a.length >= 9 && a[8] > 0;
        final (lvl, sev) = _band(score, [(4, 'Minimal', 0), (9, 'Ringan', 1), (14, 'Sedang', 2), (19, 'Cukup berat', 3), (27, 'Berat', 3)]);
        return TestResult(
          score: score,
          max: 27,
          level: lvl,
          severity: sev,
          crisis: crisis,
          summary: sev == 0
              ? 'Gejala suasana hati murung minimal.'
              : sev == 1
                  ? 'Ada beberapa gejala ringan. Perhatikan pola tidur, gerak, dan hubungan sosialmu.'
                  : 'Gejalamu cukup terasa dan bisa mengganggu aktivitas. Sebaiknya bicarakan dengan psikolog atau dokter.',
          advice: [
            if (sev >= 2) _seek,
            if (sev >= 1) 'Catat mood harian & tulis jurnal untuk melihat polanya.',
            'Jaga tidur teratur, gerak badan 20–30 menit, dan tetap terhubung dengan orang terdekat.',
            if (sev == 0) 'Ulangi tes ini sebulan lagi untuk memantau kondisimu.',
          ],
        );
      case 'gad7':
        final (lvl, sev) = _band(score, [(4, 'Minimal', 0), (9, 'Ringan', 1), (14, 'Sedang', 2), (21, 'Berat', 3)]);
        return TestResult(
          score: score,
          max: 21,
          level: lvl,
          severity: sev,
          summary: sev == 0
              ? 'Tingkat kecemasanmu rendah.'
              : sev == 1
                  ? 'Ada kecemasan ringan. Latihan napas & grounding bisa membantu.'
                  : 'Kecemasanmu cukup tinggi dan bisa mengganggu keseharian. Sebaiknya konsultasikan dengan psikolog.',
          advice: [
            if (sev >= 2) _seek,
            if (sev >= 1) 'Latih napas kotak atau 4-7-8 dua kali sehari, terutama saat cemas muncul.',
            'Batasi kafein & berita yang memicu cemas, dan jaga waktu tidur.',
          ],
        );
      case 'dass21':
        const sIdx = [0, 5, 7, 10, 11, 13, 17], aIdx = [1, 3, 6, 8, 14, 18, 19], dIdx = [2, 4, 9, 12, 15, 16, 20];
        int sum(List<int> ix) => ix.fold<int>(0, (x, i) => x + (i < a.length ? a[i] : 0)) * 2;
        final d = sum(dIdx), an = sum(aIdx), st = sum(sIdx);
        final (dl, ds) = _band(d, [(9, 'Normal', 0), (13, 'Ringan', 1), (20, 'Sedang', 2), (27, 'Berat', 3), (42, 'Sangat berat', 3)]);
        final (al, as_) = _band(an, [(7, 'Normal', 0), (9, 'Ringan', 1), (14, 'Sedang', 2), (19, 'Berat', 3), (42, 'Sangat berat', 3)]);
        final (sl, ss) = _band(st, [(14, 'Normal', 0), (18, 'Ringan', 1), (25, 'Sedang', 2), (33, 'Berat', 3), (42, 'Sangat berat', 3)]);
        final sev = [ds, as_, ss].reduce(math.max);
        final worst = [('stres', ss), ('kecemasan', as_), ('depresi', ds)].reduce((x, y) => y.$2 > x.$2 ? y : x).$1;
        return TestResult(
          score: d + an + st,
          max: 126,
          level: sev == 0 ? 'Normal' : sev == 1 ? 'Ringan' : sev == 2 ? 'Sedang' : 'Berat',
          severity: sev,
          crisis: a.length >= 21 && a[20] >= 2,
          parts: [TestPart('Stres', st, 42, sl, ss), TestPart('Kecemasan', an, 42, al, as_), TestPart('Depresi', d, 42, dl, ds)],
          summary: sev == 0 ? 'Ketiga sisi (stres, cemas, depresi) dalam batas normal.' : 'Yang paling menonjol saat ini: $worst. Lihat rincian di bawah.',
          advice: [
            if (sev >= 2) _seek,
            if (ss >= 1) 'Stres: pecah tugas jadi langkah kecil, pakai timer fokus, dan sisihkan waktu istirahat.',
            if (as_ >= 1) 'Cemas: latihan napas & grounding 5-4-3-2-1 saat gelisah muncul.',
            if (ds >= 1) 'Suasana hati: lakukan satu kegiatan kecil yang menyenangkan setiap hari & tetap terhubung dengan orang terdekat.',
            if (sev == 0) 'Pertahankan! Ulangi cek ini sebulan lagi.',
          ],
        );
      case 'who5':
        final pct = score * 4;
        final (lvl, sev) = pct > 50 ? ('Baik', 0) : (pct > 28 ? ('Rendah', 2) : ('Sangat rendah', 3));
        return TestResult(
          score: pct,
          max: 100,
          level: lvl,
          severity: sev,
          summary: sev == 0 ? 'Kesejahteraanmu dalam kondisi baik.' : 'Kesejahteraanmu sedang rendah. Coba juga tes Suasana Hati (PHQ-9).',
          advice: [
            if (sev > 0) 'Coba tes Suasana Hati (PHQ-9) untuk gambaran yang lebih jelas.',
            if (sev == 3) _seek,
            'Rencanakan satu kegiatan menyenangkan setiap hari, sekecil apa pun.',
          ],
        );
      case 'burnout':
        final avg = a.isEmpty ? 0 : (score / a.length).round();
        final (lvl, sev) = _band(avg, [(49, 'Rendah', 0), (74, 'Sedang', 1), (99, 'Tinggi', 2), (100, 'Sangat tinggi', 3)]);
        return TestResult(
          score: avg,
          max: 100,
          level: lvl,
          severity: sev,
          summary: sev == 0 ? 'Tingkat kelelahanmu masih aman.' : 'Kamu menunjukkan tanda-tanda burnout. Tubuh dan pikiranmu butuh pemulihan.',
          advice: [
            if (sev >= 2) 'Bicarakan beban kerja dengan atasan/keluarga, dan pertimbangkan konsultasi dengan psikolog.',
            if (sev >= 1) 'Jadwalkan istirahat sungguhan: tidur cukup, cuti singkat, atau hari tanpa kerja.',
            'Pakai timer fokus 25/5 agar kerja tidak terus-menerus tanpa jeda.',
          ],
        );
      case 'ucla3':
        final (lvl, sev) = _band(score, [(5, 'Terhubung', 0), (7, 'Agak kesepian', 1), (9, 'Kesepian', 2)]);
        return TestResult(
          score: score,
          max: 9,
          level: lvl,
          severity: sev,
          summary: sev == 0 ? 'Kamu merasa cukup terhubung dengan orang lain.' : 'Kamu merasakan kesepian. Itu perasaan yang umum dan bisa membaik.',
          advice: [
            if (sev >= 1) 'Kabari satu orang hari ini — teman lama, saudara, atau rekan kerja.',
            if (sev >= 1) 'Ikut kegiatan rutin bersama orang lain: komunitas, olahraga, pengajian/ibadah bersama.',
            if (sev >= 2) 'Kalau kesepian terasa sangat berat, cerita ke Healing119 (119 tekan 8) atau psikolog.',
            if (sev == 0) 'Pertahankan hubunganmu — sapa orang-orang terdekatmu secara rutin.',
          ],
        );
      case 'rses':
        final (lvl, sev) = score < 15 ? ('Rendah', 2) : (score <= 25 ? ('Normal', 0) : ('Tinggi', 0));
        return TestResult(
          score: score,
          max: 30,
          level: lvl,
          severity: sev,
          summary: sev == 0 ? 'Penghargaanmu terhadap diri sendiri cukup sehat.' : 'Kamu sedang kurang menghargai diri sendiri. Padahal kamu punya nilai yang berharga.',
          advice: [
            if (sev > 0) 'Tulis 3 hal yang kamu lakukan dengan baik setiap malam di jurnal.',
            if (sev > 0) 'Perhatikan suara hati yang terlalu keras — bicaralah pada dirimu seperti pada sahabat.',
            if (sev > 0) 'Kalau perasaan tidak berharga terus muncul, bicarakan dengan psikolog.',
            if (sev == 0) 'Terus rawat dirimu dan rayakan pencapaian kecil.',
          ],
        );
      case 'ptsd5':
        if (a.isEmpty || a.first == 0) {
          return const TestResult(
            score: 0,
            max: 5,
            level: 'Tidak ada kejadian traumatis',
            severity: 0,
            summary: 'Kamu tidak melaporkan pengalaman traumatis, jadi tes ini tidak perlu dilanjutkan.',
            advice: ['Kalau suatu saat mengalami kejadian berat, jangan ragu cerita ke orang terdekat atau profesional.'],
          );
        }
        final yes = a.skip(1).fold<int>(0, (x, y) => x + y);
        final (lvl, sev) = yes >= 4 ? ('Positif (kuat)', 3) : (yes == 3 ? ('Positif', 2) : (yes >= 1 ? ('Ada beberapa gejala', 1) : ('Minimal', 0)));
        return TestResult(
          score: yes,
          max: 5,
          level: lvl,
          severity: sev,
          summary: sev >= 2
              ? 'Kejadian itu tampaknya masih sangat memengaruhimu. Ini reaksi yang bisa dipulihkan dengan bantuan yang tepat.'
              : sev == 1
                  ? 'Ada beberapa dampak dari kejadian itu. Perhatikan dirimu baik-baik.'
                  : 'Dampak kejadian itu tampaknya sudah tidak terlalu mengganggu.',
          advice: [
            if (sev >= 2) 'Sebaiknya konsultasi dengan psikolog/psikiater — trauma bisa ditangani dengan terapi yang terbukti efektif.',
            if (sev >= 2) 'Bantuan gratis: Healing119 (telepon 119 tekan 8).',
            'Grounding 5-4-3-2-1 dan latihan napas membantu saat ingatan buruk muncul.',
            'Ceritakan ke orang yang kamu percaya; kamu tidak harus memendamnya sendiri.',
          ],
        );
      default: // tidur
        final (lvl, sev) = _band(score, [(5, 'Baik', 0), (11, 'Perlu perhatian', 1), (18, 'Terganggu', 2)]);
        return TestResult(
          score: score,
          max: 18,
          level: lvl,
          severity: sev,
          summary: sev == 0 ? 'Pola tidurmu cukup baik.' : 'Tidurmu sedang kurang berkualitas — ini bisa memengaruhi mood dan energi.',
          advice: [
            'Tidur & bangun di jam yang sama setiap hari, termasuk akhir pekan.',
            if (sev >= 1) 'Jauhkan HP 30 menit sebelum tidur; coba napas 4-7-8 di kasur.',
            if (sev >= 1) 'Kurangi kopi/teh setelah jam 2 siang.',
            if (sev >= 2) 'Kalau berlangsung lebih dari sebulan, periksakan ke dokter.',
          ],
        );
    }
  }
}
