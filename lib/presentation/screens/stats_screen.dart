import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../widgets/common.dart';

class _DayStat {
  const _DayStat(this.day, this.total, this.done);
  final DateTime day;
  final int total;
  final int done;
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(remindersProvider);
    final notifier = ref.read(remindersProvider.notifier);
    final log = notifier.doneLog;
    final today = dateOnly(DateTime.now());

    final days = <_DayStat>[
      for (var i = 6; i >= 0; i--)
        () {
          final d = addDays(today, -i);
          final its = occurrencesOn(list, d);
          final lg = notifier.doneLogOn(d);
          return _DayStat(d, its.length + lg, its.where((x) => x.done).length + lg);
        }(),
    ];
    final total = days.fold<int>(0, (a, b) => a + b.total);
    final done = days.fold<int>(0, (a, b) => a + b.done);
    final pct = total == 0 ? 0 : (done / total * 100).round();
    final active = list.where((r) => r.repeat != RepeatType.once || r.nextOccurrence() != null).length;

    // Hari beruntun: semua jadwal di hari itu selesai (hari tanpa jadwal dilewati).
    var streak = 0;
    for (var i = 0; i < 365; i++) {
      final its = occurrencesOn(list, addDays(today, -i));
      if (its.isEmpty && notifier.doneLogOn(addDays(today, -i)) == 0) continue;
      if (its.every((x) => x.done)) {
        streak++;
      } else if (i == 0) {
        continue; // hari ini belum selesai, belum memutus
      } else {
        break;
      }
    }

    final counts = {
      for (final c in ReminderCategory.values) c: list.where((r) => r.category == c).length + log.where((x) => x['c'] == c.name).length,
    };
    final maxCount = math.max(1, counts.values.fold<int>(0, math.max));
    final maxY = math.max(4, days.map((d) => d.total).fold<int>(0, math.max)).toDouble();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Text('7 hari terakhir', style: TextStyle(fontSize: 13, color: context.muted, fontWeight: FontWeight.w500)),
          const Text('Statistik', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          SoftCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(size: const Size(118, 118), painter: _RingPainter(v, context.card2)),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$pct%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1)),
                    Text('selesai', style: TextStyle(fontSize: 11, color: context.muted)),
                  ]),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Progres tugas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Belum ada jadwal dalam 7 hari terakhir.'
                        : pct >= 80
                            ? 'Luar biasa! Kamu sangat konsisten 💪'
                            : pct >= 50
                                ? 'Bagus, terus pertahankan ritmenya.'
                                : 'Yuk, selesaikan satu per satu.',
                    style: TextStyle(fontSize: 13, color: context.muted),
                  ),
                  const SizedBox(height: 8),
                  _legend(null, '$done selesai', gradient: true),
                  const SizedBox(height: 6),
                  _legend(context.card2, '${total - done} belum'),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatTile(icon: Icons.notifications_none_rounded, color: AppColors.primary, label: 'Pengingat aktif', value: '$active')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(icon: Icons.local_fire_department_outlined, color: AppColors.pink, label: 'Hari beruntun', value: '$streak', unit: 'hari')),
          ]),
          const SizedBox(height: 12),
          SoftCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Jumlah pengingat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('Tap batang untuk melihat detail', style: TextStyle(fontSize: 12.5, color: context.muted)),
              const SizedBox(height: 18),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 2,
                      getDrawingHorizontalLine: (_) => FlLine(color: context.line, strokeWidth: 1, dashArray: [3, 5]),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= days.length) return const SizedBox.shrink();
                            final isToday = i == days.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                isToday ? 'Hari ini' : hariShort[jsDay(days[i].day)],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                  color: isToday ? AppColors.primary : context.faint,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => context.ink,
                        getTooltipItem: (group, gi, rod, ri) {
                          final d = days[group.x];
                          return BarTooltipItem(
                            '${fmtDateShort(d.day)}\n${d.done}/${d.total} selesai',
                            TextStyle(color: context.card, fontSize: 12, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: days[i].total == 0 ? 0.08 : days[i].total.toDouble(),
                              width: 22,
                              borderRadius: BorderRadius.circular(8),
                              color: context.card2,
                              rodStackItems: [
                                if (days[i].done > 0)
                                  BarChartRodStackItem(0, days[i].done.toDouble(), AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SoftCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Per kategori', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('Semua pengingat yang tersimpan', style: TextStyle(fontSize: 12.5, color: context.muted)),
              const SizedBox(height: 14),
              for (final c in ReminderCategory.values) ...[
                Row(children: [
                  CategoryIcon(c, size: 26),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text('${counts[c]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: counts[c]! / maxCount,
                    minHeight: 8,
                    backgroundColor: context.card2,
                    valueColor: AlwaysStoppedAnimation(c.color),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color? color, String text, {bool gradient = false}) => Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, gradient: gradient ? AppColors.gradient : null, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13)),
      ]);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.label, required this.value, this.unit});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 12.5, color: context.muted, fontWeight: FontWeight.w500)),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          if (unit != null) TextSpan(text: ' $unit', style: TextStyle(fontSize: 13, color: context.muted)),
        ])),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.track);
  final double value;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (value <= 0) return;
    final paint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [AppColors.primary, AppColors.primary],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.track != track;
}
