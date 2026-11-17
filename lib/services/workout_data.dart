// DIHASILKAN OTOMATIS oleh tool ola/data.py — jangan diedit manual.

class Exercise {
  const Exercise(this.id, this.name, this.emoji, this.area, this.timed, this.amount, this.met, this.level, this.steps, this.tip, this.mistake, this.caution);
  final String id, name, emoji, area, tip, mistake, caution;
  final bool timed; // true = detik, false = repetisi
  final int amount, level;
  final double met;
  final List<String> steps;
}

class WorkoutProgram {
  const WorkoutProgram(this.id, this.name, this.emoji, this.color, this.level, this.desc, this.rest, this.rounds, this.items);
  final String id, name, emoji, desc;
  final int color, level, rest, rounds;
  final List<(String, int)> items;
}

const exerciseAreas = <String, String>{'perut': 'Perut & core', 'kardio': 'Kardio', 'kaki': 'Kaki & bokong', 'lengan': 'Lengan, dada & punggung', 'stretch': 'Peregangan'};

const exercises = <Exercise>[
  Exercise('crunch', 'Crunch', '🙇', 'perut', false, 15, 3.8, 1, ['Berbaring telentang, lutut ditekuk, telapak kaki menapak lantai.', 'Letakkan ujung jari di samping telinga (jangan menarik kepala).', 'Angkat bahu dari lantai dengan mengencangkan perut, buang napas.', 'Tahan 1 detik, lalu turunkan perlahan sambil tarik napas.'], 'Bayangkan pusar ditarik ke arah tulang belakang.', 'Menarik leher dengan tangan dan mengangkat badan terlalu tinggi.', ''),
  Exercise('bicycle', 'Bicycle crunch', '🚴', 'perut', true, 30, 4, 2, ['Berbaring telentang, tangan di samping kepala, kaki diangkat 45°.', 'Tekuk lutut kanan ke dada sambil memutar badan, siku kiri menuju lutut kanan.', 'Ganti sisi: lutut kiri ke dada, siku kanan menuju lutut kiri.', 'Lakukan bergantian seperti mengayuh sepeda dengan tempo terkontrol.'], 'Pelan tapi terkontrol lebih efektif daripada cepat.', 'Punggung bawah terangkat dari lantai.', ''),
  Exercise('plank', 'Plank', '🧱', 'perut', true, 30, 3.8, 1, ['Tumpukan badan pada lengan bawah dan ujung kaki.', 'Siku tepat di bawah bahu.', 'Badan lurus dari kepala sampai tumit, kencangkan perut & bokong.', 'Tahan posisi sambil bernapas normal.'], 'Pandangan ke lantai sedikit di depan tangan agar leher netral.', 'Pinggul turun (melengkung) atau terlalu tinggi.', 'Hentikan bila punggung bawah terasa sakit.'),
  Exercise('side_plank', 'Side plank', '📐', 'perut', true, 20, 3.8, 2, ['Berbaring miring, tumpu pada satu lengan bawah, siku di bawah bahu.', 'Angkat pinggul hingga badan lurus dari kepala ke kaki.', 'Tahan, lalu ganti sisi pada set berikutnya.'], 'Pemula: tekuk lutut bawah untuk menopang.', 'Pinggul turun ke lantai.', ''),
  Exercise('leg_raise', 'Leg raise', '🦵', 'perut', false, 12, 3.8, 2, ['Berbaring telentang, tangan di samping badan atau di bawah bokong.', 'Luruskan kaki dan rapatkan.', 'Angkat kedua kaki hingga tegak lurus lantai.', 'Turunkan perlahan tanpa menyentuh lantai, lalu ulangi.'], 'Semakin pelan saat turun, semakin terasa di perut bawah.', 'Punggung bawah melengkung terangkat.', 'Tekuk sedikit lutut bila punggung bawah terasa tertarik.'),
  Exercise('mountain', 'Mountain climber', '⛰️', 'perut', true, 30, 8, 2, ['Mulai dari posisi push-up, tangan di bawah bahu.', 'Tarik lutut kanan ke arah dada.', 'Kembalikan, lalu tarik lutut kiri.', 'Lakukan bergantian dengan cepat seperti berlari di tempat.'], 'Jaga pinggul tetap sejajar dengan bahu.', 'Pinggul terlalu tinggi atau bokong naik turun.', ''),
  Exercise('russian', 'Russian twist', '🔄', 'perut', true, 30, 4, 2, ['Duduk, lutut ditekuk, condongkan badan ke belakang ±45°.', 'Rapatkan kedua tangan di depan dada.', 'Putar badan ke kanan lalu ke kiri, sentuhkan tangan ke lantai di samping pinggul.', 'Angkat kaki dari lantai untuk versi lebih berat.'], 'Putar dari badan, bukan hanya tangan.', 'Punggung membungkuk.', ''),
  Exercise('flutter', 'Flutter kick', '🏊', 'perut', true, 30, 3.8, 2, ['Berbaring telentang, tangan di bawah bokong.', 'Angkat kaki sekitar 15 cm dari lantai.', 'Gerakkan kaki naik-turun bergantian dengan cepat dan kecil.'], 'Tempelkan punggung bawah ke lantai.', 'Mengangkat kaki terlalu tinggi.', ''),
  Exercise('dead_bug', 'Dead bug', '🪲', 'perut', false, 12, 3, 1, ['Berbaring telentang, angkat tangan lurus ke atas dan lutut ditekuk 90°.', 'Luruskan tangan kanan ke belakang kepala dan kaki kiri ke depan bersamaan.', 'Kembali ke tengah, lalu ganti sisi.', 'Gerakan pelan dan terkontrol.'], 'Gerakan paling aman untuk perut pemula & punggung sensitif.', 'Punggung bawah terangkat dari lantai.', ''),
  Exercise('heel_touch', 'Heel touch', '👣', 'perut', true, 30, 3.5, 1, ['Berbaring telentang, lutut ditekuk, kaki agak lebar.', 'Angkat bahu sedikit dari lantai.', 'Raih tumit kanan dengan tangan kanan, lalu tumit kiri dengan tangan kiri.'], 'Bahu tetap terangkat selama gerakan.', 'Menarik leher.', ''),
  Exercise('reverse_crunch', 'Reverse crunch', '🔃', 'perut', false, 12, 3.8, 2, ['Berbaring telentang, lutut ditekuk 90° dan kaki diangkat.', 'Tarik lutut ke dada sambil mengangkat pinggul sedikit dari lantai.', 'Turunkan perlahan ke posisi awal.'], 'Gunakan perut, bukan ayunan kaki.', 'Mengayun kaki terlalu cepat.', ''),
  Exercise('plank_tap', 'Plank shoulder tap', '👋', 'perut', true, 30, 4.5, 2, ['Posisi high plank (tangan lurus).', 'Sentuh bahu kiri dengan tangan kanan.', 'Kembalikan, lalu sentuh bahu kanan dengan tangan kiri.'], 'Lebarkan kaki agar pinggul tidak bergoyang.', 'Pinggul berayun ke kiri-kanan.', ''),
  Exercise('vacuum', 'Stomach vacuum', '🫁', 'perut', true, 20, 1.5, 1, ['Berdiri tegak atau merangkak.', 'Buang napas sepenuhnya.', 'Tarik perut ke dalam sedalam mungkin seolah pusar menyentuh tulang belakang.', 'Tahan, lalu lepaskan dan bernapas normal.'], 'Melatih otot perut dalam (transversus) yang membuat perut tampak rata.', 'Menahan napas terlalu lama sampai pusing.', 'Jangan dilakukan saat hamil atau setelah makan.'),
  Exercise('jumping_jack', 'Jumping jack', '🤸', 'kardio', true, 30, 8, 1, ['Berdiri tegak, kaki rapat, tangan di samping badan.', 'Lompat sambil membuka kaki selebar bahu dan mengangkat tangan ke atas.', 'Lompat lagi kembali ke posisi awal.', 'Ulangi dengan ritme stabil.'], 'Mendarat dengan ujung kaki, lutut sedikit ditekuk.', 'Mendarat keras dengan tumit.', 'Versi tanpa lompat: langkahkan kaki ke samping bergantian.'),
  Exercise('high_knees', 'High knees', '🏃', 'kardio', true, 30, 8, 2, ['Berdiri tegak.', 'Lari di tempat sambil mengangkat lutut setinggi pinggul.', 'Ayunkan tangan seperti berlari.'], 'Badan tegak, perut dikencangkan.', 'Badan condong ke belakang.', ''),
  Exercise('butt_kick', 'Butt kick', '🦶', 'kardio', true, 30, 7, 1, ['Lari di tempat.', 'Tendang tumit ke arah bokong setiap langkah.', 'Tangan diayun santai.'], 'Mendarat ringan dengan ujung kaki.', 'Membungkuk ke depan.', ''),
  Exercise('burpee', 'Burpee', '💥', 'kardio', false, 8, 8, 3, ['Berdiri, lalu jongkok dan letakkan tangan di lantai.', 'Lompatkan kaki ke belakang ke posisi push-up.', 'Lompatkan kaki kembali ke dekat tangan.', 'Lompat ke atas sambil mengangkat tangan.'], 'Pemula: langkahkan kaki ke belakang tanpa lompat dan tanpa push-up.', 'Punggung melengkung saat posisi push-up.', 'Hentikan bila sesak berlebihan atau pusing.'),
  Exercise('skater', 'Skater jump', '⛸️', 'kardio', true, 30, 7, 2, ['Lompat ke samping kanan, mendarat dengan kaki kanan.', 'Kaki kiri menyilang ke belakang, tangan diayun.', 'Lompat ke kiri dan ulangi bergantian.'], 'Tekuk lutut saat mendarat.', 'Lutut lurus kaku saat mendarat.', ''),
  Exercise('march', 'Jalan di tempat', '🚶', 'kardio', true, 60, 3.5, 1, ['Berdiri tegak.', 'Angkat lutut bergantian seperti berjalan di tempat.', 'Ayunkan tangan berlawanan dengan kaki.'], 'Cocok untuk pemanasan atau pemula.', 'Membungkuk.', ''),
  Exercise('jump_rope', 'Lompat tali (tanpa tali)', '🪢', 'kardio', true, 30, 8.8, 1, ['Berdiri, tangan seolah memegang tali.', 'Putar pergelangan tangan sambil melompat kecil dengan ujung kaki.', 'Jaga lompatan rendah dan ringan.'], 'Lompatan kecil 2–3 cm sudah cukup.', 'Lompat terlalu tinggi.', ''),
  Exercise('squat', 'Squat', '🏋️', 'kaki', false, 15, 5, 1, ['Berdiri, kaki selebar bahu, ujung kaki sedikit ke luar.', 'Dorong pinggul ke belakang dan tekuk lutut seperti mau duduk.', 'Turun sampai paha sejajar lantai (atau semampunya).', 'Dorong lewat tumit untuk berdiri.'], 'Dada tegak, lutut searah ujung kaki.', 'Lutut masuk ke dalam atau tumit terangkat.', ''),
  Exercise('lunge', 'Lunge', '🚶‍♂️', 'kaki', false, 12, 4, 2, ['Berdiri tegak.', 'Langkahkan kaki kanan ke depan.', 'Turunkan badan hingga kedua lutut menekuk 90°.', 'Dorong kembali ke posisi awal, ganti kaki.'], 'Lutut depan tidak melewati ujung jari kaki.', 'Badan condong ke depan.', ''),
  Exercise('glute_bridge', 'Glute bridge', '🌉', 'kaki', false, 15, 3.5, 1, ['Berbaring telentang, lutut ditekuk, kaki menapak.', 'Angkat pinggul hingga badan lurus dari bahu ke lutut.', 'Remas bokong 1 detik di atas.', 'Turunkan perlahan.'], 'Dorong lewat tumit.', 'Punggung terlalu melengkung di atas.', ''),
  Exercise('wall_sit', 'Wall sit', '🪑', 'kaki', true, 30, 3, 2, ['Sandarkan punggung ke dinding.', 'Turunkan badan sampai lutut 90° seperti duduk di kursi.', 'Tahan posisi.'], 'Lutut tepat di atas pergelangan kaki.', 'Lutut melewati ujung kaki.', ''),
  Exercise('calf_raise', 'Calf raise', '🦿', 'kaki', false, 20, 2.8, 1, ['Berdiri tegak, bisa berpegangan ke dinding.', 'Jinjit setinggi mungkin.', 'Turunkan tumit perlahan.'], 'Tahan 1 detik di atas.', 'Terlalu cepat.', ''),
  Exercise('side_leg', 'Side leg raise', '🦵', 'kaki', false, 15, 3, 1, ['Berbaring miring, kepala ditopang tangan.', 'Angkat kaki atas lurus ke atas.', 'Turunkan perlahan, ganti sisi pada set berikutnya.'], 'Ujung kaki menghadap depan.', 'Badan berguling ke belakang.', ''),
  Exercise('donkey_kick', 'Donkey kick', '🐴', 'kaki', false, 15, 3.5, 1, ['Posisi merangkak, tangan di bawah bahu, lutut di bawah pinggul.', 'Tendang satu kaki ke atas dengan lutut tetap ditekuk 90°.', 'Turunkan, ulangi, lalu ganti kaki.'], 'Remas bokong saat kaki di atas.', 'Punggung melengkung.', ''),
  Exercise('pushup', 'Push-up', '💪', 'lengan', false, 10, 8, 2, ['Tangan sedikit lebih lebar dari bahu, badan lurus.', 'Turunkan dada mendekati lantai dengan siku ±45° dari badan.', 'Dorong kembali ke atas.'], 'Pemula: lakukan dengan lutut di lantai.', 'Pinggul turun atau siku terbuka lebar.', ''),
  Exercise('knee_pushup', 'Push-up lutut', '🙌', 'lengan', false, 10, 4, 1, ['Seperti push-up, tapi lutut bertumpu di lantai.', 'Badan lurus dari kepala ke lutut.', 'Turunkan dada, lalu dorong ke atas.'], 'Langkah awal sebelum push-up penuh.', 'Bokong terangkat.', ''),
  Exercise('tricep_dip', 'Tricep dip (kursi)', '🪑', 'lengan', false, 12, 4, 2, ['Duduk di tepi kursi yang kokoh, tangan di samping pinggul.', 'Geser bokong ke depan dari kursi.', 'Turunkan badan dengan menekuk siku ke belakang.', 'Dorong kembali ke atas.'], 'Siku mengarah ke belakang, bukan ke samping.', 'Bahu naik ke telinga.', 'Pastikan kursi tidak bisa bergeser.'),
  Exercise('arm_circle', 'Putar lengan', '🌀', 'lengan', true, 30, 2.8, 1, ['Berdiri, rentangkan tangan ke samping sejajar bahu.', 'Putar lengan membentuk lingkaran kecil ke depan.', 'Setelah setengah waktu, putar ke belakang.'], 'Lingkaran kecil terasa lebih berat.', 'Bahu terangkat.', ''),
  Exercise('superman', 'Superman', '🦸', 'lengan', false, 12, 3, 1, ['Berbaring tengkurap, tangan lurus ke depan.', 'Angkat tangan, dada, dan kaki bersamaan dari lantai.', 'Tahan 2 detik, lalu turunkan.'], 'Menguatkan punggung bawah — penyeimbang latihan perut.', 'Mendongakkan kepala terlalu tinggi.', ''),
  Exercise('inchworm', 'Inchworm', '🐛', 'lengan', false, 6, 4, 2, ['Berdiri, bungkukkan badan dan letakkan tangan di lantai.', 'Jalankan tangan ke depan sampai posisi push-up.', 'Jalankan tangan kembali ke kaki, lalu berdiri.'], 'Tekuk lutut bila hamstring kaku.', 'Punggung melengkung.', ''),
  Exercise('cobra', 'Cobra stretch', '🐍', 'stretch', true, 30, 2.3, 1, ['Berbaring tengkurap, tangan di bawah bahu.', 'Dorong dada ke atas perlahan, pinggul tetap di lantai.', 'Rasakan peregangan di perut, tahan.'], 'Bahu rileks menjauhi telinga.', 'Memaksa punggung melengkung terlalu jauh.', ''),
  Exercise('child_pose', 'Child’s pose', '🧘', 'stretch', true, 30, 2.3, 1, ['Berlutut, duduk di atas tumit.', 'Bungkukkan badan ke depan, tangan lurus di lantai.', 'Dahi menyentuh lantai, bernapas dalam.'], 'Napas panjang lewat hidung.', 'Menahan napas.', ''),
  Exercise('cat_cow', 'Cat-cow', '🐈', 'stretch', true, 40, 2.3, 1, ['Posisi merangkak.', 'Tarik napas: lengkungkan punggung ke bawah, angkat kepala (cow).', 'Buang napas: bulatkan punggung ke atas, tundukkan kepala (cat).', 'Ulangi mengikuti napas.'], 'Gerakan pelan mengikuti napas.', 'Terlalu cepat.', ''),
  Exercise('side_stretch', 'Peregangan samping', '🌿', 'stretch', true, 30, 2.3, 1, ['Berdiri, angkat tangan kanan ke atas.', 'Condongkan badan ke kiri, tahan.', 'Ganti sisi di setengah waktu.'], 'Pinggul tetap lurus.', 'Badan condong ke depan.', ''),
  Exercise('knee_hug', 'Peluk lutut', '🤗', 'stretch', true, 30, 2.3, 1, ['Berbaring telentang.', 'Peluk kedua lutut ke dada.', 'Goyangkan pelan ke kiri-kanan untuk memijat punggung bawah.'], 'Bagus untuk punggung setelah latihan perut.', 'Mengangkat kepala.', ''),
  Exercise('hamstring', 'Peregangan paha belakang', '🙆', 'stretch', true, 30, 2.3, 1, ['Duduk, luruskan kedua kaki.', 'Raih ujung kaki dengan punggung lurus.', 'Tahan tanpa menghentak.'], 'Tekuk lutut sedikit bila belum lentur.', 'Menghentak-hentakkan badan.', ''),
];

