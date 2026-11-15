// Tes pemahaman bahasa alami (offline) dan logika jadwal.
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/core/utils/date_utils.dart';
import 'package:ingetzeon/data/models/reminder.dart';
import 'package:ingetzeon/services/natural_parser.dart';

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
}
