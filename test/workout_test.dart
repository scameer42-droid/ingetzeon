import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/services/workout_logic.dart';

void main() {
  group('Olahraga', () {
    test('program & kalori', () {
      final p = programById('perut_pemula')!;
      expect(Workout.steps(p).length, 16);
      expect((Workout.seconds(p) / 60).round(), 14);
      expect(Workout.kcal(p, 75).round(), 35);
      for (final pr in workoutPrograms) {
        expect(Workout.steps(pr), isNotEmpty);
      }
    });
    test('catat aktivitas dari chat', () {
      expect(Workout.parseActivity('tadi aku jogging 30 menit')?.name, 'Jogging');
      expect(Workout.parseActivity('main badminton 1,5 jam')?.minutes, 90);
      expect(Workout.parseActivity('aku gowes sejam')?.name, 'Bersepeda');
      expect(Workout.parseActivity('ingatkan lari jam 6'), isNull);
      expect(Workout.parseActivity('jalan-jalan ke mall'), isNull);
    });
    test('ajakan olahraga', () {
      expect(Workout.ask('olahraga buat mengecilkan perut'), 'perut_pemula');
      expect(Workout.ask('latihan kardio bakar lemak'), 'kardio');
      expect(Workout.ask('stretching sebelum tidur'), 'stretch_malam');
      expect(Workout.ask('mau olahraga'), 'hub');
      expect(Workout.ask('ingatkan makan'), isNull);
      expect(Workout.ask('olahraga kecilin pinggang'), 'pinggang');
      expect(Workout.ask('latihan perut tanpa rebahan'), 'perut_berdiri');
      expect(Workout.ask('workout 7 menit'), 'hiit7');
      expect(Workout.ask('olahraga tanpa lompat'), 'low_impact');
      expect(Workout.ask('senam untuk orang tua'), 'lansia');
      expect(Workout.ask('yoga pemula'), 'yoga');
      expect(Workout.ask('latihan bokong'), 'bokong');
      expect(Workout.ask('olahraga buat sakit pinggang'), 'punggung');
    });
    test('saran program', () {
      expect(Workout.recommend(kg: 70, cm: 170, age: 65, goal: 'jaga').first, 'lansia');
      expect(Workout.recommend(kg: 95, cm: 165, age: 30, goal: 'turun').take(2), ['low_impact', 'perut_berdiri']);
      expect(Workout.recommend(kg: 70, cm: 170, age: 30, goal: 'turun', weekMinutes: 120).first, 'hiit7');
      expect(Workout.recommend().length, lessThanOrEqualTo(4));
      for (final id in Workout.recommend(kg: 60, cm: 160, age: 25, goal: 'naik', hour: 21)) {
        expect(programById(id), isNotNull);
      }
      for (final p in workoutPrograms) {
        expect(programCategory[p.id], isNotNull, reason: p.id);
        expect(programFigure[p.id], isNotNull, reason: p.id);
      }
    });
  });
}
