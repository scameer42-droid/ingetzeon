import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/calorie_provider.dart';
import '../../../services/calorie_logic.dart';
import '../../widgets/common.dart';
import 'calorie_screen.dart';

/// Warna khusus berat badan.
const kW = Color(0xFFEA580C);
const kWGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA83F09), Color(0xFFEA580C)]);
const kGood = Color(0xFF10B981), kWarn = Color(0xFFF59E0B);

String kgStr(double v) => fmtQty(double.parse(v.toStringAsFixed(1)));
DateTime _d(String day) => DateTime.tryParse(day) ?? DateTime.now();
String _dayShort(String day) {
  final d = _d(day);
  return sameDay(d, DateTime.now()) ? 'Hari ini' : '${d.day} ${bulanShort[d.month - 1]}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';
}

/// Ringkasan perkembangan berat: awal → sekarang → target.
class WeightStats {
  WeightStats._(this.start, this.current, this.target, this.lose, this.cm);
  final ({String day, double kg}) start, current;
  final double? target;
  final bool lose; // arah yang diinginkan: turun?
  final double? cm;

  double get change => current.kg - start.kg;
  bool get good => change == 0 ? true : (lose ? change < 0 : change > 0);
  bool get reached => target != null && (lose ? current.kg <= target! : current.kg >= target!);
  double? get remaining => target == null ? null : (reached ? 0 : (current.kg - target!).abs());
  double? get progress {
    if (target == null) return null;
    final total = start.kg - target!;
    if (total.abs() < .05) return reached ? 1 : 0;
    return ((start.kg - current.kg) / total).clamp(0, 1).toDouble();
  }

  int get days => _d(current.day).difference(_d(start.day)).inDays;
  double? get perWeek => days >= 7 ? change / days * 7 : null;
  double? get bmi => cm == null ? null : Body.bmi(current.kg, cm!);

  static WeightStats? of(CalorieState s) {
    final p = s.profile;
    if (p == null) return null;
    final w = s.weights;
    final today = dayKey(DateTime.now());
    final start = w.isEmpty ? (day: today, kg: p.kg) : w.first;
    final cur = w.isEmpty ? (day: today, kg: p.kg) : w.last;
    final lose = p.targetKg != null ? p.targetKg! < start.kg : p.goal != 'naik';
    return WeightStats._(start, cur, p.targetKg, lose, p.cm);
  }

  String get changeText {
    final c = change.abs();
    if (c < .05) return days == 0 ? 'Ini catatan pertamamu' : 'Belum berubah dari awal';
    return '${change < 0 ? 'Turun' : 'Naik'} ${kgStr(c)} kg sejak awal${good ? ' 🎉' : ''}';
  }
}

