import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/calorie_provider.dart';
import '../../../services/calorie_logic.dart';
import '../../widgets/common.dart';
import 'calorie_add.dart';

const kKal = Color(0xFFF97316);
const kKalGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF97316), Color(0xFFF43F5E)]);
const kProt = Color(0xFF6366F1), kCarb = Color(0xFFF59E0B), kFat = Color(0xFF10B981);

class CalorieScreen extends ConsumerStatefulWidget {
  const CalorieScreen({super.key});
  @override
  ConsumerState<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends ConsumerState<CalorieScreen> {
  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(calorieProvider).profile == null) editBodyProfile(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(calorieProvider);
    final t = s.target;
    final eaten = s.kcalOn(_day);
    final goal = t?.target ?? 2000;
    final left = goal - eaten;
    final mac = s.macrosOn(_day);
    final isToday = sameDay(_day, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalori & Diet'),
        centerTitle: false,
        actions: [IconButton(tooltip: 'Profil tubuh', onPressed: () => editBodyProfile(context, ref), icon: const Icon(Icons.manage_accounts_rounded))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        // ---- pilih hari
        Row(children: [
          IconButton(onPressed: () => setState(() => _day = addDays(_day, -1)), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Text(isToday ? 'Hari ini' : fmtDateLong(_day), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          IconButton(onPressed: isToday ? null : () => setState(() => _day = addDays(_day, 1)), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        // ---- ringkasan
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: kKalGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: kKal.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
          ),
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 132,
                height: 132,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (eaten / goal).clamp(0, 1.2).toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CustomPaint(
                    painter: _Ring(v, over: left < 0),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(fmtKcal(left.abs()), style: accentFont(size: 28, color: Colors.white)),
                        Text(left >= 0 ? 'kkal tersisa' : 'kkal kelebihan', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _stat('🎯 Target', '${fmtKcal(goal)} kkal'),
                  _stat('🍽️ Dimakan', '${fmtKcal(eaten)} kkal'),
                  _stat(t == null ? '⚙️ Profil' : '${goals.firstWhere((g) => g.key == t.goal).emoji} Tujuan',
                      t == null ? 'belum diatur' : goals.firstWhere((g) => g.key == t.goal).name),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _macro('Protein', mac.p, t?.protein ?? 100),
              const SizedBox(width: 10),
              _macro('Karbo', mac.c, t?.carbs ?? 250),
              const SizedBox(width: 10),
              _macro('Lemak', mac.f, t?.fat ?? 67),
            ]),
          ]),
        ),
        if (t?.note.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SoftCard(
              color: const Color(0xFFFFF7ED),
              padding: const EdgeInsets.all(12),
              child: Text('💡 ${t!.note}', style: const TextStyle(color: Color(0xFF9A3412), height: 1.4, fontSize: 13)),
            ),
          ),
        const SizedBox(height: 14),
        // ---- tombol cepat
        Row(children: [
          _Quick('📷', 'Foto makanan', const Color(0xFFF97316), () => scanFoodPhoto(context, ref, meal: _mealNow(), day: _day)),
          const SizedBox(width: 10),
          _Quick('▦', 'Barcode', const Color(0xFF6366F1), () => scanBarcode(context, ref, meal: _mealNow(), day: _day)),
          const SizedBox(width: 10),
          _Quick('🔎', 'Cari makanan', const Color(0xFF10B981), () => showAddFood(context, ref, meal: _mealNow(), day: _day)),
        ]),
        // ---- waktu makan
        for (final m in mealKeys) _MealCard(meal: m, day: _day),
        // ---- berat badan
        const SectionHeader('Berat badan'),
        const _WeightCard(),
        const SizedBox(height: 10),
        Text('Angka kalori adalah perkiraan. Untuk diet khusus atau kondisi medis, konsultasikan dengan dokter atau ahli gizi.',
            style: TextStyle(fontSize: 11.5, color: context.faint)),
      ]),
    );
  }

