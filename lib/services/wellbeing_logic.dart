import 'dart:math';

export 'psy_tests.dart';

/// Logika Ruang Tenang (tanpa UI) — sinkron dengan versi website (index.html).
/// IngetZeon BUKAN pengganti psikolog/psikiater; bagian ini memberi dukungan awal,
/// latihan menenangkan diri, dan mengarahkan ke bantuan profesional (Healing119).

enum Emotion { sedih, cemas, stres, lelah, marah, kesepian, tidur, senang }

/// Alat bantu yang bisa dibuka dari balasan chat.
abstract class Tool {
  static const napas = 'napas';
  static const grounding = 'grounding';
  static const jurnal = 'jurnal';
  static const mood = 'mood';
  static const fokus = 'fokus';
  static const tes = 'tes';
  static const healing = 'healing119';
  static const telepon = 'telepon119';
  static const label = {
    napas: '🌬️ Latihan napas',
    grounding: '🖐️ Grounding 5-4-3-2-1',
    jurnal: '📓 Tulis jurnal',
    mood: '🙂 Catat mood',
    fokus: '⏱️ Timer fokus',
    tes: '📝 Tes psikologi',
    healing: '💬 Healing119.id',
    telepon: '📞 Telepon 119 ext 8',
  };
}

class FeelingResult {
  const FeelingResult({required this.crisis, required this.emotions});
  final bool crisis;
  final List<Emotion> emotions; // urut prioritas
  Emotion? get main => emotions.isEmpty ? null : emotions.first;
}

class Feelings {
  static final _crisis = RegExp(
      r'bunuh diri|bundir|ingin mati|pengen mati|pengin mati|pingin mati|ingin meninggal|mau mati aja|mau mati saja|mending mati|lebih baik mati|lebih baik aku mati|'
      r'(mengakhiri|akhiri|akhirin|selesaikan) hidup|(gak|ga|nggak|tidak|tak|gk) (mau|ingin|pengen|kuat) hidup( lagi)?|capek hidup|cape hidup|lelah hidup|'
      r'(gak|ga|tidak|tak) ada gunanya (aku )?hidup|hidup (gak|ga|tidak) ada (gunanya|artinya)|(menyakiti|sakiti|melukai|lukai|nyakitin) diri|self ?harm|nyilet|menyayat|sayat (tangan|nadi)|'
      r'potong nadi|loncat dari|lompat dari (gedung|jembatan|atap)|minum racun|overdosis|gantung diri|menghilang (untuk )?selamanya|pengen hilang dari dunia',
      caseSensitive: false);

  static final Map<Emotion, RegExp> _words = {
    Emotion.sedih: RegExp(r'\b(sedih|sedihh+|nangis|menangis|nangis terus|hancur|terpuruk|kecewa|patah hati|putus|diputusin|galau|down|hampa|kosong|murung|berduka|kehilangan|ditinggal|ditinggalin|depresi|depresot|sakit hati|terluka|bersalah|nyesel|menyesal|gagal)\b', caseSensitive: false),
    Emotion.cemas: RegExp(r'\b(cemas|khawatir|kuatir|takut|was[- ]?was|gelisah|panik|deg[- ]?degan|overthinking|overthink|anxiety|anxious|gugup|nervous|insecure|minder|parno|ketakutan)\b', caseSensitive: false),
    Emotion.stres: RegExp(r'\b(stres|stress|stresss+|tertekan|beban|terbebani|kewalahan|overwhelmed|burnout|burn out|banyak pikiran|mumet|ruwet|pusing mikirin|dikejar deadline|numpuk)\b', caseSensitive: false),
    Emotion.lelah: RegExp(r'\b(capek|cape|capeek+|lelah|letih|exhausted|tidak semangat|gak semangat|ga semangat|nggak semangat|kurang semangat|malas|males|mager|lemes|lemas|lesu)\b', caseSensitive: false),
    Emotion.marah: RegExp(r'\b(marah|kesal|kesel|jengkel|emosi|benci|dongkol|sebel|sebal|frustasi|frustrasi|muak|geram|bete|bt)\b', caseSensitive: false),
    Emotion.kesepian: RegExp(r'\b(kesepian|sendirian|sepi|gak punya teman|ga punya temen|tidak punya teman|nggak ada yang peduli|gak ada yang peduli|tidak ada yang peduli|dikucilkan|diabaikan|dicuekin|gak dianggap|tidak dianggap|terasing)\b', caseSensitive: false),
    Emotion.tidur: RegExp(r'\b(susah tidur|sulit tidur|gak bisa tidur|ga bisa tidur|nggak bisa tidur|tidak bisa tidur|insomnia|begadang terus|mimpi buruk|kebangun terus)\b', caseSensitive: false),
    Emotion.senang: RegExp(r'\b(senang|seneng|bahagia|happy|lega|bersyukur|semangat banget|excited|gembira|bangga)\b', caseSensitive: false),
  };

