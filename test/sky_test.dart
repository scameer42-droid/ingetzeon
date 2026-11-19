import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';

void main() {
  setUp(() => useGoogleFonts = false);

  test('fase langit mengikuti jam', () {
    expect(SkyPhase.of(DateTime(2026, 1, 1, 6)), SkyPhase.pagi);
    expect(SkyPhase.of(DateTime(2026, 1, 1, 12)), SkyPhase.siang);
    expect(SkyPhase.of(DateTime(2026, 1, 1, 16)), SkyPhase.sore);
    expect(SkyPhase.of(DateTime(2026, 1, 1, 20)), SkyPhase.malam);
    expect(SkyPhase.of(DateTime(2026, 1, 1, 2)), SkyPhase.malam);
  });

  for (final w in [360.0, 412.0]) {
    for (final ph in SkyPhase.values) {
      testWidgets('langit $ph (lebar $w) tampil tanpa error', (t) async {
        await t.binding.setSurfaceSize(Size(w, 800));
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListView(padding: EdgeInsets.zero, children: [
              SkyHeader(
                phase: ph,
                child: const Text('Selamat Malam, Muhammad Fathir Rizki Rivano', maxLines: 2, style: TextStyle(fontSize: 24)),
              ),
              const Row(children: [
                Expanded(child: CircleIcon(icon: Icons.notifications_none_rounded, color: FeatureColors.reminder)),
                Expanded(child: CircleIcon(icon: Icons.local_parking_rounded, color: FeatureColors.parking)),
                Expanded(child: CircleIcon(icon: Icons.mosque_outlined, color: FeatureColors.muslim)),
                Expanded(child: CircleIcon(icon: Icons.directions_run_rounded, color: FeatureColors.workout)),
              ]),
              const MeshCard(color: FeatureColors.calm, child: SizedBox(height: 120)),
            ]),
          ),
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.byType(SkyHeader), findsOneWidget);
      });
    }
  }
}