  String _mealNow() => isTodaySel ? mealByHour(DateTime.now().hour) : 'siang';
  bool get isTodaySel => sameDay(_day, DateTime.now());

  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );

  Widget _macro(String label, double v, int target) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: (v / target).clamp(0, 1).toDouble(), minHeight: 6, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: .25)),
          ),
          const SizedBox(height: 3),
          Text('${v.round()}/$target g', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Ring extends CustomPainter {
  _Ring(this.v, {this.over = false});
  final double v;
  final bool over;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..color = over ? const Color(0xFFFDE047) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * math.min(v, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _Ring o) => o.v != v || o.over != over;
}

class _Quick extends StatelessWidget {
  const _Quick(this.emoji, this.label, this.color, this.onTap);
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          radius: 18,
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text(emoji, style: TextStyle(fontSize: 21, color: color, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal, required this.day});
  final String meal;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calorieProvider);
    final list = s.on(day).where((e) => e.meal == meal).toList();
    final kcal = list.fold(0.0, (a, e) => a + e.kcal);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        radius: 20,
        child: Column(children: [
          Row(children: [
            Text(mealEmoji[meal]!, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mealNames[meal]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(list.isEmpty ? 'Belum dicatat' : '${fmtKcal(kcal)} kkal · ${list.length} makanan', style: TextStyle(color: context.muted, fontSize: 12.5)),
              ]),
            ),
            IconButton.filledTonal(
              tooltip: 'Tambah ${mealNames[meal]!.toLowerCase()}',
              onPressed: () => showAddFood(context, ref, meal: meal, day: day),
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(backgroundColor: kKal.withValues(alpha: .12), foregroundColor: kKal),
            ),
          ]),
          for (final e in list)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => editEntry(context, ref, e, day),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(width: 32, child: Text(e.food.emoji, style: const TextStyle(fontSize: 20))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.food.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${fmtQty(e.qty)} × ${e.food.portion}${e.source == 'foto' ? ' · 📷' : e.source == 'barcode' ? ' · ▦' : ''}',
                          style: TextStyle(color: context.muted, fontSize: 12)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('${fmtKcal(e.kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Ubah jumlah / hapus makanan yang sudah dicatat.
Future<void> editEntry(BuildContext context, WidgetRef ref, FoodEntry e, DateTime day) async {
  var q = e.qty;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${e.food.emoji} ${e.food.name}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${mealNames[e.meal]} · ${e.food.portion} = ${fmtKcal(e.food.kcal)} kkal', style: TextStyle(color: ctx.muted)),
            const SizedBox(height: 14),
            QtyStepper(value: q, onChanged: (v) => setS(() => q = v), unit: e.food.portion),
            const SizedBox(height: 8),
            Text('${fmtKcal(e.food.kcal * q)} kkal', style: accentFont(size: 30, color: kKal)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE11D48), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    ref.read(calorieProvider.notifier).remove(e.id, day);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    ref.read(calorieProvider.notifier).setQty(e.id, day, q);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.unit = 'porsi'});
  final double value;
  final ValueChanged<double> onChanged;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final step = value <= 1 ? .25 : .5;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton.filledTonal(onPressed: value > .25 ? () => onChanged(math.max(.25, value - step)) : null, icon: const Icon(Icons.remove_rounded)),
      SizedBox(
        width: 150,
        child: Column(children: [
          Text('${fmtQty(value)}×', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12)),
        ]),
      ),
      IconButton.filledTonal(onPressed: value < 20 ? () => onChanged(value + (value < 1 ? .25 : .5)) : null, icon: const Icon(Icons.add_rounded)),
    ]);
  }
}

