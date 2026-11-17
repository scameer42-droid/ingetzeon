import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/core/utils/date_utils.dart';
import 'package:ingetzeon/presentation/screens/calorie/weight_screen.dart';
import 'package:ingetzeon/presentation/screens/workout/workout_screen.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';
import 'package:ingetzeon/providers/calorie_provider.dart';
import 'package:ingetzeon/providers/workout_provider.dart';
import 'package:ingetzeon/services/calorie_logic.dart';
import 'package:ingetzeon/services/workout_logic.dart';

String _d(int n) => dayKey(DateTime.now().subtract(Duration(days: n)));

class _FakeCal extends CalorieNotifier {
  @override
  CalorieState build() => CalorieState(
        profile: const BodyProfile(kg: 76.4, cm: 165, age: 32, male: false, activity: 1.375, goal: 'turun', targetKg: 65),
        weights: [(day: _d(70), kg: 82.0), (day: _d(42), kg: 79.9), (day: _d(14), kg: 77.6), (day: _d(0), kg: 76.4)],
      );
}

class _EmptyCal extends CalorieNotifier {
  @override
  CalorieState build() => const CalorieState();
}

class _FakeWorkout extends WorkoutNotifier {
  @override
  WorkoutState build() => const WorkoutState();
}

Widget _app(Widget home, {bool empty = false}) => ProviderScope(
      overrides: [
        calorieProvider.overrideWith(empty ? _EmptyCal.new : _FakeCal.new),
        workoutProvider.overrideWith(_FakeWorkout.new),
      ],
      child: MaterialApp(home: home),
    );

Future<void> _scrollAll(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    final s = find.byType(Scrollable);
    if (s.evaluate().isEmpty) break;
    await t.drag(s.first, const Offset(0, -500));
    await t.pump(const Duration(milliseconds: 120));
  }
}

/// Muat font Roboto asli dari SDK Flutter supaya ukuran teks di tes sama dengan di HP.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final f in dir.listSync().whereType<File>().where((f) => RegExp(r'Roboto-(Regular|Medium|Bold|Black)\.ttf$').hasMatch(f.path))) {
    loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);
  setUp(() => useGoogleFonts = false);

  for (final w in [360.0, 412.0]) {
    testWidgets('halaman berat badan (lebar $w)', (t) async {
      await t.binding.setSurfaceSize(Size(w, 800));
      await t.pumpWidget(_app(const WeightScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('BERAT SAAT INI'), findsOneWidget);
      expect(find.text('Berat awal'), findsWidgets);
      expect(find.textContaining('Turun 5,6 kg'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Riwayat penimbangan'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Riwayat penimbangan'), findsOneWidget);
      await _scrollAll(t);
      await t.tap(find.text('Catat berat hari ini'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Catat berat badan'), findsOneWidget);
      await t.tap(find.text('+1'));
      await t.pump();
      expect(find.text('77,4'), findsWidgets);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('kartu berat & hub olahraga (lebar $w)', (t) async {
      await t.binding.setSurfaceSize(Size(w, 800));
      await t.pumpWidget(_app(const Scaffold(body: SingleChildScrollView(child: WeightProgressCard()))));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('SAAT INI'), findsOneWidget);
      expect(find.text('AWAL'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      await t.pumpWidget(_app(const WorkoutScreen()));
      await t.pump(const Duration(milliseconds: 300));
      await _scrollAll(t);
      await t.pumpWidget(_app(const WorkoutScreen(), empty: true));
      await t.pump(const Duration(milliseconds: 300));
      await _scrollAll(t);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    });
  }

  testWidgets('semua program baru & detail gerakan tampil', (t) async {
    await t.binding.setSurfaceSize(const Size(380, 800));
    for (final id in ['lansia', 'hiit7', 'yoga', 'bokong', 'perut_berdiri']) {
      await t.pumpWidget(_app(ProgramScreen(program: programById(id)!)));
      await t.pump(const Duration(milliseconds: 200));
      await _scrollAll(t);
    }
    final list = exercises.where((e) => e.area == 'stretch').toList();
    await t.pumpWidget(_app(ExerciseDetailScreen(list: list, index: 0)));
    await t.pump(const Duration(milliseconds: 200));
    await _scrollAll(t);
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  });
}