/// Kartu ringkas: berat awal → sekarang → target, dengan progres.
class WeightProgressCard extends ConsumerWidget {
  const WeightProgressCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calorieProvider);
    final st = WeightStats.of(s);
    if (st == null) {
      return SoftCard(
        radius: 22,
        child: Column(children: [
          const Text('⚖️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          const Text('Isi berat & tinggi badan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Untuk melihat berat awal, berat sekarang, target dan target kalori harianmu.', textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
          const SizedBox(height: 12),
          GradientButton(label: 'Atur profil tubuh', icon: Icons.tune_rounded, onPressed: () => editBodyProfile(context, ref)),
        ]),
      );
    }
    final changeColor = st.change.abs() < .05 ? context.muted : (st.good ? kGood : kWarn);
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kW.withValues(alpha: .14), blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => openWeightScreen(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // kepala bergradasi
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(gradient: kWGradient),
              child: Row(children: [
                const Text('⚖️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Perkembangan berat badan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5))),
                Text('Detail', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w700, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: _Col(label: 'AWAL', kg: st.start.kg, sub: _dayShort(st.start.day), color: context.muted)),
                Icon(Icons.arrow_forward_rounded, size: 18, color: context.faint),
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: kW.withValues(alpha: .1), borderRadius: BorderRadius.circular(18), border: Border.all(color: kW.withValues(alpha: .35), width: 1.5)),
                    child: _Col(label: 'SAAT INI', kg: st.current.kg, sub: _dayShort(st.current.day), color: kW, big: true),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 18, color: context.faint),
                Expanded(
                  child: st.target == null
                      ? InkWell(
                          onTap: () => editTargetWeight(context, ref),
                          child: Column(children: [
                            Text('TARGET', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: context.muted)),
                            const SizedBox(height: 4),
                            const Icon(Icons.add_circle_outline_rounded, color: kW),
                            Text('Atur', style: TextStyle(fontSize: 11.5, color: context.muted)),
                          ]),
                        )
                      : _Col(label: 'TARGET', kg: st.target!, sub: st.reached ? 'Tercapai ✓' : '±${Body.weeksToTarget(st.current.kg, st.target)} mgg', color: kGood),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: changeColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                    child: Text('${st.change < -.04 ? '▼ ' : st.change > .04 ? '▲ ' : ''}${st.changeText}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: changeColor, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                if (st.bmi != null) Text('BMI ${st.bmi!.toStringAsFixed(1).replaceAll('.', ',')}', style: TextStyle(color: Color(Body.bmiLabel(st.bmi!).$2), fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
            if (st.progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: st.progress, minHeight: 10, color: kGood, backgroundColor: kGood.withValues(alpha: .14)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    st.reached ? 'Target tercapai! Pertahankan pola makan & olahraga 💪' : '${(st.progress! * 100).round()}% menuju target · sisa ${kgStr(st.remaining!)} kg',
                    style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kW, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => logWeightSheet(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Catat berat', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: kW, padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: kW.withValues(alpha: .4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => openWeightScreen(context),
                    icon: const Icon(Icons.show_chart_rounded, size: 20),
                    label: const Text('Grafik', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col({required this.label, required this.kg, required this.sub, required this.color, this.big = false});
  final String label, sub;
  final double kg;
  final Color color;
  final bool big;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: TextStyle(fontSize: big ? 11.5 : 10.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: big ? kW : context.muted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(kgStr(kg), style: accentFont(size: big ? 30 : 19, color: big ? kW : context.ink)),
            Padding(padding: EdgeInsets.only(bottom: big ? 5 : 3, left: 2), child: Text('kg', style: TextStyle(fontWeight: FontWeight.w700, fontSize: big ? 13 : 11, color: big ? kW : context.muted))),
          ]),
        ),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: context.muted, fontWeight: FontWeight.w600)),
      ]);
}

void openWeightScreen(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeightScreen()));