/// ---------- Berat badan ----------
class _WeightCard extends ConsumerWidget {
  const _WeightCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calorieProvider);
    final p = s.profile;
    if (p == null) {
      return SoftCard(
        child: Column(children: [
          const Text('⚖️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          const Text('Isi berat & tinggi badan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Supaya target kalori harianmu dihitung otomatis sesuai tujuan diet.', textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
          const SizedBox(height: 12),
          GradientButton(label: 'Atur profil tubuh', icon: Icons.tune_rounded, onPressed: () => editBodyProfile(context, ref)),
        ]),
      );
    }
    final bmi = Body.bmi(p.kg, p.cm);
    final (label, color) = Body.bmiLabel(bmi);
    final (lo, hi) = Body.healthyRange(p.cm);
    final w = s.weights.length > 30 ? s.weights.sublist(s.weights.length - 30) : s.weights;
    final first = s.weights.isEmpty ? p.kg : s.weights.first.kg;
    final diff = p.kg - first;
    final weeks = Body.weeksToTarget(p.kg, p.targetKg);
    return SoftCard(
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtQty(p.kg), style: accentFont(size: 38)),
          const Padding(padding: EdgeInsets.only(bottom: 6, left: 4), child: Text('kg', style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          if (s.weights.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${diff > 0 ? '▲' : diff < 0 ? '▼' : '•'} ${fmtQty(double.parse(diff.abs().toStringAsFixed(1)))} kg',
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.muted, fontSize: 13)),
            ),
          const Spacer(),
          FilledButton.tonalIcon(onPressed: () => logWeightDialog(context, ref), icon: const Icon(Icons.monitor_weight_outlined, size: 18), label: const Text('Catat')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('BMI ${bmi.toStringAsFixed(1)} · $label', Color(color)),
          _chip('Ideal ${fmtQty(lo)}–${fmtQty(hi)} kg', const Color(0xFF10B981)),
          _chip('Tinggi ${fmtQty(p.cm)} cm', const Color(0xFF6366F1)),
          if (p.targetKg != null) _chip('Target ${fmtQty(p.targetKg!)} kg${weeks > 0 ? ' · ±$weeks minggu' : ' ✓'}', kKal),
        ]),
        if (w.length >= 2) ...[
          const SizedBox(height: 16),
          SizedBox(height: 150, child: _WeightChart(w, target: p.targetKg)),
        ] else ...[
          const SizedBox(height: 10),
          Text('Catat berat badan rutin (mis. seminggu sekali di pagi hari) untuk melihat grafik perkembanganmu.', style: TextStyle(color: context.muted, fontSize: 12.5)),
        ],
      ]),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _WeightChart extends StatelessWidget {
  const _WeightChart(this.w, {this.target});
  final List<({String day, double kg})> w;
  final double? target;
  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < w.length; i++) FlSpot(i.toDouble(), w[i].kg)];
    final vals = [...w.map((x) => x.kg), if (target != null) target!];
    final lo = vals.reduce(math.min) - 1, hi = vals.reduce(math.max) + 1;
    return LineChart(LineChartData(
      minY: lo.floorToDouble(),
      maxY: hi.ceilToDouble(),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      extraLinesData: target == null
          ? null
          : ExtraLinesData(horizontalLines: [HorizontalLine(y: target!, color: kKal.withValues(alpha: .6), strokeWidth: 1.5, dashArray: [6, 4])]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (v, meta) => v == meta.min || v == meta.max ? Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 11, color: context.muted)) : const SizedBox.shrink(),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (v % 1 != 0 || i < 0 || i >= w.length || (i != 0 && i != w.length - 1)) return const SizedBox.shrink();
              final d = DateTime.tryParse(w[i].day);
              return Text(d == null ? '' : '${d.day}/${d.month}', style: TextStyle(fontSize: 11, color: context.muted));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(spots: spots, isCurved: true, color: kKal, barWidth: 4, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: kKal.withValues(alpha: .1))),
      ],
    ));
  }
}

Future<void> logWeightDialog(BuildContext context, WidgetRef ref) async {
  final cur = ref.read(calorieProvider).profile?.kg;
  final v = await inputDialog(context, title: 'Berat badan hari ini (kg)', initial: cur == null ? '' : fmtQty(cur), hint: 'mis. 65,5');
  if (v == null) return;
  final kg = double.tryParse(v.replaceAll(',', '.').trim());
  if (kg == null || kg < 25 || kg > 300) {
    if (context.mounted) showToast(context, 'Masukkan berat 25–300 kg');
    return;
  }
  if (ref.read(calorieProvider).profile == null) {
    if (context.mounted) await editBodyProfile(context, ref, kg: kg);
    return;
  }
  await ref.read(calorieProvider.notifier).logWeight(kg);
  if (context.mounted) showToast(context, 'Berat ${fmtQty(kg)} kg dicatat ⚖️');
}