  static final _self = RegExp(
      r'\b(aku|saya|gue|gw|gua|ku|aq|diriku|hatiku|perasaanku|lagi|sedang|merasa|ngerasa|rasanya|kerasa|perasaan|hati|hidupku|hari ini|akhir[- ]?akhir ini|belakangan|kok|kenapa aku|i feel|im|i am)\b',
      caseSensitive: false);
  static final _notAboutMe = RegExp(r'\b(lagu|film|resep|cerita|puisi|quote|kata[- ]?kata|caption|artikel|definisi|arti kata|apa itu|apa arti)\b', caseSensitive: false);

  /// "kenapa kucing saya takut air" → bukan tentang perasaan pengguna.
  static final _aboutOther = RegExp(r'\b(kucing|anjing|ikan|burung|hewan|tanaman|bayi|hp|motor|mobil|laptop|komputer|tokek|ayam)( (saya|aku|ku|gue|gw))?\b.*\b(takut|marah|sedih|stres|stress|lemes|lemas|cemas|gelisah)\b', caseSensitive: false);

  static const _priority = [Emotion.kesepian, Emotion.sedih, Emotion.cemas, Emotion.stres, Emotion.marah, Emotion.tidur, Emotion.lelah, Emotion.senang];

  static bool isCrisis(String text) => _crisis.hasMatch(text);

  /// null bila pesan bukan curhat tentang perasaan sendiri.
  static FeelingResult? detect(String text) {
    if (isCrisis(text)) return const FeelingResult(crisis: true, emotions: []);
    final found = [for (final e in _priority) if (_words[e]!.hasMatch(text)) e];
    if (found.isEmpty) return null;
    final words = text.trim().split(RegExp(r'\s+')).length;
    if (_notAboutMe.hasMatch(text) && !RegExp(r'\b(aku|saya|gue|gw)\b', caseSensitive: false).hasMatch(text)) return null;
    if (_aboutOther.hasMatch(text)) return null;
    if (words > 4 && !_self.hasMatch(text)) return null;
    return FeelingResult(crisis: false, emotions: found);
  }

  /// Minta tes psikologi? → 'phq9' | 'gad7' | 'who5' | 'menu'
  static String? testRequest(String text) {
    final t = text.toLowerCase();
    if (!RegExp(r'\b(tes|test|kuis|kuesioner|cek|periksa|skrining|screening|ukur)\b').hasMatch(t)) return null;
    if (RegExp(r'depresi|phq|suasana hati|mood').hasMatch(t)) return 'phq9';
    if (RegExp(r'cemas|kecemasan|anxiety|gad|khawatir|panik').hasMatch(t)) return 'gad7';
    if (RegExp(r'kesejahteraan|well[- ]?being|who[- ]?5|bahagia').hasMatch(t)) return 'who5';
    if (RegExp(r'burnout|burn out|kelelahan|capek kerja').hasMatch(t)) return 'burnout';
    if (RegExp(r'stres|stress|dass').hasMatch(t)) return 'dass21';
    if (RegExp(r'kesepian|sepi|ucla').hasMatch(t)) return 'ucla3';
    if (RegExp(r'percaya diri|harga diri|insecure|minder|self[- ]?esteem').hasMatch(t)) return 'rses';
    if (RegExp(r'tidur|insomnia').hasMatch(t)) return 'tidur';
    if (RegExp(r'trauma|ptsd').hasMatch(t)) return 'ptsd5';
    if (RegExp(r'psikolog|kesehatan mental|mental|jiwa|kepribadian|emosi').hasMatch(t)) return 'menu';
    return null;
  }
}

