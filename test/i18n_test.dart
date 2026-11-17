import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ingetzeon/core/i18n/i18n.dart';
import 'package:ingetzeon/core/utils/date_utils.dart';
import 'package:ingetzeon/presentation/screens/calorie/weight_screen.dart';
import 'package:ingetzeon/presentation/screens/translate_screen.dart';
import 'package:ingetzeon/presentation/screens/welcome_screen.dart';
import 'package:ingetzeon/presentation/screens/workout/workout_screen.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';
import 'package:ingetzeon/providers/calorie_provider.dart';
import 'package:ingetzeon/providers/workout_provider.dart';
import 'package:ingetzeon/services/calorie_logic.dart';
import 'package:ingetzeon/services/translate_service.dart';
import 'package:ingetzeon/services/workout_logic.dart';

String _d(int n) => dayKey(DateTime.now().subtract(Duration(days: n)));

class _FakeCal extends CalorieNotifier {
  @override
  CalorieState build() => CalorieState(
        profile: const BodyProfile(kg: 76.4, cm: 165, age: 32, male: false, activity: 1.375, goal: 'turun', targetKg: 65),
        weights: [(day: _d(70), kg: 82.0), (day: _d(14), kg: 77.6), (day: _d(0), kg: 76.4)],
      );
}

class _FakeWorkout extends WorkoutNotifier {
  @override
  WorkoutState build() => const WorkoutState();
}

Widget _app(Widget home) => ProviderScope(
      overrides: [
        calorieProvider.overrideWith(_FakeCal.new),
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
  group('terjemahan tampilan', () {
    tearDown(() => I18n.setLang('id'));

    test('bahasa Indonesia tidak diubah', () {
      I18n.setLang('id');
      expect(tr('Simpan'), 'Simpan');
    });

    test('teks tetap, pola, dan per baris', () {
      I18n.setLang('en');
      expect(tr('Simpan'), 'Save');
      expect(tr('Hari ini'), 'Today');
      expect(tr('5 menit lagi'), 'in 5 minutes');
      expect(tr('2 jam 5 menit lagi'), 'in 2 h 5 min');
      expect(tr('Terlambat 3 hari'), '3 days late');
      expect(tr('Simpan\nHapus'), 'Save\nDelete');
      expect(tr('  Simpan '), '  Save ');
      expect(tr('Teks buatan pengguna 123'), 'Teks buatan pengguna 123');
      expect(fmtDateShort(DateTime(2026, 11, 17)), 'Tue, Nov 17');
    });

    test('deteksi bahasa untuk fitur Terjemah', () {
      expect(TranslateService.detect('aku mau beli baju yang ini'), 'id');
      expect(TranslateService.detect('where is the nearest station?'), 'en');
    });
  });

  group('tampilan bahasa Inggris tidak meluber', () {
    setUpAll(_loadRoboto);
    setUp(() {
      useGoogleFonts = false;
      I18n.setLang('en');
    });
    tearDown(() => I18n.setLang('id'));

    for (final w in [360.0, 412.0]) {
      testWidgets('berat & olahraga EN (lebar $w)', (t) async {
        await t.binding.setSurfaceSize(Size(w, 800));
        await t.pumpWidget(_app(const WeightScreen()));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('CURRENT WEIGHT'), findsOneWidget);
        await _scrollAll(t);
        await t.pumpWidget(_app(const Scaffold(body: SingleChildScrollView(child: WeightProgressCard()))));
        await t.pump(const Duration(milliseconds: 300));
        await t.pumpWidget(_app(const WorkoutScreen()));
        await t.pump(const Duration(milliseconds: 300));
        await _scrollAll(t);
        for (final id in ['pemula', 'hiit7', 'yoga']) {
          final p = programById(id);
          if (p == null) continue;
          await t.pumpWidget(_app(ProgramScreen(program: p)));
          await t.pump(const Duration(milliseconds: 200));
          await _scrollAll(t);
        }
        await t.pumpWidget(const SizedBox());
        await t.binding.setSurfaceSize(null);
      });
    }

    testWidgets('layar Terjemah (ID & EN)', (t) async {
      await t.runAsync(() async {
        Hive.init(Directory.systemTemp.createTempSync('hive').path);
        await Hive.openBox('settings');
      });
      for (final lang in ['id', 'en']) {
        I18n.setLang(lang);
        await t.binding.setSurfaceSize(const Size(360, 800));
        await t.pumpWidget(_app(const TranslateScreen()));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text(lang == 'en' ? 'Translate' : 'Terjemahkan'), findsWidgets);
        await t.enterText(find.byType(TextField), 'Selamat pagi');
        await t.pump();
        await _scrollAll(t);
        await t.pumpWidget(const SizedBox());
      }
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('layar sambutan isi nama (ID & EN, layar kecil)', (t) async {
      await t.runAsync(() async {
        if (!Hive.isBoxOpen('settings')) {
          Hive.init(Directory.systemTemp.createTempSync('hive2').path);
          await Hive.openBox('settings');
        }
      });
      for (final size in const [Size(360, 640), Size(412, 900)]) {
        for (final lang in ['id', 'en']) {
          I18n.setLang(lang);
          await t.binding.setSurfaceSize(size);
          await t.pumpWidget(_app(const WelcomeScreen()));
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text(lang == 'en' ? 'Welcome 👋' : 'Selamat datang 👋'), findsOneWidget);
          await t.enterText(find.byType(TextField), 'Vano');
          await t.pump();
          await t.pumpWidget(const SizedBox());
        }
      }
      await t.binding.setSurfaceSize(null);
    });
  });
}