/// ---------- Profil tubuh ----------
Future<void> editBodyProfile(BuildContext context, WidgetRef ref, {double? kg}) async {
  final p = ref.read(calorieProvider).profile;
  var male = p?.male ?? false;
  var act = p?.activity ?? 1.375;
  var goal = p?.goal ?? 'turun';
  final kgC = TextEditingController(text: kg != null ? fmtQty(kg) : (p == null ? '' : fmtQty(p.kg)));
  final cmC = TextEditingController(text: p == null ? '' : fmtQty(p.cm));
  final ageC = TextEditingController(text: p == null ? '' : '${p.age}');
  final tgC = TextEditingController(text: p?.targetKg == null ? '' : fmtQty(p!.targetKg!));
  double? d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final w = d(kgC), h = d(cmC), a = int.tryParse(ageC.text.trim()), tg = d(tgC);
      final ok = w != null && w >= 25 && w <= 300 && h != null && h >= 100 && h <= 250 && a != null && a >= 10 && a <= 100;
      final preview = ok ? Body.target(BodyProfile(kg: w, cm: h, age: a, male: male, activity: act, goal: goal, targetKg: tg)) : null;
      final range = h != null && h >= 100 ? Body.healthyRange(h) : null;
      final tgLow = tg != null && range != null && tg < range.$1;
      InputDecoration deco(String l, String suf) => InputDecoration(labelText: l, suffixText: suf, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .86,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            const Text('Profil tubuh', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Dipakai untuk menghitung target kalori harianmu.', style: TextStyle(color: ctx.muted)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('👩 Perempuan')), ButtonSegment(value: true, label: Text('👨 Laki-laki'))],
              selected: {male},
              onSelectionChanged: (v) => setS(() => male = v.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: kgC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('Berat', 'kg'), onChanged: (_) => setS(() {}))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: cmC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('Tinggi', 'cm'), onChanged: (_) => setS(() {}))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: ageC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: deco('Umur', 'th'),
                      onChanged: (_) => setS(() {}))),
            ]),
            const SizedBox(height: 16),
            const Text('Seberapa aktif kamu?', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final l in activityLevels)
              RadioListTile<double>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: l.f,
                groupValue: act,
                activeColor: kKal,
                onChanged: (v) => setS(() => act = v ?? act),
                title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l.desc),
              ),
            const SizedBox(height: 8),
            const Text('Tujuanmu', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final g in goals)
                ChoiceChip(
                  label: Text('${g.emoji} ${g.name}'),
                  selected: goal == g.key,
                  selectedColor: kKal.withValues(alpha: .18),
                  onSelected: (_) => setS(() => goal = g.key),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: tgC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: deco('Berat target (opsional)', 'kg').copyWith(
                helperText: range == null ? null : 'Berat sehat untuk tinggimu: ${fmtQty(range.$1)}–${fmtQty(range.$2)} kg',
                errorText: tgLow ? 'Di bawah berat sehat — pilih minimal ${fmtQty(range.$1)} kg' : null,
              ),
              onChanged: (_) => setS(() {}),
            ),
            const SizedBox(height: 16),
            if (preview != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: kKalGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Target kalori harianmu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('${fmtKcal(preview.target)} kkal', style: accentFont(size: 32, color: Colors.white)),
                  Text('Kebutuhan tubuhmu ±${fmtKcal(preview.tdee)} kkal/hari · BMI ${Body.bmi(w, h).toStringAsFixed(1)} (${Body.bmiLabel(Body.bmi(w, h)).$1})',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                  if (preview.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('💡 ${preview.note}', style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                  ],
                ]),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: !ok || tgLow
                  ? null
                  : () async {
                      await ref.read(calorieProvider.notifier).setProfile(BodyProfile(kg: w, cm: h, age: a, male: male, activity: act, goal: goal, targetKg: tg));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: Text(ok ? 'Simpan' : 'Isi berat, tinggi & umur dulu', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
    }),
  );
}

/// Ringkasan untuk kotak di Beranda.
String calorieSummary(CalorieState s) {
  final t = s.target;
  final eaten = s.kcalOn(DateTime.now());
  if (t == null) return eaten > 0 ? '${fmtKcal(eaten)} kkal hari ini' : 'Atur target diet';
  return '${fmtKcal(eaten)} / ${fmtKcal(t.target)} kkal';
}