/// ---------- Halaman berat badan lengkap ----------
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});
  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  int _range = 90; // hari; 0 = semua

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(calorieProvider);
    final st = WeightStats.of(s);
    if (st == null) {
      return Scaffold(appBar: AppBar(title: const Text('Berat badan')), body: const Padding(padding: EdgeInsets.all(16), child: WeightProgressCard()));
    }
    final p = s.profile!;
    final all = s.weights.isEmpty ? [st.current] : s.weights;
    final from = _range == 0 ? null : dayKey(DateTime.now().subtract(Duration(days: _range)));
    final shown = from == null ? all : all.where((w) => w.day.compareTo(from) >= 0).toList();
    final changeColor = st.change.abs() < .05 ? Colors.white : (st.good ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A));
    return Scaffold(
      appBar: AppBar(title: const Text('Berat badan'), actions: [
        IconButton(tooltip: tr('Profil tubuh'), onPressed: () => editBodyProfile(context, ref), icon: const Icon(Icons.manage_accounts_rounded)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        // ---- pahlawan: berat saat ini
        Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(gradient: kWGradient, borderRadius: BorderRadius.circular(20)), child: CustomPaint(painter: const HillsPainter(), child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BERAT SAAT INI', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(
                flex: 3,
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: Text(kgStr(st.current.kg), style: accentFont(size: 54, color: Colors.white))),
              ),
              const Padding(padding: EdgeInsets.only(bottom: 12, left: 4), child: Text('kg', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('dicatat ${_dayShort(st.current.day).toLowerCase()}',
                      textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            Text('${st.change < -.04 ? '▼ ' : st.change > .04 ? '▲ ' : ''}${st.changeText}', style: TextStyle(color: changeColor, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              _heroBox('Berat awal', '${kgStr(st.start.kg)} kg', _dayShort(st.start.day), onTap: () => _editEntry(st.start, isStart: true)),
              const SizedBox(width: 8),
              _heroBox('Target', st.target == null ? 'Atur' : '${kgStr(st.target!)} kg', st.target == null ? 'ketuk di sini' : st.reached ? 'tercapai ✓' : 'sisa ${kgStr(st.remaining!)} kg',
                  onTap: () => editTargetWeight(context, ref)),
              const SizedBox(width: 8),
              _heroBox('Per minggu', st.perWeek == null ? '–' : '${st.perWeek! > 0 ? '+' : ''}${kgStr(st.perWeek!)} kg', st.perWeek == null ? 'butuh 1 minggu' : 'rata-rata'),
            ]),
          ])))),
        // ---- perjalanan menuju target
        if (st.target != null) ...[
          const SizedBox(height: 14),
          SoftCard(
            radius: 22,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Menuju target', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Text('${(st.progress! * 100).round()}%', style: accentFont(size: 20, color: kGood)),
              ]),
              const SizedBox(height: 14),
              _Journey(st),
              const SizedBox(height: 10),
              Text(
                st.reached
                    ? 'Selamat, target tercapai! Sekarang fokus menjaga berat dengan pola makan seimbang 💚'
                    : 'Sisa ${kgStr(st.remaining!)} kg. Dengan laju sehat 0,5 kg/minggu, perkiraan ±${Body.weeksToTarget(st.current.kg, st.target)} minggu lagi.',
                style: TextStyle(color: context.muted, height: 1.4, fontSize: 13),
              ),
            ]),
          ),
        ],
        // ---- BMI
        const SizedBox(height: 14),
        SoftCard(radius: 22, child: _BmiGauge(kg: st.current.kg, cm: p.cm, target: st.target)),
        // ---- grafik
        const SizedBox(height: 14),
        SoftCard(
          radius: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Grafik berat', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [ButtonSegment(value: 30, label: Text('1 bln')), ButtonSegment(value: 90, label: Text('3 bln')), ButtonSegment(value: 0, label: Text('Semua'))],
                selected: {_range},
                onSelectionChanged: (v) => setState(() => _range = v.first),
              ),
            ]),
            const SizedBox(height: 16),
            if (shown.length >= 2)
              SizedBox(height: 190, child: WeightChart(shown, target: st.target, start: st.start.kg))
            else
              Container(
                height: 110,
                alignment: Alignment.center,
                child: Text('Catat berat minimal 2 kali (mis. seminggu sekali) untuk melihat grafiknya.', textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
              ),
          ]),
        ),
        // ---- riwayat
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Row(children: [
            const Expanded(child: Text('Riwayat penimbangan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            TextButton.icon(onPressed: () => logWeightSheet(context, ref, pickDate: true), icon: const Icon(Icons.history_rounded, size: 18), label: const Text('Catatan lama')),
          ]),
        ),
        SoftCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = all.length - 1; i >= 0; i--)
              _historyRow(all[i], i > 0 ? all[i].kg - all[i - 1].kg : null, i == 0, st.lose, i > 0 || all.length == 1),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Ketuk catatan untuk mengubah. Catatan paling lama dipakai sebagai berat awal — tambahkan lewat "Catatan lama" kalau kamu sudah menimbang sebelum memakai aplikasi.',
            style: TextStyle(color: context.faint, fontSize: 11.5, height: 1.4)),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kW, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          onPressed: () => logWeightSheet(context, ref),
          icon: const Icon(Icons.monitor_weight_outlined),
          label: const Text('Catat berat hari ini', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ),
      ),
    );
  }

  Widget _heroBox(String l, String v, String sub, {VoidCallback? onTap}) => Expanded(
        child: Material(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
              ]),
            ),
          ),
        ),
      );

  Widget _historyRow(({String day, double kg}) w, double? diff, bool first, bool lose, bool canDelete) {
    final good = diff == null || diff.abs() < .05 ? null : (lose ? diff < 0 : diff > 0);
    final c = good == null ? context.muted : (good ? kGood : kWarn);
    return ListTile(
      onTap: () => _editEntry(w, isStart: first),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: (first ? kW : c).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Text(first ? '🏁' : (diff == null || diff.abs() < .05 ? '•' : diff < 0 ? '▼' : '▲'), style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: first ? 18 : 15)),
      ),
      title: Text(fmtDateLong(_d(w.day)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(first ? 'Berat awal' : diff == null || diff.abs() < .05 ? 'Sama dengan sebelumnya' : '${diff < 0 ? 'Turun' : 'Naik'} ${kgStr(diff.abs())} kg dari sebelumnya',
          style: TextStyle(color: first ? kW : c, fontWeight: FontWeight.w600, fontSize: 12.5)),
      trailing: Text('${kgStr(w.kg)} kg', style: accentFont(size: 17, color: context.ink)),
    );
  }

  Future<void> _editEntry(({String day, double kg}) w, {bool isStart = false}) async {
    final n = ref.read(calorieProvider).weights.length;
    await logWeightSheet(context, ref, day: w.day, kg: w.kg, title: isStart ? 'Ubah berat awal' : 'Ubah catatan', pickDate: isStart, canDelete: n > 1);
  }
}

