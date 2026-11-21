import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_detail_screen.dart';
import 'track_record_screen.dart';
import 'track_widgets.dart';

void openTrack(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackScreen()));
void openRecord(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackRecordScreen()));

/// Halaman "Kamu" gaya Strava: filter jenis, minggu ini + grafik 12 minggu, kalender latihan,
/// rekor pribadi, statistik tahun ini & sepanjang masa, dan feed aktivitas. Tombol Rekam oranye.
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});
  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  ActivityType? _f; // null = semua

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(trackProvider);
    final rec = ref.watch(recorderProvider);
    final now = DateTime.now();
    final ws = TrackState.weekStart(now);
    final week = s.between(ws, ws.add(const Duration(days: 7)), _f);
    final km = week.fold(0.0, (a, x) => a + x.distance) / 1000;
    final secs = week.fold(0, (a, x) => a + x.moving);
    final elev = week.fold(0.0, (a, x) => a + x.stats.elevGain);
    final list = s.of(_f);
    final prType = _f ?? ActivityType.lari;
    final prs = [
      for (final (m, label) in bestDistances)
        if (s.ranking(prType, m).firstOrNull case final r?) (label: label, m: m, secs: r.secs, a: r.activity),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Rekam Aktivitas'), centerTitle: false, actions: [
        IconButton(tooltip: tr('Pengaturan'), icon: const Icon(Icons.tune_rounded), onPressed: () => showTrackSettings(context)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kTrack,
        foregroundColor: Colors.white,
        onPressed: () => openRecord(context),
        icon: Icon(rec.active ? Icons.radio_button_checked_rounded : Icons.fiber_manual_record_rounded),
        label: Text(rec.active ? 'Buka rekaman' : 'Rekam', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 4, 0, 100), children: [
        if (rec.active)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Material(
              color: kTrack.withValues(alpha: context.isDark ? .2 : .1),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => openRecord(context),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(rec.status == RecStatus.paused ? Icons.pause_circle_filled_rounded : Icons.fiber_manual_record_rounded, color: kTrack),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(rec.status == RecStatus.paused ? 'Rekaman dijeda — ketuk untuk melanjutkan' : 'Sedang merekam — ketuk untuk membuka',
                          style: TextStyle(fontWeight: FontWeight.w600, color: context.ink)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kTrack),
                  ]),
                ),
              ),
            ),
          ),
        // filter jenis
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            for (final t in [null, ...ActivityType.values])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t == null ? tr('Semua') : '${t.emoji} ${tr(t.label)}', translate: false),
                  selected: _f == t,
                  showCheckmark: false,
                  selectedColor: kTrack,
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _f == t ? Colors.white : context.ink),
                  side: BorderSide(color: _f == t ? kTrack : context.line),
                  onSelected: (_) => setState(() => _f = t),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // minggu ini
            _Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Minggu ini', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(km * 1000, 1), unit: 'km')),
                  Expanded(child: StatBox(label: tr('Waktu'), value: fmtDur(secs))),
                  Expanded(child: StatBox(label: tr('Elevasi'), value: '${elev.round()}', unit: 'm')),
                ]),
                const SizedBox(height: 14),
                SizedBox(height: 130, child: _WeeksChart(s, _f)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: (km / s.weeklyGoalKm).clamp(0, 1).toDouble(), minHeight: 8, color: kTrack, backgroundColor: kTrack.withValues(alpha: .15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${fmtKm(km * 1000, 1)} / ${s.weeklyGoalKm} km', translate: false, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.muted)),
                ]),
              ]),
            ),
            if (s.activities.isEmpty) ...[
              const SizedBox(height: 20),
              const EmptyState(
                title: 'Belum ada aktivitas.',
                subtitle: 'Tekan tombol Rekam, pilih lari, jalan, sepeda, atau hiking, lalu IngetZeon mencatat rute, jarak, pace, dan elevasimu dengan GPS.',
                icon: Icons.directions_run_rounded,
              ),
            ] else ...[
              const SectionHeader('Kalender latihan'),
              _Card(child: _Calendar(s, _f)),
              SectionHeader('${tr('Rekor pribadi')} · ${tr(prType.label)}'),
              if (prs.isEmpty)
                Text('Rekor 1 km, 5 km, 10 km, dan half marathon muncul otomatis setelah kamu menempuh jarak itu.', style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4))
              else
                ListGroup(children: [
                  for (final p in prs)
                    InkWell(
                      onTap: () => openActivity(context, p.a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          const SizedBox(width: 34, child: Text('🥇', translate: false, style: TextStyle(fontSize: 22))),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(p.label), translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
                              Text('${fmtPace(p.secs / (p.m / 1000))} /km · ${fmtDateShort(p.a.start)}', translate: false, style: TextStyle(fontSize: 12.5, color: context.muted)),
                            ]),
                          ),
                          Text(fmtDur(p.secs), translate: false, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.ink)),
                        ]),
                      ),
                    ),
                ]),
              const SectionHeader('Statistik'),
              _Card(child: _Totals(s, _f)),
              const SectionHeader('Aktivitas'),
              if (list.isEmpty) Text('Belum ada aktivitas jenis ini.', style: TextStyle(color: context.muted)),
              for (final a in list.take(50)) ...[ActivityCard(a: a, onTap: () => openActivity(context, a)), const SizedBox(height: 12)],
            ],
            const SizedBox(height: 8),
            Text('Peta © OpenStreetMap. Kalori adalah perkiraan.', style: TextStyle(fontSize: 11.5, color: context.faint)),
          ]),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.line)),
        child: child,
      );
}