const workoutPrograms = <WorkoutProgram>[
  WorkoutProgram('perut_pemula', 'Perut rata — pemula', '🔥', 0xFFF97316, 1, 'Tanpa alat, gerakan ramah pemula. Mulai dari sini kalau baru mulai olahraga.', 20, 2, [('march', 60), ('crunch', 12), ('dead_bug', 10), ('heel_touch', 30), ('glute_bridge', 12), ('plank', 20), ('vacuum', 20), ('cobra', 30)]),
  WorkoutProgram('perut_menengah', 'Perut & core — menengah', '⚡', 0xFFEF4444, 2, 'Kombinasi kardio + perut untuk membakar lemak dan mengencangkan core.', 15, 3, [('jumping_jack', 40), ('bicycle', 40), ('mountain', 30), ('leg_raise', 12), ('russian', 30), ('plank', 40), ('side_plank', 25), ('flutter', 30)]),
  WorkoutProgram('perut_lanjut', 'Perut six-pack — lanjut', '🏆', 0xFF7C3AED, 3, 'Untuk yang sudah terbiasa. Intens dan melelahkan.', 10, 3, [('burpee', 10), ('mountain', 45), ('reverse_crunch', 15), ('bicycle', 45), ('plank_tap', 40), ('leg_raise', 15), ('russian', 45), ('plank', 60)]),
  WorkoutProgram('kardio', 'Kardio bakar lemak', '🏃', 0xFF0EA5E9, 2, 'HIIT tanpa alat — paling efektif membakar kalori dalam waktu singkat.', 15, 3, [('jumping_jack', 40), ('high_knees', 30), ('butt_kick', 30), ('skater', 30), ('jump_rope', 40), ('burpee', 8), ('mountain', 30)]),
  WorkoutProgram('fullbody', 'Full body tanpa alat', '💪', 0xFF10B981, 2, 'Melatih seluruh tubuh: kaki, dada, lengan, punggung dan perut.', 15, 2, [('jumping_jack', 30), ('squat', 15), ('pushup', 10), ('lunge', 12), ('superman', 12), ('glute_bridge', 15), ('plank', 30), ('mountain', 30), ('inchworm', 6)]),
  WorkoutProgram('kaki', 'Kaki & bokong', '🍑', 0xFFEC4899, 1, 'Mengencangkan paha dan bokong.', 15, 3, [('squat', 15), ('lunge', 12), ('glute_bridge', 15), ('donkey_kick', 15), ('side_leg', 15), ('wall_sit', 30), ('calf_raise', 20)]),
  WorkoutProgram('lengan', 'Lengan & dada', '🦾', 0xFF6366F1, 1, 'Mengencangkan lengan, dada dan punggung tanpa alat.', 20, 3, [('arm_circle', 30), ('knee_pushup', 10), ('tricep_dip', 12), ('superman', 12), ('pushup', 8), ('plank_tap', 30), ('inchworm', 6)]),
  WorkoutProgram('stretch_pagi', 'Peregangan pagi', '🌅', 0xFF14B8A6, 1, '5 menit untuk melemaskan badan setelah bangun tidur.', 5, 1, [('march', 60), ('side_stretch', 30), ('cat_cow', 40), ('cobra', 30), ('hamstring', 30), ('child_pose', 40)]),
  WorkoutProgram('stretch_malam', 'Peregangan sebelum tidur', '🌙', 0xFF8B5CF6, 1, 'Rileks, meredakan pegal dan membantu tidur lebih nyenyak.', 5, 1, [('knee_hug', 40), ('cat_cow', 40), ('child_pose', 45), ('hamstring', 40), ('cobra', 30)]),
];