/// Garis perjalanan: awal ● ——— sekarang ——— ◎ target
class _Journey extends StatelessWidget {
  const _Journey(this.st);
  final WeightStats st;
  @override
  Widget build(BuildContext context) {
    final pr = st.progress ?? 0;
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final x = (w - 28) * pr + 14;
      return SizedBox(
        height: 66,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 14, right: 14, top: 26, child: Container(height: 8, decoration: BoxDecoration(color: kGood.withValues(alpha: .15), borderRadius: BorderRadius.circular(9)))),
          Positioned(left: 14, top: 26, width: math.max(0, x - 14), child: Container(height: 8, decoration: BoxDecoration(gradient: const LinearGradient(colors: [kW, kGood]), borderRadius: BorderRadius.circular(9)))),
          Positioned(left: 6, top: 22, child: _dot(kW)),
          Positioned(right: 6, top: 22, child: _dot(kGood, ring: true)),
          Positioned(
            left: (x - 34).clamp(0, w - 68).toDouble(),
            top: 0,
            width: 68,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kW, borderRadius: BorderRadius.circular(8)),
                child: Text('${kgStr(st.current.kg)} kg', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Positioned(left: x - 9, top: 21, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kW, width: 4)))),
          Positioned(left: 0, bottom: 0, child: Text('Awal ${kgStr(st.start.kg)} kg', style: TextStyle(fontSize: 11.5, color: context.muted, fontWeight: FontWeight.w700))),
          Positioned(right: 0, bottom: 0, child: Text('Target ${kgStr(st.target!)} kg', style: const TextStyle(fontSize: 11.5, color: kGood, fontWeight: FontWeight.w800))),
        ]),
      );
    });
  }

  Widget _dot(Color c, {bool ring = false}) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: ring ? Colors.white : c, shape: BoxShape.circle, border: Border.all(color: c, width: ring ? 4 : 0)),
      );
}

/// Skala BMI berwarna dengan penanda posisi sekarang.
class _BmiGauge extends StatelessWidget {
  const _BmiGauge({required this.kg, required this.cm, this.target});
  final double kg, cm;
  final double? target;
  @override
  Widget build(BuildContext context) {
    final bmi = Body.bmi(kg, cm);
    final (label, color) = Body.bmiLabel(bmi);
    final (lo, hi) = Body.healthyRange(cm);
    const minB = 15.0, maxB = 35.0;
    double pos(double b) => ((b - minB) / (maxB - minB)).clamp(0, 1).toDouble();
    const segs = [(15.0, 18.5, Color(0xFF0EA5E9), 'Kurus'), (18.5, 25.0, Color(0xFF10B981), 'Normal'), (25.0, 27.0, Color(0xFFF59E0B), 'Gemuk'), (27.0, 35.0, Color(0xFFE11D48), 'Obesitas')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Expanded(child: Text('Indeks massa tubuh', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        Text(bmi.toStringAsFixed(1).replaceAll('.', ','), style: accentFont(size: 24, color: Color(color))),
        const SizedBox(width: 6),
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: TextStyle(color: Color(color), fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (ctx, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 44,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Row(children: [
                  for (final sg in segs) Expanded(flex: ((sg.$2 - sg.$1) * 10).round(), child: Container(height: 12, color: sg.$3)),
                ]),
              ),
            ),
            if (target != null)
              Positioned(
                left: w * pos(Body.bmi(target!, cm)) - 1.5,
                top: 4,
                child: Container(width: 3, height: 20, decoration: BoxDecoration(color: kGood, borderRadius: BorderRadius.circular(2))),
              ),
            Positioned(
              left: w * pos(bmi) - 11,
              top: 0,
              child: Container(
                width: 22,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(color), width: 3), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)]),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(children: [
                for (final sg in segs)
                  Expanded(
                    flex: ((sg.$2 - sg.$1) * 10).round(),
                    child: Text(sg.$4, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 10.5, color: sg.$3, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ]),
        );
      }),
      const SizedBox(height: 10),
      Text('Berat sehat untuk tinggi ${fmtQty(cm)} cm: ${kgStr(lo)}–${kgStr(hi)} kg${target != null ? ' · garis hijau = BMI di berat target' : ''}.',
          style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4)),
    ]);
  }
}