/// Jawaban "teman cerita" tanpa internet.
class SupportReply {
  const SupportReply(this.text, this.tools);
  final String text;
  final List<String> tools;

  static const crisisText =
      'Terima kasih sudah mau cerita — aku tahu itu tidak mudah. Yang kamu rasakan sekarang penting, dan kamu tidak harus menanggungnya sendirian. 💛\n\n'
      'Kalau kamu sedang berpikir untuk menyakiti diri atau mengakhiri hidup, tolong hubungi bantuan sekarang:\n'
      '• **Healing119** (Kemenkes, gratis 24 jam): telepon **119 lalu tekan 8**, atau chat lewat **healing119.id**\n'
      '• Kalau dalam bahaya saat ini: telepon **112** atau **119**\n'
      '• Hubungi orang yang kamu percaya — keluarga atau teman — dan minta mereka menemanimu.\n\n'
      'Aku di sini. Kalau mau, ceritakan apa yang terjadi, atau kita coba latihan napas pelan-pelan bareng.';

  static SupportReply crisis() => const SupportReply(crisisText, [Tool.telepon, Tool.healing, Tool.napas]);

  static final Map<Emotion, List<String>> _validate = {
    Emotion.sedih: [
      'Aku ikut sedih dengar itu. Wajar banget merasa begini — perasaan sedih itu tanda ada hal yang penting buatmu.',
      'Kedengarannya hatimu lagi berat sekali. Tidak apa-apa untuk merasa sedih, kamu tidak harus langsung baik-baik saja.',
      'Terima kasih sudah cerita. Sedih itu melelahkan, dan kamu sudah bertahan sejauh ini.',
    ],
    Emotion.cemas: [
      'Rasa cemas itu memang tidak enak — pikiran rasanya lari ke mana-mana. Kamu tidak sendirian merasakannya.',
      'Kedengarannya kepalamu lagi penuh kekhawatiran. Yuk pelan-pelan, satu per satu.',
      'Wajar merasa cemas saat banyak hal belum pasti. Tubuhmu sedang berusaha melindungimu.',
    ],
    Emotion.stres: [
      'Kedengarannya bebanmu lagi numpuk banget. Wajar kalau rasanya kewalahan.',
      'Banyak hal sekaligus memang bikin sesak. Kamu sudah berusaha keras, itu patut dihargai.',
      'Stres itu sinyal kalau kamu butuh jeda sebentar — bukan tanda kamu lemah.',
    ],
    Emotion.lelah: [
      'Capek itu nyata, dan istirahat bukan kemalasan. Badan dan pikiranmu butuh diisi ulang.',
      'Kedengarannya energimu lagi terkuras. Tidak apa-apa kalau hari ini cukup mengerjakan yang kecil-kecil dulu.',
      'Kamu sudah melakukan banyak hal. Boleh kok berhenti sebentar.',
    ],
    Emotion.marah: [
      'Wajar kalau kamu kesal — sepertinya ada yang terasa tidak adil atau tidak sesuai harapan.',
      'Marah itu emosi yang valid. Yang penting kita cari cara melepaskannya tanpa menyakiti diri atau orang lain.',
      'Kedengarannya situasinya bikin jengkel sekali. Tarik napas dulu, aku dengerin.',
    ],
    Emotion.kesepian: [
      'Merasa sendirian itu berat sekali. Aku senang kamu mau cerita di sini.',
      'Kesepian bisa bikin semuanya terasa lebih berat. Perasaanmu penting, dan kamu layak diperhatikan.',
      'Terima kasih sudah berbagi. Kamu tidak sendirian di percakapan ini.',
    ],
    Emotion.tidur: [
      'Susah tidur itu bikin hari berikutnya makin berat. Sering kali pikiran yang belum tenang ikut terbawa ke kasur.',
      'Kurang tidur memang menguras emosi dan tenaga. Yuk kita coba bantu tubuhmu lebih rileks.',
    ],
    Emotion.senang: [
      'Ikut senang dengarnya! 😊 Momen baik seperti ini layak dirayakan.',
      'Wah, kabar baik! Simpan rasa ini baik-baik ya.',
    ],
  };