/// Tantangan 4 minggu perut: (program, pengali durasi/repetisi) per minggu.
const bellyChallenge = <(String, double)>[('perut_pemula', 1.0), ('perut_pemula', 1.3), ('perut_menengah', 1.0), ('perut_menengah', 1.25)];

/// Aktivitas bebas untuk dicatat lewat chat: (kata kunci, nama, MET).
const freeActivities = <(List<String>, String, double)>[
  (['jalan kaki', 'jalan santai', 'jalan pagi', 'jalan sore', 'jalan'], 'Jalan kaki', 3.5),
  (['jalan cepat', 'power walk'], 'Jalan cepat', 4.3),
  (['jogging', 'joging', 'lari pagi', 'lari santai'], 'Jogging', 7),
  (['lari'], 'Lari', 9.8),
  (['bersepeda', 'sepedaan', 'gowes', 'sepeda'], 'Bersepeda', 6.8),
  (['renang', 'berenang'], 'Renang', 6),
  (['senam aerobik', 'aerobik', 'zumba', 'senam'], 'Senam', 6.5),
  (['yoga', 'pilates'], 'Yoga', 2.5),
  (['badminton', 'bulu tangkis', 'bulutangkis'], 'Badminton', 5.5),
  (['futsal', 'sepak bola', 'main bola'], 'Futsal/sepak bola', 7),
  (['basket'], 'Basket', 6.5),
  (['tenis meja', 'pingpong', 'ping pong'], 'Tenis meja', 4),
  (['angkat beban', 'gym', 'nge-gym', 'ngegym', 'fitness'], 'Angkat beban/gym', 5),
  (['skipping', 'lompat tali'], 'Lompat tali', 11),
  (['hiking', 'naik gunung', 'mendaki'], 'Hiking', 6),
  (['bersih bersih rumah', 'bersih-bersih', 'nyapu', 'ngepel'], 'Bersih-bersih rumah', 3.3),
];
