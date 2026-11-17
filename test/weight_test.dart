import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/presentation/screens/calorie/weight_screen.dart';
import 'package:ingetzeon/providers/calorie_provider.dart';
import 'package:ingetzeon/services/calorie_logic.dart';

void main() {
  test('berat awal, sekarang & progres menuju target', () {
    const p = BodyProfile(kg: 76, cm: 165, age: 30, male: false, activity: 1.375, goal: 'turun', targetKg: 66);
    const s = CalorieState(profile: p, weights: [(day: '2026-10-01', kg: 80.0), (day: '2026-10-15', kg: 78.4), (day: '2026-11-01', kg: 76.0)]);
    final st = WeightStats.of(s)!;
    expect(st.start.kg, 80);
    expect(st.current.kg, 76);
    expect(st.change, -4);
    expect(st.good, isTrue);
    expect(st.progress, closeTo(.2857, .001));
    expect(st.remaining, 10);
    expect(st.perWeek, closeTo(-0.903, .01));
    expect(st.changeText, contains('Turun 4 kg'));
    expect(st.reached, isFalse);
  });
  test('tanpa catatan & target tercapai', () {
    const p = BodyProfile(kg: 60, cm: 160, age: 30, male: true, activity: 1.2, goal: 'turun', targetKg: 62);
    const s = CalorieState(profile: p, weights: [(day: '2026-09-01', kg: 70.0), (day: '2026-11-10', kg: 60.0)]);
    final st = WeightStats.of(s)!;
    expect(st.reached, isTrue);
    expect(st.progress, 1);
    expect(st.remaining, 0);
    expect(WeightStats.of(const CalorieState()), isNull);
  });
}
