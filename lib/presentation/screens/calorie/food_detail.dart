import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/calorie_provider.dart';
import '../../../services/calorie_logic.dart';
import '../../widgets/common.dart';
import 'calorie_add.dart' show MealPicker;
import 'calorie_screen.dart';

/// Acuan label gizi BPOM (2150 kkal): lemak total 67 g, karbohidrat total 325 g, protein 60 g.
const akgKcal = 2150.0, akgFat = 67.0, akgCarb = 325.0, akgProt = 60.0;

class FoodDetailResult {
  const FoodDetailResult(this.qty, this.meal, {this.delete = false});
  final double qty;
  final String meal;
  final bool delete;
}

/// Lembar detail makanan: pilih porsi/gram, lihat kalori, lemak, karbo, protein & %AKG.
Future<FoodDetailResult?> showFoodDetail(BuildContext context, FoodItem f,
    {required String meal, double qty = 1, bool editing = false, String action = 'Tambah'}) {
  return showModalBottomSheet<FoodDetailResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FoodDetail(food: f, meal: meal, qty: qty, editing: editing, action: action),
  );
}

class _FoodDetail extends ConsumerStatefulWidget {
  const _FoodDetail({required this.food, required this.meal, required this.qty, required this.editing, required this.action});
  final FoodItem food;
  final String meal, action;
  final double qty;
  final bool editing;
  @override
  ConsumerState<_FoodDetail> createState() => _FoodDetailState();
}

class _FoodDetailState extends ConsumerState<_FoodDetail> {
  late double _qty = widget.qty;
  late String _meal = widget.meal;
  bool _gram = false;
  late final _gC = TextEditingController(text: _fmtG(widget.food.gram * widget.qty));

  FoodItem get f => widget.food;
  bool get _hasGram => f.gram > 0;
  double get _grams => f.gram * _qty;

  static String _fmtG(double g) => g == g.roundToDouble() ? '${g.round()}' : g.toStringAsFixed(1).replaceAll('.', ',');

  void _setGram(double g) {
    if (!_hasGram || g <= 0) return;
    setState(() => _qty = g / f.gram);
  }

