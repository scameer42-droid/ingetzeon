/// Materi Belajar Inggris: 10 topik sehari-hari, masing-masing 10 kata & 4 kalimat.
/// Isinya sama dengan versi website.
library;

import 'package:flutter/material.dart';

class EngTopic {
  const EngTopic(this.id, this.title, this.emoji, this.color, this.words, this.sentences);
  final String id, title, emoji;
  final Color color;
  /// (Inggris, Indonesia)
  final List<(String, String)> words;
  final List<(String, String)> sentences;
}

const engGoal = 30;

const engTopics = <EngTopic>[
  EngTopic('sapaan', 'Sapaan', '👋', Color(0xFF5B5CE2), [
    ('hello', 'halo'), ('good morning', 'selamat pagi'), ('good night', 'selamat malam'), ('thank you', 'terima kasih'), ('please', 'tolong'), ('sorry', 'maaf'), ('yes', 'ya'), ('no', 'tidak'), ('goodbye', 'selamat tinggal'), ('welcome', 'selamat datang'),
  ], [
    ('Good morning, how are you?', 'Selamat pagi, apa kabar?'), ('Nice to meet you', 'Senang bertemu denganmu'), ('Thank you very much', 'Terima kasih banyak'), ('See you tomorrow', 'Sampai jumpa besok'),
  ]),
  EngTopic('angka', 'Angka & waktu', '🔢', Color(0xFF0E9384), [
    ('one', 'satu'), ('two', 'dua'), ('three', 'tiga'), ('ten', 'sepuluh'), ('twenty', 'dua puluh'), ('hundred', 'seratus'), ('today', 'hari ini'), ('tomorrow', 'besok'), ('yesterday', 'kemarin'), ('minute', 'menit'),
  ], [
    ('What time is it?', 'Jam berapa sekarang?'), ('It is seven o\'clock', 'Sekarang jam tujuh'), ('I wake up at six', 'Saya bangun jam enam'), ('The meeting is tomorrow', 'Rapatnya besok'),
  ]),
  EngTopic('harian', 'Kegiatan harian', '☀️', Color(0xFFDC6803), [
    ('wake up', 'bangun'), ('eat', 'makan'), ('drink', 'minum'), ('sleep', 'tidur'), ('work', 'bekerja'), ('study', 'belajar'), ('cook', 'memasak'), ('take a shower', 'mandi'), ('walk', 'berjalan'), ('read', 'membaca'),
  ], [
    ('I drink water every morning', 'Saya minum air setiap pagi'), ('She is cooking dinner', 'Dia sedang memasak makan malam'), ('We study English together', 'Kami belajar bahasa Inggris bersama'), ('Do not forget to sleep early', 'Jangan lupa tidur lebih awal'),
  ]),
  EngTopic('makanan', 'Makanan', '🍜', Color(0xFFE31B54), [
    ('rice', 'nasi'), ('water', 'air'), ('coffee', 'kopi'), ('tea', 'teh'), ('egg', 'telur'), ('chicken', 'ayam'), ('fish', 'ikan'), ('fruit', 'buah'), ('bread', 'roti'), ('sugar', 'gula'),
  ], [
    ('I want fried rice', 'Saya mau nasi goreng'), ('The coffee is too hot', 'Kopinya terlalu panas'), ('This food is delicious', 'Makanan ini enak'), ('Can I have some water?', 'Boleh saya minta air?'),
  ]),
  EngTopic('keluarga', 'Keluarga', '👨‍👩‍👧', Color(0xFF7A5AF8), [
    ('mother', 'ibu'), ('father', 'ayah'), ('brother', 'saudara laki-laki'), ('sister', 'saudara perempuan'), ('child', 'anak'), ('friend', 'teman'), ('husband', 'suami'), ('wife', 'istri'), ('family', 'keluarga'), ('neighbor', 'tetangga'),
  ], [
    ('This is my mother', 'Ini ibu saya'), ('My friend lives nearby', 'Teman saya tinggal di dekat sini'), ('I love my family', 'Saya sayang keluarga saya'), ('Her brother is a doctor', 'Saudara laki-lakinya seorang dokter'),
  ]),
  EngTopic('kantor', 'Di kantor', '💼', Color(0xFF1570EF), [
    ('meeting', 'rapat'), ('office', 'kantor'), ('boss', 'atasan'), ('employee', 'karyawan'), ('schedule', 'jadwal'), ('deadline', 'tenggat waktu'), ('report', 'laporan'), ('salary', 'gaji'), ('break', 'istirahat'), ('task', 'tugas'),
  ], [
    ('The meeting starts at nine', 'Rapatnya mulai jam sembilan'), ('Please send the report today', 'Tolong kirim laporannya hari ini'), ('I have a deadline tomorrow', 'Saya punya tenggat waktu besok'), ('Let us take a short break', 'Ayo istirahat sebentar'),
  ]),
  EngTopic('belanja', 'Belanja', '🛍️', Color(0xFFDD2590), [
    ('price', 'harga'), ('cheap', 'murah'), ('expensive', 'mahal'), ('buy', 'membeli'), ('sell', 'menjual'), ('money', 'uang'), ('discount', 'diskon'), ('size', 'ukuran'), ('store', 'toko'), ('cash', 'tunai'),
  ], [
    ('How much is this?', 'Berapa harganya?'), ('Do you have a smaller size?', 'Ada ukuran yang lebih kecil?'), ('I will pay in cash', 'Saya akan bayar tunai'), ('This shirt is too expensive', 'Kemeja ini terlalu mahal'),
  ]),
  EngTopic('jalan', 'Perjalanan', '🧭', Color(0xFF0BA5EC), [
    ('left', 'kiri'), ('right', 'kanan'), ('straight', 'lurus'), ('near', 'dekat'), ('far', 'jauh'), ('ticket', 'tiket'), ('station', 'stasiun'), ('airport', 'bandara'), ('street', 'jalan'), ('map', 'peta'),
  ], [
    ('Where is the station?', 'Di mana stasiunnya?'), ('Turn left at the corner', 'Belok kiri di tikungan'), ('Is it far from here?', 'Apakah jauh dari sini?'), ('I parked on the second floor', 'Saya parkir di lantai dua'),
  ]),
  EngTopic('perasaan', 'Perasaan', '😊', Color(0xFF16856B), [
    ('happy', 'senang'), ('sad', 'sedih'), ('tired', 'lelah'), ('angry', 'marah'), ('hungry', 'lapar'), ('sleepy', 'mengantuk'), ('bored', 'bosan'), ('excited', 'bersemangat'), ('worried', 'khawatir'), ('calm', 'tenang'),
  ], [
    ('I am very tired today', 'Saya sangat lelah hari ini'), ('Do not worry, everything is fine', 'Jangan khawatir, semuanya baik-baik saja'), ('Are you hungry?', 'Apakah kamu lapar?'), ('She feels happy', 'Dia merasa senang'),
  ]),
  EngTopic('rumah', 'Di rumah', '🏠', Color(0xFFB76A09), [
    ('house', 'rumah'), ('room', 'kamar'), ('kitchen', 'dapur'), ('door', 'pintu'), ('window', 'jendela'), ('table', 'meja'), ('chair', 'kursi'), ('bed', 'tempat tidur'), ('key', 'kunci'), ('bag', 'tas'),
  ], [
    ('The key is on the table', 'Kuncinya ada di atas meja'), ('Please close the door', 'Tolong tutup pintunya'), ('My bag is in the bedroom', 'Tas saya ada di kamar tidur'), ('Where did I put my keys?', 'Di mana saya menaruh kunci saya?'),
  ]),
];
