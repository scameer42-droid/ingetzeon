import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/services/islam_logic.dart';
import 'package:ingetzeon/services/note_parser.dart';

void main() {
  group('Muslim Harian', () {
    test('jadwal sholat Jakarta (Kemenag) sesuai perhitungan', () {
      final t = PrayerCalc.times(DateTime(2026, 11, 16), -6.2088, 106.8456, 7);
      expect(PrayerCalc.hm(t['subuh']!), '04.05');
      expect(PrayerCalc.hm(t['dzuhur']!), '11.39');
      expect(PrayerCalc.hm(t['ashar']!), '15.01');
      expect(PrayerCalc.hm(t['maghrib']!), '17.51');
      expect(PrayerCalc.hm(t['isya']!), '19.05');
      expect(PrayerCalc.hm(t['imsak']!), '03.55');
    });

    test('arah kiblat & kota terdekat', () {
      expect(PrayerCalc.qibla(-6.2088, 106.8456), closeTo(295.2, .3));
      expect(PrayerCalc.nearestCity(-6.92, 107.6).name, 'Bandung');
    });

    test('kalender Hijriah', () {
      final h = Hijri.fromDate(DateTime(2026, 11, 16));
      expect(h.toString(), '5 Jumadil Akhir 1448 H');
      final back = Hijri.toDate(h.y, h.m, h.d);
      expect(back, DateTime(2026, 11, 16));
      final up = Hijri.upcoming(DateTime(2026, 11, 16), count: 3);
      expect(up.first.name, contains('Isra'));
    });

    test('pertanyaan di chat', () {
      expect(IslamAsk.prayer('jam berapa maghrib hari ini?'), 'maghrib');
      expect(IslamAsk.prayer('arah kiblat dimana'), 'kiblat');
      expect(IslamAsk.prayer('jadwal sholat hari ini'), 'jadwal');
      expect(IslamAsk.prayer('tanggal hijriah sekarang'), 'hijri');
      expect(IslamAsk.prayer('ingatkan beli asam jawa'), isNull);
      expect(IslamAsk.doa('doa sebelum tidur apa ya')!.judul, 'Sebelum tidur');
      expect(IslamAsk.doa('ingatkan aku tidur jam 10'), isNull);
    });
  });

  group('Catatan rahasia', () {
    test('nomor rekening otomatis jadi rahasia', () {
      final d = NoteParser.parseStore('tolong catat nomor rekening BCA 9015 4630 1700')!;
      expect(d.secret, isTrue);
      expect(d.label, 'nomor rekening BCA');
      expect(d.value, '9015 4630 1700');
    });
    test('kata biasa tidak jadi rahasia', () {
      expect(NoteParser.parseStore('catat saya pinjam uang 50000 ke budi')!.secret, isFalse);
      expect(NoteParser.parseStore('catat rekening utama saya di BCA')!.secret, isFalse);
      expect(NoteParser.parseStore('catat password fb itu kucing123')!.value, 'kucing123');
    });
  });
}