  @override
  void dispose() {
    _gC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kcal = f.kcal * _qty, p = f.protein * _qty, c = f.carbs * _qty, fat = f.fat * _qty;
    final ek = p * 4 + c * 4 + fat * 9;
    final target = ref.watch(calorieProvider).target?.target.toDouble();
    final cat = foodCategories[f.cat] ?? (f.cat == 'kemasan' ? 'Produk kemasan' : f.cat == 'foto' ? 'Dari foto (perkiraan AI)' : 'Makanan');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          // ---- kepala
          Row(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: kKal.withValues(alpha: .1), borderRadius: BorderRadius.circular(18)),
              alignment: Alignment.center,
              child: Text(f.emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 3),
                Text('$cat · ${f.portion}${_hasGram ? ' (${_fmtG(f.gram)} g)' : ''}', style: TextStyle(color: context.muted, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          MealPicker(meal: _meal, onChanged: (v) => setState(() => _meal = v)),
          const SizedBox(height: 14),
          // ---- jumlah
          if (_hasGram)
            SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(selectedBackgroundColor: kKal.withValues(alpha: .15), selectedForegroundColor: const Color(0xFFC2410C)),
              segments: const [
                ButtonSegment(value: false, label: Text('Porsi'), icon: Icon(Icons.restaurant_rounded, size: 18)),
                ButtonSegment(value: true, label: Text('Gram'), icon: Icon(Icons.scale_rounded, size: 18)),
              ],
              selected: {_gram},
              onSelectionChanged: (v) => setState(() {
                _gram = v.first;
                _gC.text = _fmtG(_grams);
              }),
            ),
          const SizedBox(height: 12),
          if (_gram && _hasGram) ...[
            TextField(
              controller: _gC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              decoration: InputDecoration(suffixText: 'gram', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
              onChanged: (v) => _setGram(double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              for (final g in const [50, 100, 150, 200, 250])
                ChoiceChip(
                  label: Text('$g g'),
                  selected: (_grams - g).abs() < .5,
                  selectedColor: kKal.withValues(alpha: .18),
                  onSelected: (_) {
                    _gC.text = '$g';
                    _setGram(g.toDouble());
                  },
                ),
            ]),
          ] else
            QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v), unit: _hasGram ? '${f.portion} · ${_fmtG(_grams)} g' : f.portion),
          const SizedBox(height: 16),
          // ---- kalori + makro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: kKalGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtKcal(kcal), style: accentFont(size: 40, color: Colors.white)),
                const Padding(padding: EdgeInsets.only(bottom: 8, left: 6), child: Text('kkal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                const Spacer(),
                if (target != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${(kcal / target * 100).round()}% target harian', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ),
              ]),
              const SizedBox(height: 10),
              // komposisi energi
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 10,
                  child: ek <= 0
                      ? Container(color: Colors.white24)
                      : Row(children: [
                          if (p > 0) Expanded(flex: math.max(1, (p * 4 / ek * 1000).round()), child: Container(color: const Color(0xFFC7D2FE))),
                          if (c > 0) Expanded(flex: math.max(1, (c * 4 / ek * 1000).round()), child: Container(color: const Color(0xFFFDE68A))),
                          if (fat > 0) Expanded(flex: math.max(1, (fat * 9 / ek * 1000).round()), child: Container(color: const Color(0xFFA7F3D0))),
                        ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _Macro('Protein', p, ek <= 0 ? 0 : p * 4 / ek, const Color(0xFFC7D2FE)),
                const SizedBox(width: 8),
                _Macro('Karbohidrat', c, ek <= 0 ? 0 : c * 4 / ek, const Color(0xFFFDE68A)),
                const SizedBox(width: 8),
                _Macro('Lemak', fat, ek <= 0 ? 0 : fat * 9 / ek, const Color(0xFFA7F3D0)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // ---- informasi nilai gizi
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(border: Border.all(color: context.ink, width: 1.6), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('INFORMASI NILAI GIZI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: .4)),
              const SizedBox(height: 2),
              Text('Takaran saji: ${fmtQty(_qty)} × ${f.portion}${_hasGram ? ' (${_fmtG(_grams)} g)' : ''}', style: TextStyle(color: context.muted, fontSize: 12.5)),
              Divider(thickness: 6, height: 18, color: context.ink),
              Row(children: [
                const Expanded(child: Text('Energi total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                Text('${fmtKcal(kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ]),
              Row(children: [
                Expanded(child: Text('Energi dari lemak', style: TextStyle(color: context.muted, fontSize: 13))),
                Text('${fmtKcal(fat * 9)} kkal', style: TextStyle(color: context.muted, fontSize: 13)),
              ]),
              Divider(thickness: 1.4, height: 16, color: context.ink),
              Align(alignment: Alignment.centerRight, child: Text('% AKG*', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: context.muted))),
              _NutRow('Lemak total', fat, akgFat, bold: true),
              _NutRow('Karbohidrat total', c, akgCarb, bold: true),
              _NutRow('Protein', p, akgProt, bold: true),
              Divider(thickness: 1.4, height: 16, color: context.ink),
              Text('*Persen AKG berdasarkan kebutuhan energi 2150 kkal. Kebutuhanmu bisa lebih tinggi atau lebih rendah. '
                  '${f.cat == 'foto' ? 'Nilai dari foto adalah perkiraan AI.' : 'Nilai rata-rata, bisa berbeda tergantung resep & porsi.'}',
                  style: TextStyle(fontSize: 11, color: context.faint, height: 1.35)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.editing) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE11D48), padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: () => Navigator.pop(context, FoodDetailResult(_qty, _meal, delete: true)),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _qty > 0 ? () => Navigator.pop(context, FoodDetailResult(double.parse(_qty.toStringAsFixed(3)), _meal)) : null,
                child: Text('${widget.action} · ${fmtKcal(kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.g, this.share, this.dot);
  final String label;
  final double g, share;
  final Color dot;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 4),
            Text('${g < 10 ? g.toStringAsFixed(1).replaceAll('.', ',') : g.round()} g', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${(share * 100).round()}% energi', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11)),
          ]),
        ),
      );
}

class _NutRow extends StatelessWidget {
  const _NutRow(this.label, this.g, this.ref, {this.bold = false});
  final String label;
  final double g, ref;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
              TextSpan(text: '  ${g < 10 ? g.toStringAsFixed(1).replaceAll('.', ',') : g.round()} g'),
            ])),
          ),
          Text('${(g / ref * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
