import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/core/i18n/i18n.dart';
import 'package:ingetzeon/presentation/screens/vital_screen.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';
import 'package:ingetzeon/providers/vital_provider.dart';
import 'package:ingetzeon/services/vital_logic.dart';

class _FakeVital extends VitalNotifier {
  @override
  VitalState build() {
    final n = DateTime.now();
    return VitalState(
      diabetic: true,
      bp: [
        BpEntry(id: 'a', at: n.subtract(const Duration(days: 6)), sys: 118, dia: 76, pulse: 72),
        BpEntry(id: 'b', at: n.subtract(const Duration(days: 3)), sys: 136, dia: 86),
        BpEntry(id: 'c', at: n.subtract(const Duration(hours: 2)), sys: 152, dia: 88, pulse: 80),
      ],
      glu: [
        GluEntry(id: 'd', at: n.subtract(const Duration(days: 5)), kind: GluKind.puasa, value: 96),
        GluEntry(id: 'e', at: n.subtract(const Duration(days: 2)), kind: GluKind.puasa, value: 118),
        GluEntry(id: 'f', at: n.subtract(const Duration(hours: 1)), kind: GluKind.pp2, value: 210),
        GluEntry(id: 'g', at: n, kind: GluKind.hba1c, value: 6.1),
      ],
    );
  }

  @override
  Future<void> setDiabetic(bool v) async => state = state.copyWith(diabetic: v);
}

class _EmptyVital extends VitalNotifier {
  @override
  VitalState build() => const VitalState();
}

Widget _app(Widget home, {bool empty = false}) => ProviderScope(
      overrides: [vitalProvider.overrideWith(empty ? _EmptyVital.new : _FakeVital.new)],
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

void main() {
  setUp(() => useGoogleFonts = false);

  group('golongan tekanan darah (Kemenkes)', () {
    test('batas tiap golongan', () {
      expect(classifyBp(115, 75).key, 'optimal');
      expect(classifyBp(120, 79).key, 'normal');
      expect(classifyBp(125, 84).key, 'normal');
      expect(classifyBp(130, 70).key, 'normal_tinggi');
      expect(classifyBp(118, 85).key, 'normal_tinggi');
      expect(classifyBp(140, 80).key, 'h1');
      expect(classifyBp(120, 90).key, 'h1');
      expect(classifyBp(160, 95).key, 'h2');
      expect(classifyBp(150, 100).key, 'h2');
      expect(classifyBp(180, 90).key, 'h3');
      expect(classifyBp(170, 110).key, 'h3');
      expect(classifyBp(140, 89).key, 'h1');
      expect(isIsolatedSystolic(150, 85), isTrue);
      expect(isIsolatedSystolic(150, 95), isFalse);
    });
    test('rendah hanya bila tidak hipertensi', () {
      expect(classifyBp(85, 55).key, 'rendah');
      expect(classifyBp(150, 55).key, 'h1');
      expect(classifyBp(180, 120).urgent, isTrue);
    });
  });

  group('golongan gula darah (PNPK DM tipe 2)', () {
    test('puasa', () {
      expect(classifyGlu(GluKind.puasa, 99).key, 'normal');
      expect(classifyGlu(GluKind.puasa, 100).key, 'pre');
      expect(classifyGlu(GluKind.puasa, 125).key, 'pre');
      expect(classifyGlu(GluKind.puasa, 126).key, 'diabetes');
      expect(classifyGlu(GluKind.puasa, 65).key, 'hipo');
      expect(classifyGlu(GluKind.puasa, 50).key, 'hipo2');
    });
    test('2 jam, sewaktu, HbA1c', () {
      expect(classifyGlu(GluKind.pp2, 139).key, 'normal');
      expect(classifyGlu(GluKind.pp2, 140).key, 'pre');
      expect(classifyGlu(GluKind.pp2, 200).key, 'diabetes');
      expect(classifyGlu(GluKind.sewaktu, 199).key, 'normal');
      expect(classifyGlu(GluKind.sewaktu, 200).key, 'diabetes');
      expect(classifyGlu(GluKind.hba1c, 5.6).key, 'normal');
      expect(classifyGlu(GluKind.hba1c, 5.7).key, 'pre');
      expect(classifyGlu(GluKind.hba1c, 6.5).key, 'diabetes');
    });
    test('target penyandang diabetes', () {
      expect(diabetesTarget(GluKind.puasa, 120)!.status, 0);
      expect(diabetesTarget(GluKind.puasa, 140)!.status, 1);
      expect(diabetesTarget(GluKind.puasa, 75)!.status, -1);
      expect(diabetesTarget(GluKind.pp2, 175)!.status, 0);
      expect(diabetesTarget(GluKind.hba1c, 7.2)!.status, 1);
      expect(diabetesTarget(GluKind.sewaktu, 150), isNull);
    });
  });

  group('layar tensi & gula darah', () {
    tearDown(() => I18n.setLang('id'));
    for (final size in const [Size(360, 800), Size(412, 900)]) {
      for (final lang in ['id', 'en']) {
        testWidgets('tensi + gula, ${size.width.toInt()} $lang', (t) async {
          I18n.setLang(lang);
          await t.binding.setSurfaceSize(size);
          await t.pumpWidget(_app(const VitalScreen()));
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text('152/88'), findsWidgets);
          await _scrollAll(t);
          await t.pumpWidget(_app(const VitalScreen(glucose: true)));
          await t.pump(const Duration(milliseconds: 300));
          await _scrollAll(t);
          await t.pumpWidget(const SizedBox());
          await t.binding.setSurfaceSize(null);
        });
      }
    }
    testWidgets('kosong + lembar catat tensi', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      await t.pumpWidget(_app(const VitalScreen(), empty: true));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Belum ada catatan tensi.'), findsOneWidget);
      await t.tap(find.text('Catat tensi').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '145');
      await t.enterText(find.byType(TextField).at(1), '92');
      await t.pump();
      expect(find.text('Hipertensi derajat 1'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    });
  });
}