/// Grafik garis berat dengan garis target (hijau putus-putus) & berat awal (abu-abu).
class WeightChart extends StatelessWidget {
  const WeightChart(this.w, {super.key, this.target, this.start});
  final List<({String day, double kg})> w;
  final double? target, start;
  @override
  Widget build(BuildContext context) {
    final d0 = _d(w.first.day);
    final spots = [for (final x in w) FlSpot(_d(x.day).difference(d0).inDays.toDouble(), x.kg)];
    final vals = [...w.map((x) => x.kg), if (target != null) target!, if (start != null) start!];
    final lo = vals.reduce(math.min) - 1, hi = vals.reduce(math.max) + 1;
    final maxX = math.max(1.0, spots.last.x);
    return LineChart(LineChartData(
      minX: 0,
      maxX: maxX,
      minY: lo.floorToDouble(),
      maxY: hi.ceilToDouble(),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => kW,
          getTooltipItems: (items) => [
            for (final it in items)
              LineTooltipItem('${kgStr(it.y)} kg\n${_dayShort(dayKey(d0.add(Duration(days: it.x.round()))))}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
      extraLinesData: ExtraLinesData(horizontalLines: [
        if (target != null)
          HorizontalLine(
            y: target!,
            color: kGood,
            strokeWidth: 2,
            dashArray: [6, 4],
            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: kGood, fontWeight: FontWeight.w800, fontSize: 11), labelResolver: (_) => 'Target'),
          ),
      ]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (v, meta) => v == meta.min || v == meta.max || v % 2 == 0 ? Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 11, color: context.muted)) : const SizedBox.shrink(),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: maxX,
            getTitlesWidget: (v, _) {
              final d = d0.add(Duration(days: v.round()));
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day} ${bulanShort[d.month - 1]}', style: TextStyle(fontSize: 11, color: context.muted)));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: kW,
          barWidth: 4,
          dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) => FlDotCirclePainter(radius: i == spots.length - 1 ? 6 : 3.5, color: Colors.white, strokeWidth: 3, strokeColor: kW)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kW.withValues(alpha: .25), kW.withValues(alpha: 0)])),
        ),
      ],
    ));
  }
}

