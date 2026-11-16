import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';

void main() {
  testWidgets('lembar bawah bisa dibuka, digulir & ditutup', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppSheet(
                context: context,
                builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                  const SheetTitle('Semua fitur'),
                  for (var i = 0; i < 40; i++) ListTile(title: Text('Baris $i')),
                ]),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Semua fitur'), findsOneWidget);
    await tester.drag(find.text('Baris 3'), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Baris 39'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lembar bawah tanpa gulir (isi punya tinggi sendiri)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showAppSheet(
              context: context,
              scroll: false,
              builder: (c) => SizedBox(height: 300, child: ListView(children: const [Text('isi')])),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('isi'), findsOneWidget);
  });
}
