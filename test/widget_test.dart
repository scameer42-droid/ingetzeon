// Tes pemahaman bahasa alami (offline) dan logika jadwal.
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/core/utils/date_utils.dart';
import 'package:ingetzeon/data/models/reminder.dart';
import 'package:ingetzeon/services/memory_parser.dart';
import 'package:ingetzeon/services/natural_parser.dart';
import 'package:ingetzeon/services/cycle_parser.dart';
import 'package:ingetzeon/services/note_parser.dart';
import 'package:ingetzeon/services/speech_text.dart';
import 'package:ingetzeon/providers/cycle_provider.dart';
import 'package:ingetzeon/services/vocab.dart';

void main() {
  // Minggu, 15 November 2026, 11.20
  final now = DateTime(2026, 11, 15, 11, 20);
  ParsedReminder p(String s) => NaturalParser.parse(s, now: now);

  group('NaturalParser', () {
    test('besok jam 7 pagi', () {
      final r = p('ingatkan besok jam 7 pagi olahraga');
      expect(r.title, 'Olahraga');
      expect(toLocalIso(r.scheduledAt), '2026-11-16T07:00');
      expect(r.repeat, RepeatType.once);
      expect(r.category, ReminderCategory.kesehatan);
    });

    test('setiap hari jam 8 malam', () {
      final r = p('ingatkan minum obat setiap hari jam 8 malam');
      expect(r.title, 'Minum obat');
      expect(toLocalIso(r.scheduledAt), '2026-11-15T20:00');
      expect(r.repeat, RepeatType.daily);
    });

    test('tiap senin', () {
      final r = p('ingatkan rapat tiap senin jam 9');
      expect(r.title, 'Rapat');
      expect(toLocalIso(r.scheduledAt), '2026-11-16T09:00');
      expect(r.repeat, RepeatType.weekly);
      expect(r.category, ReminderCategory.kerja);
    });

    test('10 menit lagi', () {
      final r = p('ingatkan 10 menit lagi angkat jemuran');
      expect(r.title, 'Angkat jemuran');
      expect(toLocalIso(r.scheduledAt), '2026-11-15T11:30');
    });

    test('tanggal 20', () {
      final r = p('tolong ingetin aku bayar listrik tanggal 20');
      expect(r.title, 'Bayar listrik');
      expect(toLocalIso(r.scheduledAt), '2026-11-20T09:00');
    });

    test('lusa jam 14:30', () {
      final r = p('ingatkan meeting klien lusa jam 14:30');
      expect(r.title, 'Meeting klien');
      expect(toLocalIso(r.scheduledAt), '2026-11-17T14:30');
    });

    test('setengah 4 sore', () {
      final r = p('ingatkan jemput anak jam setengah 4 sore');
      expect(toLocalIso(r.scheduledAt), '2026-11-15T15:30');
    });

    test('setiap tanggal 5', () {
      final r = p('ingatkan arisan setiap tanggal 5 jam 4 sore');
      expect(r.repeat, RepeatType.monthly);
      expect(toLocalIso(r.scheduledAt), '2026-12-05T16:00');
    });

    test('tanpa jam → 09.00, sudah lewat → besok', () {
      final r = p('ingatkan aku cek stok');
      expect(r.title, 'Cek stok');
      expect(toLocalIso(r.scheduledAt), '2026-11-16T09:00');
    });

    test('tanggal & bulan', () {
      final r = p('ingatkan ulang tahun ibu 2 desember');
      expect(toLocalIso(r.scheduledAt), '2026-12-02T09:00');
      expect(r.category, ReminderCategory.pribadi);
    });
  });

  group('Kosakata', () {
    test('salah ketik & singkatan', () {
      expect(Vocab.classify('ingkatkan hari ini jam 07'), 'reminder');
      expect(Vocab.classify('jadwal hari ini shopefood jam 11'), 'reminder');
      expect(Vocab.classify('jadwal hari ini'), 'schedule');
      expect(Vocab.classify('jadwal besok apa?'), 'schedule');
      expect(Vocab.classify('apa kabar'), 'other');
      final a = p('tlg ingetin bsk jm 7 pgi olahraga');
      expect(a.title, 'Olahraga');
      expect(toLocalIso(a.scheduledAt), '2026-11-16T07:00');
      final b = p('jadwal hari ini shopefood jam 16');
      expect(b.title, 'Shopeefood');
      expect(toLocalIso(b.scheduledAt), '2026-11-15T16:00');
      expect(p('bangunin aku bsk jam 5').title, 'Bangun');
      expect(toLocalIso(p('rapat jam 8 kurang seperempat besok').scheduledAt), '2026-11-16T07:45');
      expect(toLocalIso(p('ingatkan jam tujuh malam makan obat').scheduledAt), '2026-11-15T19:00');
      expect(toLocalIso(p('3 hari lagi bayar cicilan').scheduledAt), '2026-11-18T09:00');
      expect(toLocalIso(p('akhir pekan cuci motor').scheduledAt), '2026-11-21T09:00');
      expect(toLocalIso(p('ingtakan tengah malam matikan kompor').scheduledAt), '2026-11-16T00:00');
      expect(Vocab.calc('250 x 12'), 3000);
      expect(Vocab.smallTalk('bantuan', greeting: 'Halo'), isNotNull);
    });
  });

  group('Parkir', () {
    test('catatan parkir tanpa jam → tanpa alarm', () {
      final r = p('saya parkir di b2 tolong ingatkan saya');
      expect(r.title, 'Parkir di B2');
      expect(r.category, ReminderCategory.parkir);
      expect(r.alarm, false);
      expect(toLocalIso(r.scheduledAt), '2026-11-15T11:20');
    });

    test('parkir dengan jam → alarm', () {
      final r = p('ingatkan jam 5 sore mobil parkir di lantai p3 pilar c5');
      expect(r.category, ReminderCategory.parkir);
      expect(r.alarm, true);
      expect(toLocalIso(r.scheduledAt), '2026-11-15T17:00');
      expect(r.title.contains('P3'), true);
    });
  });

  group('Ingat barang', () {
    test('kalimat penyimpanan', () {
      final cases = {
        'saya simpan kunci motor di laci meja': ['kunci motor', 'di laci meja'],
        'aku taruh tas kerja di atas lemari kamar ya': ['tas kerja', 'di atas lemari kamar'],
        'kacamata aku taro di samping tv': ['kacamata', 'di samping tv'],
        'paspor ada di dalam koper biru': ['paspor', 'di dalam koper biru'],
        'barusan nyimpen dompet di jok motor biar ga lupa': ['dompet', 'di jok motor'],
      };
      cases.forEach((input, want) {
        final r = MemoryParser.parseStore(input);
        expect(r, isNotNull, reason: input);
        expect(r!.item, want[0], reason: input);
        expect(r.place, want[1], reason: input);
      });
      expect(MemoryParser.parseStore('ingatkan besok jam 7 simpan baju di lemari'), isNull);
      expect(MemoryParser.parseStore('rapat ada di kantor'), isNull);
    });

    test('pertanyaan di mana', () {
      final items = [
        Reminder.create(title: 'Kunci motor di laci', scheduledAt: now, category: ReminderCategory.barang, alarm: false, item: 'kunci motor', place: 'di laci'),
        Reminder.create(title: 'Tas di lemari', scheduledAt: now, category: ReminderCategory.barang, alarm: false, item: 'tas kerja', place: 'di lemari'),
      ];
      expect(MemoryParser.isWhereQuestion('di mana kunci motor saya?'), true);
      expect(MemoryParser.findItems(items, 'di mana kunci motor saya?').first.item, 'kunci motor');
      expect(MemoryParser.findItems(items, 'tas kerjaku taruh di mana ya').first.item, 'tas kerja');
      expect(MemoryParser.findItems(items, 'di mana payung saya'), isEmpty);
    });
  });

  group('Reminder', () {
    test('kemunculan & jadwal berikutnya (harian)', () {
      final r = Reminder.create(title: 'Obat', scheduledAt: DateTime(2026, 11, 10, 20), repeat: RepeatType.daily);
      expect(r.occursOn(DateTime(2026, 11, 9)), false);
      expect(r.occursOn(DateTime(2026, 11, 15)), true);
      expect(r.nextOccurrence(now), DateTime(2026, 11, 15, 20));
      final done = r.withDone(DateTime(2026, 11, 15), true);
      expect(done.nextOccurrence(now), DateTime(2026, 11, 16, 20));
    });

    test('mingguan & bulanan', () {
      final w = Reminder.create(title: 'Rapat', scheduledAt: DateTime(2026, 11, 16, 9), repeat: RepeatType.weekly);
      expect(w.occursOn(DateTime(2026, 11, 23)), true);
      expect(w.occursOn(DateTime(2026, 11, 24)), false);
      final m = Reminder.create(title: 'Arisan', scheduledAt: DateTime(2026, 11, 5, 16), repeat: RepeatType.monthly);
      expect(m.nextOccurrence(now), DateTime(2026, 12, 5, 16));
    });

    test('simpan & baca ulang', () {
      final r = Reminder.create(title: 'Tes', note: 'catatan', scheduledAt: DateTime(2026, 11, 20, 8, 15), category: ReminderCategory.edukasi);
      final back = Reminder.fromMap(r.toMap());
      expect(back.title, 'Tes');
      expect(back.note, 'catatan');
      expect(back.scheduledAt, DateTime(2026, 11, 20, 8, 15));
      expect(back.category, ReminderCategory.edukasi);
      expect(back.notifId, r.notifId);
      expect(back.alarm, true);
      expect(back.photoPath, null);
    });
  });

  group('Pengingat haid', () {
    test('perkiraan dari riwayat', () {
      final c = CycleData(enabled: true, periods: [
        Period(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
        Period(DateTime(2026, 10, 20), DateTime(2026, 10, 24)),
      ]);
      final i = CycleInfo.from(c, DateTime(2026, 11, 15))!;
      expect(i.cycleLen, 28);
      expect(i.periodLen, 5);
      expect(i.next, DateTime(2026, 11, 17));
      expect(i.ovulation, DateTime(2026, 11, 3));
      expect(i.day, 27);
      expect(i.onPeriod, false);
      expect(i.markOn(DateTime(2026, 10, 22)), 'haid');
      expect(i.markOn(DateTime(2026, 11, 18)), 'haid-pred');
      expect(i.markOn(DateTime(2026, 12, 1)), 'subur');
      expect(i.status(DateTime(2026, 11, 15)).title, 'Haid 2 hari lagi');
      final back = CycleData.fromMap(c.toMap());
      expect(back.periods.length, 2);
      expect(back.periods.last.end, DateTime(2026, 10, 24));
    });

    test('perintah chat (banyak kosakata)', () {
      expect(CycleParser.parse('udh bersih hari ini', ongoing: true)!.cmd, CycleCmd.end);
      expect(CycleParser.parse('udh bersih hari ini'), null);
      expect(CycleParser.parse('kamar udah bersih', ongoing: true), null);
      expect(CycleParser.parse('haid aku mulai hari ini').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('lagi dapet nih').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('aku dapet mens kemarin').toString(), 'CycleIntent(CycleCmd.start, 1)');
      expect(CycleParser.parse('baru datang bulan tadi pagi').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('mens hari ke 3').toString(), 'CycleIntent(CycleCmd.start, 2)');
      expect(CycleParser.parse('haidku udah 3 hari').toString(), 'CycleIntent(CycleCmd.start, 2)');
      expect(CycleParser.parse('datang bulan 3 hari lalu').toString(), 'CycleIntent(CycleCmd.start, 3)');
      expect(CycleParser.parse('kemaren lusa aku mulai haid').toString(), 'CycleIntent(CycleCmd.start, 2)');
      expect(CycleParser.parse('lagi halangan').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('kedatangan tamu bulanan nih').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('aku lagi menstruasi').toString(), 'CycleIntent(CycleCmd.start, 0)');
      expect(CycleParser.parse('udah selesai haidnya').toString(), 'CycleIntent(CycleCmd.end, 0)');
      expect(CycleParser.parse('haid aku udah bersih kemarin').toString(), 'CycleIntent(CycleCmd.end, 1)');
      expect(CycleParser.parse('mens udahan').toString(), 'CycleIntent(CycleCmd.end, 0)');
      expect(CycleParser.parse('hari ini hari terakhir haid').toString(), 'CycleIntent(CycleCmd.end, 0)');
      expect(CycleParser.parse('udh gak keluar lagi haidnya').toString(), 'CycleIntent(CycleCmd.end, 0)');
      expect(CycleParser.parse('haid beres 2 hari lalu').toString(), 'CycleIntent(CycleCmd.end, 2)');
      expect(CycleParser.parse('kapan haid berikutnya?').toString(), 'CycleIntent(CycleCmd.askNext, 0)');
      expect(CycleParser.parse('kpn aku mens lagi').toString(), 'CycleIntent(CycleCmd.askNext, 0)');
      expect(CycleParser.parse('kapan saya haid').toString(), 'CycleIntent(CycleCmd.askNext, 0)');
      expect(CycleParser.parse('perkiraan datang bulan').toString(), 'CycleIntent(CycleCmd.askNext, 0)');
      expect(CycleParser.parse('haid').toString(), 'CycleIntent(CycleCmd.askNext, 0)');
      expect(CycleParser.parse('kapan haid saya selesai?').toString(), 'CycleIntent(CycleCmd.askEnd, 0)');
      expect(CycleParser.parse('haid aku selesai kapan').toString(), 'CycleIntent(CycleCmd.askEnd, 0)');
      expect(CycleParser.parse('berapa hari lagi haid selesai').toString(), 'CycleIntent(CycleCmd.askEnd, 0)');
      expect(CycleParser.parse('kapan bersih haidnya').toString(), 'CycleIntent(CycleCmd.askEnd, 0)');
      expect(CycleParser.parse('haid hari ke berapa?').toString(), 'CycleIntent(CycleCmd.askDay, 0)');
      expect(CycleParser.parse('udah berapa hari aku haid').toString(), 'CycleIntent(CycleCmd.askDay, 0)');
      expect(CycleParser.parse('masih haid ga?').toString(), 'CycleIntent(CycleCmd.askDay, 0)');
      expect(CycleParser.parse('kapan masa subur aku').toString(), 'CycleIntent(CycleCmd.askFertile, 0)');
      expect(CycleParser.parse('masa subur').toString(), 'CycleIntent(CycleCmd.askFertile, 0)');
      expect(CycleParser.parse('kapan ovulasi').toString(), 'CycleIntent(CycleCmd.askFertile, 0)');
      expect(CycleParser.parse('aku telat haid').toString(), 'CycleIntent(CycleCmd.askLate, 0)');
      expect(CycleParser.parse('kok belum haid ya?').toString(), 'CycleIntent(CycleCmd.askLate, 0)');
      expect(CycleParser.parse('apakah aku terlambat mens?').toString(), 'CycleIntent(CycleCmd.askLate, 0)');
      expect(CycleParser.parse('mens ku blm datang').toString(), 'CycleIntent(CycleCmd.askLate, 0)');
      expect(CycleParser.parse('ingatkan aku kalau mau haid').toString(), 'CycleIntent(CycleCmd.remindOn, 0)');
      expect(CycleParser.parse('ingetin kapan aku haid dan kapan selesai').toString(), 'CycleIntent(CycleCmd.remindOn, 0)');
      expect(CycleParser.parse('tolong ingatkan saya kapan haid').toString(), 'CycleIntent(CycleCmd.remindOn, 0)');
      expect(CycleParser.parse('jangan ingatkan haid lagi').toString(), 'CycleIntent(CycleCmd.remindOff, 0)');
      expect(CycleParser.parse('matikan pengingat haid').toString(), 'CycleIntent(CycleCmd.remindOff, 0)');
      expect(CycleParser.parse('ingatkan rapat besok jam 9'), null);
      expect(CycleParser.parse('tolong pupuk tanaman biar subur'), null);
      expect(CycleParser.parse('bayar pajak periode ini'), null);
      expect(CycleParser.parse('saya parkir di b2'), null);
    });
  });

  group('Suara', () {
    test('teks untuk dibacakan', () {
      expect(SpeechText.forTts('Siap! Aku ingatkan **Rapat** besok jam 09.00. ✅'), 'Siap! Aku ingatkan Rapat besok jam 9.');
      expect(SpeechText.forTts('Kunci motor kamu ada di laci 📍 (dicatat hari ini jam 17.18).'), 'Kunci motor kamu ada di laci, dicatat hari ini jam 17 lewat 18.');
      expect(SpeechText.forTts('Harga emas Rp 1.250.000 per gr, naik 2,5% dari kemarin.'), 'Harga emas 1250000 rupiah per gram, naik 2 koma 5 persen dari kemarin.');
      expect(SpeechText.forTts('Masa subur: Sab, 21 Nov – Jum, 27 Nov · siklus 28 hari.'), 'Masa subur: Sabtu, 21 November sampai Jumat, 27 November, siklus 28 hari.');
    });
    test('hasil dengar', () {
      expect(SpeechText.fromStt('saya parkir di be dua'), 'Saya parkir di B2');
      expect(SpeechText.fromStt('parkir di B 2 dekat lift'), 'Parkir di B2 dekat lift');
      expect(SpeechText.fromStt('parkir di lantai tiga'), 'Parkir di lantai 3');
      expect(SpeechText.fromStt('ingatkan jam 7:30 olahraga'), 'Ingatkan jam 7.30 olahraga');
    });
  });

  group('Catatan', () {
    test('simpan catatan', () {
      final a = NoteParser.parseStore('tolong catat saya punya emas 10 gr')!;
      expect(a.secret, false);
      expect(a.text, 'saya punya emas 10 gr');
      expect(NoteParser.parseStore('catet ya: utang budi 50rb')!.text, 'utang budi 50rb');
      final p = NoteParser.parseStore('catat password fb saya Abc#123')!;
      expect(p.secret, true);
      expect(p.label, 'password fb saya');
      expect(p.value, 'Abc#123');
      expect(NoteParser.parseStore('simpan password ig aku adalah Rahasia 99')!.value, 'Rahasia 99');
      expect(NoteParser.parseStore('password fb saya abc123')!.value, 'abc123');
      expect(NoteParser.parseStore('note: wifi kantor pass = kantor2026')!.value, 'kantor2026');
      expect(NoteParser.parseStore('tolong catet kalau pin hp aku 1234 ya')!.value, '1234');
      expect(NoteParser.parseStore('simpan kunci motor di laci'), null);
      expect(NoteParser.parseStore('ingatkan besok jam 7 olahraga'), null);
      expect(NoteParser.parseStore('catat rapat besok jam 9'), null);
      expect(NoteParser.parseStore('apa password fb saya?'), null);
    });

    test('tanya catatan', () {
      final notes = [
        _N('saya punya emas 10 gr', 'saya punya emas 10 gr', false, 1),
        _N('password fb saya', '', true, 2),
        _N('pin atm bca saya', '', true, 3),
        _N('nomor plat motor saya B 1234 XYZ', 'nomor plat motor saya B 1234 XYZ', false, 4),
      ];
      List<String> ask(String q) {
        final p = NoteParser.parseQuery(q)!;
        return NoteParser.match(notes, p.tokens, personal: p.personal).map((n) => n.label).toList();
      }
      expect(ask('apa password fb saya'), ['password fb saya']);
      expect(ask('pasword fesbuk aku apa?'), ['password fb saya']);
      expect(ask('berapa emas saya'), ['saya punya emas 10 gr']);
      expect(ask('emas saya berapa gram'), ['saya punya emas 10 gr']);
      expect(ask('aku lupa password ig'), isEmpty);
      expect(ask('apa pin atm saya'), ['pin atm bca saya']);
      expect(ask('plat motor saya apa'), ['nomor plat motor saya B 1234 XYZ']);
      expect(ask('berapa harga emas hari ini'), isEmpty);
      expect(NoteParser.parseQuery('lihat semua catatan')!.kind, NoteQueryKind.list);
      expect(NoteParser.parseQuery('hapus catatan emas')!.kind, NoteQueryKind.delete);
      expect(NoteParser.you('saya punya emas 10 gr'), 'kamu punya emas 10 gr');
    });
  });
}


class _N implements NoteLike {
  _N(this.label, this.value, this.secret, int t) : createdAt = DateTime(2026, 1, t);
  @override
  final String label;
  @override
  final String value;
  @override
  final bool secret;
  @override
  final DateTime createdAt;
}