/// ---------- Lembar catat / ubah berat ----------
Future<void> logWeightSheet(BuildContext context, WidgetRef ref, {String? day, double? kg, String? title, bool pickDate = false, bool canDelete = false}) async {
  final s = ref.read(calorieProvider);
  final editing = day != null;
  var date = day == null ? DateTime.now() : _d(day);
  var v = kg ?? s.profile?.kg ?? (s.weights.isEmpty ? 60.0 : s.weights.last.kg);
  v = double.parse(v.toStringAsFixed(1));
  var showDate = pickDate;

  await showAppSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final key = dayKey(date);
      final others = s.weights.where((w) => w.day != key).toList();
      final prev = others.where((w) => w.day.compareTo(key) < 0).toList();
      final before = prev.isEmpty ? null : prev.last;
      final start = others.isEmpty || others.first.day.compareTo(key) > 0 ? null : others.first;
      void set(double n) => setS(() => v = double.parse(n.clamp(25.0, 300.0).toStringAsFixed(1)));
      Widget step(String l, double d) => SizedBox(
            width: 54,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: kW, side: BorderSide(color: kW.withValues(alpha: .35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => set(v + d),
              child: Text(l, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          );
      Widget cmp(String l, double? base) {
        if (base == null) return const SizedBox.shrink();
        final d = v - base;
        final c = d.abs() < .05 ? ctx.muted : ((s.profile?.goal == 'naik') == (d > 0) ? kGood : kWarn);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('$l: ${d.abs() < .05 ? 'sama' : '${d < 0 ? '▼ turun' : '▲ naik'} ${kgStr(d.abs())} kg'}', textAlign: TextAlign.center, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title ?? 'Catat berat badan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Material(
            color: kW.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.event_rounded, color: kW),
              title: Text(sameDay(date, DateTime.now()) ? 'Hari ini · ${fmtDateShort(date)}' : fmtDateLong(date), style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(showDate || !editing ? 'Ubah' : '', style: const TextStyle(color: kW, fontWeight: FontWeight.w800)),
              onTap: !showDate && editing
                  ? null
                  : () async {
                      final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now().subtract(const Duration(days: 1095)), lastDate: DateTime.now(), helpText: tr('Tanggal menimbang'));
                      if (d != null) setS(() => date = d);
                    },
            ),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(kgStr(v), style: accentFont(size: 58, color: kW)),
            const Padding(padding: EdgeInsets.only(bottom: 14, left: 4), child: Text('kg', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: kW))),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [step('−1', -1), step('−0,1', -.1), step('+0,1', .1), step('+1', 1)]),
          Slider(value: v.clamp(25, 300).toDouble(), min: 25, max: 300, divisions: 2750, activeColor: kW, onChanged: set),
          cmp('Dibanding sebelumnya', before?.kg),
          if (start != null && start != before) cmp('Dari berat awal', start.kg),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ctx.isDark ? Colors.white10 : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
            child: Text('💡 Timbang di pagi hari setelah buang air, sebelum makan, dengan pakaian ringan — supaya hasilnya bisa dibandingkan.',
                style: TextStyle(color: ctx.muted, fontSize: 12.5, height: 1.4)),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kW, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              final n = ref.read(calorieProvider.notifier);
              if (ref.read(calorieProvider).profile == null) {
                Navigator.pop(ctx);
                if (context.mounted) await editBodyProfile(context, ref, kg: v);
                return;
              }
              if (editing && day != key) await n.removeWeight(day);
              await n.setWeightOn(key, v);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) showToast(context, 'Berat ${kgStr(v)} kg dicatat ⚖️');
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          ),
          if (editing && canDelete)
            TextButton(
              onPressed: () async {
                if (await confirmDialog(ctx, title: 'Hapus catatan ini?', message: '${kgStr(kg ?? v)} kg pada ${fmtDateLong(_d(day))}', ok: 'Hapus', danger: true)) {
                  await ref.read(calorieProvider.notifier).removeWeight(day);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Hapus catatan', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w700)),
            ),
        ]),
      );
    }),
  );
}

/// Atur berat target (dengan batas berat sehat).
Future<void> editTargetWeight(BuildContext context, WidgetRef ref) async {
  final p = ref.read(calorieProvider).profile;
  if (p == null) return editBodyProfile(context, ref);
  final (lo, hi) = Body.healthyRange(p.cm);
  final v = await inputDialog(context,
      title: 'Berat target (kg)',
      message: 'Berat sehat untuk tinggi ${fmtQty(p.cm)} cm: ${kgStr(lo)}–${kgStr(hi)} kg. Kosongkan untuk menghapus target.',
      initial: p.targetKg == null ? '' : kgStr(p.targetKg!),
      hint: 'mis. ${kgStr(math.min(hi, math.max(lo, p.kg - 5)))}');
  if (v == null) return;
  final t = v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.').trim());
  if (v.trim().isNotEmpty && (t == null || t < 25 || t > 300)) {
    if (context.mounted) showToast(context, 'Masukkan berat 25–300 kg');
    return;
  }
  if (t != null && t < lo) {
    if (context.mounted) showToast(context, 'Terlalu rendah — minimal ${kgStr(lo)} kg agar tetap sehat');
    return;
  }
  final goal = t == null ? p.goal : (t < p.kg - .2 ? 'turun' : t > p.kg + .2 ? 'naik' : 'jaga');
  await ref.read(calorieProvider.notifier).updateProfile(BodyProfile(kg: p.kg, cm: p.cm, age: p.age, male: p.male, activity: p.activity, goal: goal, targetKg: t));
  if (context.mounted) showToast(context, t == null ? 'Target dihapus' : 'Target ${kgStr(t)} kg disimpan 🎯');
}
