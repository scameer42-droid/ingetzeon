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
    });
  });
}