  static final Map<Emotion, List<String>> _ask = {
    Emotion.sedih: ['Kalau kamu mau, ceritakan apa yang terjadi?', 'Apa yang paling bikin sedih hari ini?', 'Sudah berapa lama kamu merasa begini?'],
    Emotion.cemas: ['Hal apa yang paling kamu khawatirkan sekarang?', 'Kalau dipilah, bagian mana yang bisa kamu kendalikan?', 'Kekhawatiran ini muncul sejak kapan?'],
    Emotion.stres: ['Apa satu hal paling mendesak yang bisa kita urai dulu?', 'Dari semua beban itu, mana yang paling menyita pikiran?'],
    Emotion.lelah: ['Tidurmu cukup belakangan ini?', 'Apa yang paling menguras energimu akhir-akhir ini?'],
    Emotion.marah: ['Apa yang terjadi sampai bikin kamu sekesal ini?', 'Kalau boleh tahu, siapa atau apa yang bikin kamu marah?'],
    Emotion.kesepian: ['Adakah satu orang yang bisa kamu kabari hari ini, walau sekadar say hi?', 'Sejak kapan kamu merasa sendirian begini?'],
    Emotion.tidur: ['Biasanya apa yang ada di pikiranmu menjelang tidur?', 'Jam berapa biasanya kamu mulai pegang HP sebelum tidur?'],
    Emotion.senang: ['Apa yang bikin kamu senang hari ini?', 'Mau dicatat di jurnal syukur biar bisa dibaca lagi nanti?'],
  };

  static final Map<Emotion, List<String>> _tip = {
    Emotion.sedih: ['Coba lakukan satu hal kecil yang menenangkan: minum air hangat, mandi, atau jalan sebentar di luar.', 'Menulis perasaan di jurnal kadang bikin dada sedikit lebih lega.'],
    Emotion.cemas: ['Coba napas kotak: tarik 4 hitungan, tahan 4, hembuskan 4, tahan 4 — ulangi beberapa kali.', 'Grounding 5-4-3-2-1 bisa membawa pikiranmu kembali ke saat ini.'],
    Emotion.stres: ['Tulis semua yang ada di kepala, lalu pilih SATU yang dikerjakan 25 menit dulu. Sisanya boleh menunggu.', 'Jeda 5 menit untuk napas dalam bisa menurunkan ketegangan.'],
    Emotion.lelah: ['Kalau bisa, istirahat 15–20 menit atau tidur lebih awal malam ini.', 'Minum air, makan sesuatu yang bergizi, dan kurangi layar sebentar.'],
    Emotion.marah: ['Sebelum membalas siapa pun, beri jeda 10 menit dan tarik napas pelan.', 'Menulis semua uneg-uneg di jurnal (tanpa dikirim ke siapa-siapa) bisa membantu melepas emosi.'],
    Emotion.kesepian: ['Coba kirim pesan singkat ke teman atau keluarga — kadang satu obrolan kecil sudah membantu.', 'Kegiatan di luar rumah, walau sebentar, bisa mengurangi rasa terasing.'],
    Emotion.tidur: ['Coba jauhkan HP 30 menit sebelum tidur dan lakukan napas 4-7-8 di kasur.', 'Tuliskan isi pikiran di jurnal sebelum tidur supaya kepala lebih ringan.'],
    Emotion.senang: ['Tulis 3 hal yang kamu syukuri hari ini — bagus untuk kesehatan mental jangka panjang.'],
  };

  static const Map<Emotion, List<String>> _tools = {
    Emotion.sedih: [Tool.jurnal, Tool.napas, Tool.mood],
    Emotion.cemas: [Tool.napas, Tool.grounding, Tool.tes],
    Emotion.stres: [Tool.napas, Tool.fokus, Tool.jurnal],
    Emotion.lelah: [Tool.napas, Tool.mood, Tool.jurnal],
    Emotion.marah: [Tool.napas, Tool.jurnal],
    Emotion.kesepian: [Tool.jurnal, Tool.grounding, Tool.healing],
    Emotion.tidur: [Tool.napas, Tool.jurnal],
    Emotion.senang: [Tool.jurnal, Tool.mood],
  };

  static String _pick(List<String> l, Random r) => l[r.nextInt(l.length)];

