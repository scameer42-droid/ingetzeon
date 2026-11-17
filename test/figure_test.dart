import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/presentation/screens/workout/exercise_figure.dart';
import 'package:ingetzeon/services/workout_data.dart';

void main() {
  test('setiap gerakan punya animasi figur yang bisa digambar', () {
    for (final e in exercises) {
      final p = FigurePrep.of(e.id);
      expect(p, isNotNull, reason: e.id);
      expect(p!.s, greaterThan(0.3), reason: e.id);
      expect(e.muscles, isNotEmpty, reason: e.id);
      expect(e.breath, isNotEmpty, reason: e.id);
      for (final ph in [0.0, .13, .37, .5, .81, 1.0, 2.6]) {
        final rec = ui.PictureRecorder();
        FigurePainter(p, ph).paint(Canvas(rec), const Size(200, 150));
        rec.endRecording();
        final (pose, off) = p.at(ph);
        expect(pose.length, 14);
        expect(off.dx.isFinite && off.dy.isFinite, isTrue, reason: e.id);
      }
    }
  });

  testWidgets('ExerciseFigure beranimasi tanpa error', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 200, child: ExerciseFigure('burpee'))))));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(CustomPaint), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });
}
