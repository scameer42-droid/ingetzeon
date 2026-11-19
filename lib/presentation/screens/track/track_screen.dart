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

/// Rekam Aktivitas (gaya Strava): ringkasan minggu ini, statistik, rekor pribadi, dan riwayat.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(trackProvider);
    final rec = ref.watch(recorderProvider);
    final now = DateTime.now();
    final week = s.inWeek(now);
    final km = s.weekKm(now);
    final secs = week.fold(0, (a, x) => a + x.moving);
    final elev = week.fold(0.0, (a, x) => a + x.stats.elevGain);
    final prs = s.bestEfforts();
    return Scaffold(
      appBar: AppBar(title: const Text('Rekam Aktivitas'), centerTitle: false, actions: [
        IconButton(tooltip: tr('Pengaturan'), icon: const Icon(Icons.tune_rounded), onPressed: () => _settings(context, ref)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        if (rec.active) ...[
          SoftCard(
            padding: const EdgeInsets.all(14),
            onTap: () => openRecord(context),
            child: Row(children: [
              CircleIcon(icon: rec.status == RecStatus.paused ? Icons.pause_rounded : Icons.fiber_manual_record_rounded, color: const Color(0xFFDC2626), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rec.status == RecStatus.paused ? 'Rekaman dijeda — ketuk untuk melanjutkan' : 'Sedang merekam — ketuk untuk membuka',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.ink)),
              ),
              Icon(Icons.chevron_right_rounded, color: context.faint),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        FeatureHero(
          color: kTrack,
          label: 'Minggu ini',
          title: '${fmtKm(km * 1000, 1)} ${tr('km dari target')} ${s.weeklyGoalKm} km',
          icon: Icons.route_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: (km / s.weeklyGoalKm).clamp(0, 1).toDouble(), minHeight: 8, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: .25)),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: StatBox(label: tr('Aktivitas'), value: '${week.length}', light: true)),
              Expanded(child: StatBox(label: tr('Waktu'), value: fmtDur(secs), light: true)),
              Expanded(child: StatBox(label: tr('Elevasi'), value: '${elev.round()}', unit: 'm', light: true)),
            ]),
          ]),
          actions: [
            HeroButton(label: rec.active ? 'Buka rekaman' : 'Mulai rekam', icon: Icons.play_arrow_rounded, color: kTrack, onTap: () => openRecord(context)),
          ],
        ),
        if (s.activities.isEmpty) ...[
          const SizedBox(height: 20),
          const EmptyState(
            title: 'Belum ada aktivitas.',
            subtitle: 'Tekan "Mulai rekam", pilih lari, jalan, sepeda, atau hiking, lalu IngetZeon mencatat rute, jarak, pace, dan elevasimu dengan GPS.',
            icon: Icons.directions_run_rounded,
          ),
        ] else ...[
          const SectionHeader('Jarak 12 minggu terakhir'),
          SoftCard(padding: const EdgeInsets.fromLTRB(8, 18, 12, 8), child: SizedBox(height: 170, child: _WeeksChart(s))),
          const SectionHeader('Rekor pribadi'),
          ListGroup(children: [
            for (final p in prs)
              AppListRow(
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFFF59E0B),
                title: '${tr('Lari')} ${p.label}',
                subtitle: '${fmtDur(p.secs)} · ${fmtPace(p.secs / (p.meters / 1000))}/km · ${fmtDateShort(p.activity.start)}',
                trailing: const SizedBox.shrink(),
                onTap: () => openActivity(context, p.activity),
              ),
            if (s.longest != null)
              AppListRow(
                icon: Icons.straighten_rounded,
                color: kTrack,
                title: 'Terjauh',
                subtitle: '${fmtKm(s.longest!.distance)} km · ${s.longest!.title}',
                trailing: const SizedBox.shrink(),
                onTap: () => openActivity(context, s.longest!),
              ),
            if (s.mostClimb != null && s.mostClimb!.stats.elevGain >= 5)
              AppListRow(
                icon: Icons.terrain_rounded,
                color: const Color(0xFF7C3AED),
                title: 'Tanjakan terbanyak',
                subtitle: '${s.mostClimb!.stats.elevGain.round()} m · ${s.mostClimb!.title}',
                trailing: const SizedBox.shrink(),
                onTap: () => openActivity(context, s.mostClimb!),
              ),
          ]),
          if (prs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('Rekor lari 1 km, 5 km, 10 km, dan half marathon muncul otomatis setelah kamu merekam lari sejauh itu.', style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4)),
            ),
          const SectionHeader('Riwayat'),
          for (final a in s.activities.take(50)) ...[ActivityCard(a: a, onTap: () => openActivity(context, a)), const SizedBox(height: 10)],
        ],
        const SizedBox(height: 8),
        Text('Peta © OpenStreetMap. Kalori adalah perkiraan.', style: TextStyle(fontSize: 11.5, color: context.faint)),
      ]),
    );
  }

  Future<void> _settings(BuildContext context, WidgetRef ref) async {
    await showAppSheet(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final s = ref.watch(trackProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Pengaturan rekam', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text('Target jarak per minggu', style: TextStyle(fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => ref.read(trackProvider.notifier).setGoal(s.weeklyGoalKm - 5), icon: const Icon(Icons.remove_circle_outline_rounded)),
              Text('${s.weeklyGoalKm} km', translate: false, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(onPressed: () => ref.read(trackProvider.notifier).setGoal(s.weeklyGoalKm + 5), icon: const Icon(Icons.add_circle_outline_rounded)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kTrack,
              title: const Text('Aba-aba suara tiap 1 km', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Jarak, waktu, dan pace dibacakan', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
              value: s.voice,
              onChanged: (v) => ref.read(trackProvider.notifier).setVoice(v),
            ),
          ]),
        );
      }),
    );
  }
}

class _WeeksChart extends StatelessWidget {
  const _WeeksChart(this.s);
  final TrackState s;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = [for (var i = 11; i >= 0; i--) TrackState.weekStart(now).subtract(Duration(days: 7 * i))];
    final vals = [for (final w in weeks) s.weekKm(w)];
    final maxY = math.max(5.0, (vals.reduce(math.max) / 5).ceil() * 5.0);
    return BarChart(BarChartData(
      maxY: maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 2, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => const Color(0xFF111633), getTooltipItem: (g, _, r, __) => BarTooltipItem('${fmtKm(r.toY * 1000, 1)} km', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: maxY / 2, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), translate: false, style: TextStyle(fontSize: 11, color: context.muted)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.round();
              if (i != 0 && i != 11 && i != 6) return const SizedBox.shrink();
              final d = weeks[i];
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day} ${bulanShort[d.month - 1]}', translate: false, style: TextStyle(fontSize: 11, color: context.muted)));
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < 12; i++)
          BarChartGroupData(x: i, barRods: [BarChartRodData(toY: vals[i], width: 14, color: i == 11 ? kTrack : kTrack.withValues(alpha: .45), borderRadius: BorderRadius.circular(4))]),
      ],
    ));
  }
}
