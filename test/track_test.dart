import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/core/i18n/i18n.dart';
import 'package:ingetzeon/presentation/screens/track/track_detail_screen.dart';
import 'package:ingetzeon/presentation/screens/track/track_screen.dart';
import 'package:ingetzeon/presentation/screens/track/track_widgets.dart';
import 'package:ingetzeon/presentation/widgets/common.dart';
import 'package:ingetzeon/providers/track_provider.dart';
import 'package:ingetzeon/services/track_logic.dart';

/// Rute lurus ke utara: [secs] detik, [mps] meter per detik, ketinggian naik-turun.
List<TrackPoint> line(int secs, double mps, {DateTime? start}) {
  final t0 = start ?? DateTime(2026, 11, 19, 6);
  return [
    for (var i = 0; i <= secs; i++) TrackPoint(-6.2 + i * mps / 111194.93, 106.8, t0.add(Duration(seconds: i)), alt: 20 + 15 * math.sin(i / 120)),
  ];
}

Activity act(String id, double km, {ActivityType type = ActivityType.lari, double mps = 3, int daysAgo = 0}) {
  final secs = (km * 1000 / mps).round();
  final start = DateTime.now().subtract(Duration(days: daysAgo, hours: 1));
  return Activity(id: id, type: type, start: start, title: autoTitle(type, start), segments: [line(secs, mps, start: start)], elapsed: secs + 30, kcal: 300);
}

class _FakeTrack extends TrackNotifier {
  @override
  TrackState build() => TrackState(activities: [act('a', 5.3), act('b', 10.4, mps: 2.9, daysAgo: 3), act('c', 21.5, type: ActivityType.sepeda, mps: 7, daysAgo: 9)]);
}

Widget _app(Widget home) => ProviderScope(overrides: [trackProvider.overrideWith(_FakeTrack.new)], child: MaterialApp(home: home));

Future<void> _scrollAll(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    final s = find.byType(Scrollable);
    if (s.evaluate().isEmpty) break;
    await t.drag(s.first, const Offset(0, -500));
    await t.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() {
    useGoogleFonts = false;
    showMapTiles = false;
  });

  group('logika GPS', () {
    test('haversine ± benar', () {
      expect(haversine(-6.2, 106.8, -6.2 + 1000 / 111320, 106.8), closeTo(1000, 5));
    });
    test('jarak, waktu bergerak, split, pace', () {
      final st = TrackStats.compute([line(1200, 3)], ActivityType.lari);
      expect(st.distance, closeTo(3600, 20));
      expect(st.moving, closeTo(1200, 2));
      expect(st.splits.length, 4); // 3 km penuh + 600 m
      expect(st.splits.first.secs, closeTo(333, 3));
      expect(fmtPace(st.avgPace), '5:33');
      expect(st.elevGain, greaterThan(10));
    });
    test('jeda: segmen terpisah, diam tidak dihitung bergerak', () {
      final a = line(300, 3);
      final b = line(300, 3, start: a.last.t.add(const Duration(minutes: 10)));
      final st = TrackStats.compute([a, b], ActivityType.lari);
      expect(st.moving, closeTo(600, 2));
    });
    test('upaya terbaik', () {
      final st = TrackStats.compute([line(2000, 3)], ActivityType.lari);
      expect(st.bestEffort(1000), closeTo(333, 3));
      expect(st.bestEffort(5000), closeTo(1667, 5));
      expect(st.bestEffort(10000), isNull);
    });
    test('saringan membuang loncatan & titik tidak akurat', () {
      final f = PointFilter(ActivityType.lari);
      final t0 = DateTime(2026);
      expect(f.accept(TrackPoint(-6.2, 106.8, t0)), isTrue);
      expect(f.accept(TrackPoint(-6.2 + 500 / 111320, 106.8, t0.add(const Duration(seconds: 2)))), isFalse); // 250 m/s
      expect(f.accept(TrackPoint(-6.2 + 10 / 111320, 106.8, t0.add(const Duration(seconds: 3)), acc: 80)), isFalse);
      expect(f.accept(TrackPoint(-6.2 + 10 / 111320, 106.8, t0.add(const Duration(seconds: 3)))), isTrue);
    });
    test('GPX & kalori & judul', () {
      final g = toGpx(name: 'Lari <pagi>', type: ActivityType.lari, segments: [line(5, 3)]);
      expect(g, contains('<trkpt'));
      expect(g, contains('Lari &lt;pagi&gt;'));
      expect(activityKcal(ActivityType.lari, 5000, 1800, 60), closeTo(11.0 * 60 * .5, 1));
      expect(autoTitle(ActivityType.sepeda, DateTime(2026, 1, 1, 7)), 'Sepeda pagi');
    });
    test('format', () {
      expect(fmtDur(3725), '1:02:05');
      expect(fmtDur(605), '10:05');
      expect(fmtKm(5234), '5,23');
    });
  });

  group('layar rekam aktivitas', () {
    tearDown(() => I18n.setLang('id'));
    for (final size in const [Size(360, 800), Size(412, 900)]) {
      for (final lang in ['id', 'en']) {
        testWidgets('ringkasan & detail ${size.width.toInt()} $lang', (t) async {
          I18n.setLang(lang);
          await t.binding.setSurfaceSize(size);
          await t.pumpWidget(_app(const TrackScreen()));
          await t.pump(const Duration(milliseconds: 300));
          expect(find.byType(FeatureHero), findsOneWidget);
          await _scrollAll(t);
          expect(find.byType(ActivityCard), findsWidgets);
          await t.pumpWidget(_app(const TrackDetailScreen(id: 'b')));
          await t.pump(const Duration(milliseconds: 300));
          expect(find.textContaining('10,4'), findsWidgets);
          await _scrollAll(t);
          await t.pumpWidget(const SizedBox());
          await t.binding.setSurfaceSize(null);
        });
      }
    }
    testWidgets('kartu bagikan tampil', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      for (final style in CardStyle.values) {
        await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ShareCard(a: act('x', 7.2), style: style)))));
        await t.pump();
        expect(find.text('IngetZeon'), findsOneWidget);
        expect(find.text('Jarak'), findsOneWidget);
      }
      await t.binding.setSurfaceSize(null);
    });
  });
}