/// Grafik garis jarak 12 minggu (titik oranye, minggu ini paling kanan) seperti Strava.
class _WeeksChart extends StatelessWidget {
  const _WeeksChart(this.s, this.f);
  final TrackState s;
  final ActivityType? f;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = [for (var i = 11; i >= 0; i--) TrackState.weekStart(now).subtract(Duration(days: 7 * i))];
    final vals = [for (final w in weeks) s.between(w, w.add(const Duration(days: 7)), f).fold(0.0, (a, x) => a + x.distance) / 1000];
    final maxY = math.max(4.0, (vals.reduce(math.max) / 4).ceil() * 4.0);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      minX: 0,
      maxX: 11,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 2, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .2), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF111633),
          getTooltipItems: (ss) => [for (final x in ss) LineTooltipItem('${fmtKm(x.y * 1000, 1)} km', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: maxY / 2, getTitlesWidget: (v, _) => Text(' ${v.toStringAsFixed(0)} km', translate: false, style: TextStyle(fontSize: 10.5, color: context.muted)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.round();
              if (i != 0 && i != 5 && i != 11) return const SizedBox.shrink();
              final d = weeks[i];
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day} ${monthShortName(d.month)}', translate: false, style: TextStyle(fontSize: 10.5, color: context.muted)));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < 12; i++) FlSpot(i.toDouble(), vals[i])],
          color: kTrack,
          barWidth: 2.4,
          dotData: FlDotData(show: true, getDotPainter: (spot, _, __, i) => FlDotCirclePainter(radius: i == 11 ? 5 : 3.4, color: i == 11 ? kTrack : context.card, strokeColor: kTrack, strokeWidth: 2)),
          belowBarData: BarAreaData(show: true, color: kTrack.withValues(alpha: .10)),
        ),
      ],
    ));
  }
}

/// Kalender bulan ini: hari beraktivitas ditandai bulatan oranye + minggu beruntun.
class _Calendar extends StatelessWidget {
  const _Calendar(this.s, this.f);
  final TrackState s;
  final ActivityType? f;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final lead = first.weekday - 1;
    final monthActs = s.between(first, DateTime(now.year, now.month + 1), f);
    final active = {for (final a in monthActs) a.start.day};
    final streak = s.streakWeeks(now);
    const heads = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('${monthName(now.month)} ${now.year}', translate: false, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: context.ink))),
        Text('${monthActs.length} ${tr('aktivitas')}', translate: false, style: TextStyle(fontSize: 12.5, color: context.muted, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),
      Row(children: [for (final h in heads) Expanded(child: Text(h, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.faint, fontWeight: FontWeight.w600)))]),
      const SizedBox(height: 6),
      for (var row = 0; row * 7 < lead + days; row++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(
                child: () {
                  final d = row * 7 + c - lead + 1;
                  if (d < 1 || d > days) return const SizedBox(height: 32);
                  final on = active.contains(d), today = d == now.day;
                  return Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? kTrack : null,
                        shape: BoxShape.circle,
                        border: today && !on ? Border.all(color: kTrack, width: 1.6) : null,
                      ),
                      child: Text('$d', translate: false, style: TextStyle(fontSize: 12.5, fontWeight: on || today ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : (d > now.day ? context.faint : context.ink))),
                    ),
                  );
                }(),
              ),
          ]),
        ),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.local_fire_department_rounded, color: kTrack, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(streak == 0 ? tr('Mulai minggu beruntunmu dengan satu aktivitas.') : '$streak ${tr('minggu beruntun')}',
              translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
        ),
      ]),
    ]);
  }
}

/// Statistik tahun ini & sepanjang masa (jumlah, jarak, waktu, elevasi).
class _Totals extends StatelessWidget {
  const _Totals(this.s, this.f);
  final TrackState s;
  final ActivityType? f;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = s.between(DateTime(now.year), DateTime(now.year + 1), f), all = s.of(f);
    String km(List<Activity> l) => '${fmtKm(l.fold(0.0, (a, x) => a + x.distance), 1)} km';
    String dur(List<Activity> l) {
      final m = l.fold(0, (a, x) => a + x.moving) ~/ 60;
      return '${m ~/ 60}${tr('j')} ${m % 60}${tr('m')}';
    }

    String el(List<Activity> l) => '${l.fold(0.0, (a, x) => a + x.stats.elevGain).round()} m';
    final rows = [
      ('Aktivitas', '${year.length}', '${all.length}'),
      ('Jarak', km(year), km(all)),
      ('Waktu', dur(year), dur(all)),
      ('Elevasi', el(year), el(all)),
    ];
    final head = TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w700);
    return Column(children: [
      Row(children: [
        const Expanded(flex: 4, child: SizedBox()),
        Expanded(flex: 5, child: Text('${tr('Tahun')} ${now.year}', translate: false, textAlign: TextAlign.right, style: head)),
        Expanded(flex: 5, child: Text('Sepanjang masa', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: head)),
      ]),
      for (final (l, y, a) in rows) ...[
        Divider(height: 18, color: context.line),
        Row(children: [
          Expanded(flex: 4, child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontWeight: FontWeight.w600))),
          Expanded(flex: 5, child: Text(y, translate: false, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
          Expanded(flex: 5, child: Text(a, translate: false, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
        ]),
      ],
    ]);
  }
}