  static SupportReply forFeeling(FeelingResult f, {String name = '', Random? rng}) {
    if (f.crisis) return crisis();
    final r = rng ?? Random();
    final e = f.main!;
    final hi = name.isEmpty ? '' : '$name, ';
    final v = _pick(_validate[e]!, r);
    final text = '${hi.isEmpty ? v : hi + v[0].toLowerCase() + v.substring(1)}\n\n💡 ${_pick(_tip[e]!, r)}\n\n${_pick(_ask[e]!, r)}'
        '${e == Emotion.senang ? '' : '\n\n*Kalau perasaan ini berlangsung lama atau mengganggu aktivitas, bicara dengan psikolog bisa sangat membantu (Healing119: 119 tekan 8).*'}';
    return SupportReply(text, _tools[e]!);
  }

  /// Balasan saat pengguna melanjutkan cerita tanpa kata emosi yang jelas.
  static SupportReply listening({Random? rng}) {
    final r = rng ?? Random();
    const a = [
      'Aku dengerin. Kedengarannya itu memang tidak mudah buatmu.',
      'Terima kasih sudah cerita lebih jauh. Perasaanmu masuk akal.',
      'Hmm, aku paham kenapa itu bikin kepikiran terus.',
      'Makasih sudah percaya cerita ke aku.',
    ];
    const b = [
      'Bagian mana yang paling berat buatmu sekarang?',
      'Menurutmu, apa satu hal kecil yang bisa bikin hari ini sedikit lebih ringan?',
      'Apa yang kamu butuhkan saat ini — didengarkan, atau dibantu cari jalan keluar?',
      'Kalau sahabatmu mengalami hal yang sama, apa yang akan kamu katakan padanya?',
    ];
    return SupportReply('${_pick(a, r)}\n\n${_pick(b, r)}', const [Tool.napas, Tool.jurnal]);
  }
}

/// Saran jadwal harian berdasarkan mood & energi (1–5).
class MoodAdvice {
  static const moodEmoji = ['😢', '😟', '😐', '🙂', '😄'];
  static const moodLabel = ['Sangat buruk', 'Kurang baik', 'Biasa saja', 'Baik', 'Sangat baik'];
  static const energyLabel = ['Habis', 'Rendah', 'Sedang', 'Cukup', 'Penuh'];

  static ({String title, List<String> tips, List<String> tools}) forDay(int mood, int energy, {int remindersToday = 0}) {
    final tips = <String>[];
    final tools = <String>[];
    String title;
    if (mood <= 2) {
      title = 'Hari ini pelan-pelan saja 💛';
      tips.addAll([
        'Pilih 1–3 tugas paling penting saja, sisanya boleh digeser.',
        'Selipkan satu kegiatan kecil yang kamu suka (musik, jalan kaki, teh hangat).',
        'Kalau berat, cerita ke orang yang kamu percaya atau ke Teman Cerita di asisten.',
      ]);
      tools.addAll([Tool.napas, Tool.jurnal]);
    } else if (energy >= 4) {
      title = 'Energimu bagus — manfaatkan! ⚡';
      tips.addAll([
        'Kerjakan tugas paling berat/penting di pagi hari ("makan katak dulu").',
        'Pakai blok fokus 50 menit + istirahat 10 menit.',
        'Sisakan waktu sore untuk tugas ringan & membalas pesan.',
      ]);
      tools.add(Tool.fokus);
    } else if (energy <= 2) {
      title = 'Energi rendah — hemat tenaga ya 🔋';
      tips.addAll([
        'Mulai dari tugas 5 menit supaya terasa ada kemajuan.',
        'Pakai blok fokus 25 menit + istirahat 5 menit (Pomodoro).',
        'Minum air, makan teratur, dan rencanakan tidur lebih awal.',
      ]);
      tools.addAll([Tool.fokus, Tool.napas]);
    } else {
      title = 'Hari yang seimbang 🌤️';
      tips.addAll([
        'Bagi hari jadi 3 blok: pagi (penting), siang (rutin), sore (ringan).',
        'Ambil jeda singkat tiap 1–1,5 jam untuk peregangan.',
      ]);
      tools.add(Tool.fokus);
    }
    if (remindersToday > 5) tips.add('Ada $remindersToday pengingat hari ini — cek mana yang bisa digabung atau ditunda.');
    return (title: title, tips: tips, tools: tools);
  }
}

