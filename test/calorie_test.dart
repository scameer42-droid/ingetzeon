import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/services/calorie_logic.dart';

void main() {
  final siang = DateTime(2026, 11, 16, 12, 30);
  String show(FoodLog? l) => l == null ? 'null' : '${l.meal}: ${l.items.map((x) => '${x.food.name} x${fmtQty(x.qty)}').join(', ')}';

  group('Kalori', () {
    test('memahami kalimat makan', () {
      expect(show(FoodParse.parse('tadi pagi aku sarapan nasi uduk sama telur dadar dan teh manis', now: siang)), 'pagi: Nasi uduk x1, Telur dadar x1, Teh manis x1');
      expect(show(FoodParse.parse('aku makan nasi goreng 2 piring', now: siang)), 'siang: Nasi goreng x2');
      expect(show(FoodParse.parse('barusan makan sate ayam 5 tusuk + lontong', now: siang)), 'siang: Sate ayam x0,5, Lontong x1');
      expect(show(FoodParse.parse('malam ini makan mie ayam, es jeruk', now: siang)), 'malam: Mie ayam x1, Es jeruk x1');
      expect(show(FoodParse.parse('abis makan nasi 200 gram, ayam bakar, sambal', now: siang)), 'siang: Nasi putih x1,3, Ayam bakar x1, Sambal x1');
      expect(show(FoodParse.parse('tadi sore ngemil pisang goreng 2 buah', now: siang)), 'sore: Pisang goreng x2');
      expect(FoodParse.parse('aku mau makan apa ya', now: siang), isNull);
      expect(FoodParse.parse('ingatkan makan siang jam 12', now: siang), isNull);
    });

    test('pertanyaan & berat badan', () {
      expect(FoodParse.askCalorie('berapa kalori nasi goreng')!.name, 'Nasi goreng');
      expect(FoodParse.askToday('sisa kalori hari ini berapa'), isTrue);
      expect(FoodParse.weight('berat badan saya 68,5 kg'), 68.5);
      expect(FoodParse.weight('berat badan ideal saya berapa'), isNull);
    });

    test('target kalori aman', () {
      final t = Body.target(const BodyProfile(kg: 75, cm: 165, age: 30, male: false, activity: 1.375, goal: 'turun'));
      expect(t.target, 1520);
      expect(t.tdee, 2022);
      final low = Body.target(const BodyProfile(kg: 60, cm: 160, age: 40, male: false, activity: 1.2, goal: 'turun'));
      expect(low.target, 1200); // tidak di bawah batas aman
      final thin = Body.target(const BodyProfile(kg: 45, cm: 165, age: 25, male: false, activity: 1.2, goal: 'turun'));
      expect(thin.goal, 'jaga');
      final teen = Body.target(const BodyProfile(kg: 70, cm: 165, age: 16, male: true, activity: 1.55, goal: 'turun'));
      expect(teen.goal, 'jaga');
      expect(Body.bmiLabel(Body.bmi(75, 165)).$1, 'Obesitas');
      expect(Body.healthyRange(165), (50.4, 68.1));
    });

    test('produk Open Food Facts', () {
      final p = PackFood.fromOff({
        'product_name': 'Teh Botol',
        'brands': 'Sosro',
        'serving_quantity': 350,
        'nutriments': {'energy-kcal_100g': 37, 'carbohydrates_100g': 9}
      })!;
      expect(p.name, 'Teh Botol · Sosro');
      expect(p.toFood().kcal, closeTo(129.5, .1));
      expect(fmtKcal(1520), '1.520');
    });
  });
}
