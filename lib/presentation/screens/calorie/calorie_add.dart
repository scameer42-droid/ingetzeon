import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/calorie_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/calorie_logic.dart';
import '../../widgets/common.dart';
import 'calorie_screen.dart';

/// Pilih waktu makan (chip).
class MealPicker extends StatelessWidget {
  const MealPicker({super.key, required this.meal, required this.onChanged});
  final String meal;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final m in mealKeys)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${mealEmoji[m]} ${mealNames[m]}'),
                selected: meal == m,
                selectedColor: kKal.withValues(alpha: .18),
                onSelected: (_) => onChanged(m),
              ),
            ),
        ]),
      );
}

/// ---------- Cari & tambah makanan ----------
Future<void> showAddFood(BuildContext context, WidgetRef ref, {required String meal, required DateTime day}) async {
  var q = '';
  var cat = '';
  var m = meal;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final s = ref.read(calorieProvider);
      final custom = s.barcodes.values.toList();
      var list = q.isEmpty && cat.isEmpty ? <FoodItem>[] : FoodSearch.search(q, extra: custom);
      if (cat.isNotEmpty) list = (q.isEmpty ? foodDb : list).where((f) => f.cat == cat).toList();
      final showRecent = q.isEmpty && cat.isEmpty;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .86,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tambah makanan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                MealPicker(meal: m, onChanged: (v) => setS(() => m = v)),
                const SizedBox(height: 8),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setS(() => q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Cari: nasi goreng, bakso, teh manis…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _Act('📷 Foto', () {
                    Navigator.pop(ctx);
                    scanFoodPhoto(context, ref, meal: m, day: day);
                  }),
                  const SizedBox(width: 8),
                  _Act('▦ Barcode', () {
                    Navigator.pop(ctx);
                    scanBarcode(context, ref, meal: m, day: day);
                  }),
                  const SizedBox(width: 8),
                  _Act('✏️ Manual', () {
                    Navigator.pop(ctx);
                    manualFood(context, ref, meal: m, day: day, name: q);
                  }),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final e in foodCategories.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(e.value, style: const TextStyle(fontSize: 12)),
                          selected: cat == e.key,
                          onSelected: (v) => setS(() => cat = v ? e.key : ''),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 16), children: [
                if (showRecent) ...[
                  if (s.recent.isNotEmpty) _label(ctx, 'Terakhir kamu makan'),
                  for (final f in s.recent) _FoodRow(f, onTap: () => _pick(ctx, ref, f, m, day)),
                  _label(ctx, 'Makanan populer'),
                  for (final f in foodDb.take(30)) _FoodRow(f, onTap: () => _pick(ctx, ref, f, m, day)),
                ] else if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text('"$q" belum ada di daftar.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Tambahkan manual, atau foto makanannya biar AI yang menghitung.', textAlign: TextAlign.center, style: TextStyle(color: ctx.muted)),
                    ]),
                  )
                else
                  for (final f in list.take(60)) _FoodRow(f, onTap: () => _pick(ctx, ref, f, m, day)),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
}

Widget _label(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: c.muted)),
    );

class _Act extends StatelessWidget {
  const _Act(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      );
}

class _FoodRow extends StatelessWidget {
  const _FoodRow(this.f, {required this.onTap});
  final FoodItem f;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        onTap: onTap,
        leading: Text(f.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        subtitle: Text('${f.portion}${f.gram > 0 ? ' (${fmtQty(f.gram)} g)' : ''}'),
        trailing: Text('${fmtKcal(f.kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w800, color: kKal)),
      );
}

Future<void> _pick(BuildContext sheetCtx, WidgetRef ref, FoodItem f, String meal, DateTime day) async {
  final q = await askQty(sheetCtx, f);
  if (q == null) return;
  await ref.read(calorieProvider.notifier).add(meal, [(food: f, qty: q)], day: day);
  if (sheetCtx.mounted) {
    Navigator.pop(sheetCtx);
    showToast(sheetCtx, '${f.emoji} ${f.name} +${fmtKcal(f.kcal * q)} kkal → ${mealNames[meal]}');
  }
}

/// Minta jumlah porsi.
Future<double?> askQty(BuildContext context, FoodItem f, {double initial = 1}) async {
  var q = initial;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('${f.emoji} ${f.name}', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QtyStepper(value: q, onChanged: (v) => setS(() => q = v), unit: f.portion),
          const SizedBox(height: 10),
          Text('${fmtKcal(f.kcal * q)} kkal', style: accentFont(size: 28, color: kKal)),
          Text('P ${(f.protein * q).round()} g · K ${(f.carbs * q).round()} g · L ${(f.fat * q).round()} g', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kKal), onPressed: () => Navigator.pop(ctx, q), child: const Text('Tambah')),
        ],
      ),
    ),
  );
}

/// ---------- Input manual ----------
Future<void> manualFood(BuildContext context, WidgetRef ref, {required String meal, required DateTime day, String name = '', String? barcode}) async {
  final nameC = TextEditingController(text: name);
  final kcalC = TextEditingController();
  final porC = TextEditingController(text: barcode != null ? '1 kemasan' : '1 porsi');
  var m = meal;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(barcode != null ? 'Produk belum dikenal' : 'Tambah manual', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          if (barcode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Barcode $barcode. Lihat "Informasi Nilai Gizi" di kemasan, lalu isi di bawah. Lain kali cukup pindai.',
                  style: TextStyle(color: ctx.muted, height: 1.35)),
            ),
          const SizedBox(height: 12),
          MealPicker(meal: m, onChanged: (v) => setS(() => m = v)),
          const SizedBox(height: 12),
          TextField(controller: nameC, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Nama makanan', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: kcalC,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Kalori', suffixText: 'kkal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: porC, decoration: InputDecoration(labelText: 'Porsi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: () async {
              final k = double.tryParse(kcalC.text.trim());
              if (nameC.text.trim().isEmpty || k == null) {
                showToast(ctx, 'Isi nama & kalorinya dulu');
                return;
              }
              final f = FoodItem(barcode != null ? '📦' : '🍽️', nameC.text.trim(), const [], porC.text.trim().isEmpty ? '1 porsi' : porC.text.trim(), 0, k, 0, 0, 0,
                  barcode != null ? 'kemasan' : 'lain');
              final n = ref.read(calorieProvider.notifier);
              if (barcode != null) await n.saveBarcode(barcode, f);
              await n.add(m, [(food: f, qty: 1)], day: day, source: barcode != null ? 'barcode' : '');
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) showToast(context, '${f.name} +${fmtKcal(k)} kkal → ${mealNames[m]}');
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    ),
  );
}

/// ---------- Pindai foto makanan (Gemini) ----------
Future<void> scanFoodPhoto(BuildContext context, WidgetRef ref, {required String meal, required DateTime day, String? path}) async {
  final settings = ref.read(settingsProvider);
  if (!settings.hasAi) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📷 Pindai makanan'),
        content: const Text(
            'Untuk mengenali makanan dari foto, isi dulu kunci API Gemini (gratis) di Profil → Kunci API Gemini.\n\nSementara itu kamu bisa cari makanan dari daftar atau pindai barcode kemasan.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti'))],
      ),
    );
    return;
  }
  List<int> bytes;
  if (path != null) {
    bytes = await XFile(path).readAsBytes();
  } else {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded, color: kKal), title: const Text('Ambil foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded, color: kKal), title: const Text('Pilih dari galeri'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (x == null) return;
    bytes = await x.readAsBytes();
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [CircularProgressIndicator(color: kKal), SizedBox(width: 18), Expanded(child: Text('AI sedang mengenali makananmu… 🍽️'))]),
    ),
  );
  ({List<Map<String, dynamic>> items, String note})? res;
  String? err;
  try {
    res = await ref.read(aiServiceProvider).scanFood(bytes, apiKey: settings.apiKey, model: settings.model);
  } on AiException catch (e) {
    err = e.status == 401 || e.status == 403 ? 'Kunci API Gemini ditolak. Cek lagi di Profil.' : e.status == -1 ? 'Koneksi lambat — coba lagi.' : 'AI belum bisa membaca foto ini (${e.status}).';
  } catch (_) {
    err = 'Foto belum bisa dikenali. Coba foto lebih dekat dan terang, atau cari manual.';
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (err != null || res == null) {
    showToast(context, err ?? 'Gagal memindai');
    return;
  }
  if (res.items.isEmpty) {
    showToast(context, res.note.isNotEmpty ? res.note : 'Tidak ada makanan yang terlihat di foto');
    return;
  }
  double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  final foods = [
    for (final x in res.items)
      FoodItem(foodEmoji('${x['name']}'), '${x['name']}', const [], '${x['portion'] ?? '1 porsi'}', d(x['gram']), d(x['kcal']), d(x['protein']), d(x['carbs']), d(x['fat']), 'foto'),
  ];
  await reviewFoods(context, ref, foods: foods, meal: meal, day: day, source: 'foto', title: 'Hasil pindai foto', note: res.note);
}

/// Daftar hasil (foto/chat) yang bisa diubah sebelum disimpan.
Future<void> reviewFoods(BuildContext context, WidgetRef ref,
    {required List<FoodItem> foods, required String meal, required DateTime day, required String source, required String title, String note = '', List<double>? qtys}) async {
  final q = qtys ?? List<double>.filled(foods.length, 1);
  final on = List<bool>.filled(foods.length, true);
  var m = meal;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      var total = 0.0;
      for (var i = 0; i < foods.length; i++) {
        if (on[i]) total += foods[i].kcal * q[i];
      }
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .86),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: TextStyle(color: ctx.muted, fontSize: 13))),
            const SizedBox(height: 10),
            MealPicker(meal: m, onChanged: (v) => setS(() => m = v)),
            const SizedBox(height: 6),
            for (var i = 0; i < foods.length; i++)
              Card(
                elevation: 0,
                color: on[i] ? kKal.withValues(alpha: .06) : ctx.card2,
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                  child: Column(children: [
                    CheckboxListTile(
                      dense: true,
                      value: on[i],
                      activeColor: kKal,
                      onChanged: (v) => setS(() => on[i] = v ?? true),
                      title: Text(foods[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${foods[i].portion}${foods[i].gram > 0 ? ' · ±${fmtQty(foods[i].gram)} g' : ''}'),
                      secondary: Text('${fmtKcal(foods[i].kcal * q[i])}\nkkal', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: kKal)),
                    ),
                    if (on[i]) QtyStepper(value: q[i], onChanged: (v) => setS(() => q[i] = v), unit: foods[i].portion),
                  ]),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: total <= 0 && !on.contains(true)
                  ? null
                  : () async {
                      await ref.read(calorieProvider.notifier).add(m, [
                        for (var i = 0; i < foods.length; i++)
                          if (on[i]) (food: foods[i], qty: q[i]),
                      ], day: day, source: source);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) showToast(context, '✅ ${fmtKcal(total)} kkal dicatat ke ${mealNames[m]}');
                    },
              child: Text('Simpan ${fmtKcal(total)} kkal', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Text('Perkiraan AI — sesuaikan porsinya bila perlu.', textAlign: TextAlign.center, style: TextStyle(color: ctx.faint, fontSize: 12)),
          ]),
        ),
      );
    }),
  );
}

/// ---------- Pindai barcode kemasan ----------
Future<void> scanBarcode(BuildContext context, WidgetRef ref, {required String meal, required DateTime day}) async {
  final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScreen()));
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  await lookupBarcode(context, ref, code.trim(), meal: meal, day: day);
}

Future<PackFood?> fetchOpenFoodFacts(String code) async {
  final res = await http.get(
    Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,product_name_id,generic_name,brands,nutriments,serving_size,serving_quantity'),
    headers: {'User-Agent': 'IngetZeon/1.0 (aplikasi pengingat)'},
  ).timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  final data = jsonDecode(utf8.decode(res.bodyBytes));
  if (data is! Map || data['status'] != 1 || data['product'] is! Map) return null;
  return PackFood.fromOff(data['product'] as Map);
}

Future<void> lookupBarcode(BuildContext context, WidgetRef ref, String code, {required String meal, required DateTime day}) async {
  final known = ref.read(calorieProvider).barcodes[code];
  if (known != null) {
    final q = await askQty(context, known);
    if (q == null) return;
    await ref.read(calorieProvider.notifier).add(meal, [(food: known, qty: q)], day: day, source: 'barcode');
    if (context.mounted) showToast(context, '📦 ${known.name} +${fmtKcal(known.kcal * q)} kkal → ${mealNames[meal]}');
    return;
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(color: kKal), SizedBox(width: 18), Expanded(child: Text('Mencari produk…'))])),
  );
  PackFood? p;
  var failed = false;
  try {
    p = await fetchOpenFoodFacts(code);
  } catch (_) {
    failed = true;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (p == null) {
    if (failed) showToast(context, 'Database produk tidak bisa dihubungi — isi manual dulu ya');
    await manualFood(context, ref, meal: meal, day: day, barcode: code);
    return;
  }
  await _packSheet(context, ref, code, p, meal: meal, day: day);
}

Future<void> _packSheet(BuildContext context, WidgetRef ref, String code, PackFood p, {required String meal, required DateTime day}) async {
  final food = p.toFood();
  var useGram = p.serving == null;
  var serv = 1.0;
  final gC = TextEditingController(text: '${(p.serving ?? 100).round()}');
  var m = meal;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final g = double.tryParse(gC.text.replaceAll(',', '.')) ?? 0;
      final kcal = useGram ? p.kcal100 * g / 100 : food.kcal * serv;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('📦 ${p.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${fmtKcal(p.kcal100)} kkal per 100 g/ml${p.serving != null ? ' · 1 sajian ${fmtQty(p.serving!)} g = ${fmtKcal(food.kcal)} kkal' : ''}',
              style: TextStyle(color: ctx.muted)),
          const SizedBox(height: 12),
          MealPicker(meal: m, onChanged: (v) => setS(() => m = v)),
          const SizedBox(height: 12),
          if (p.serving != null)
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Per sajian')), ButtonSegment(value: true, label: Text('Gram / ml'))],
              selected: {useGram},
              onSelectionChanged: (v) => setS(() => useGram = v.first),
            ),
          const SizedBox(height: 12),
          if (useGram)
            TextField(
              controller: gC,
              keyboardType: TextInputType.number,
              onChanged: (_) => setS(() {}),
              decoration: InputDecoration(labelText: 'Jumlah dimakan/diminum', suffixText: 'g/ml', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            )
          else
            QtyStepper(value: serv, onChanged: (v) => setS(() => serv = v), unit: 'sajian (${p.servingLabel.isNotEmpty ? p.servingLabel : '${fmtQty(p.serving ?? 100)} g'})'),
          const SizedBox(height: 10),
          Text('${fmtKcal(kcal)} kkal', textAlign: TextAlign.center, style: accentFont(size: 30, color: kKal)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kKal, padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: kcal <= 0
                ? null
                : () async {
                    final n = ref.read(calorieProvider.notifier);
                    await n.saveBarcode(code, food);
                    final qty = useGram ? g / food.gram : serv;
                    await n.add(m, [(food: food, qty: double.parse(qty.toStringAsFixed(2)))], day: day, source: 'barcode');
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) showToast(context, '📦 +${fmtKcal(kcal)} kkal → ${mealNames[m]}');
                  },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Text('Data gizi dari Open Food Facts', textAlign: TextAlign.center, style: TextStyle(color: ctx.faint, fontSize: 11.5)),
        ]),
      );
    }),
  );
}

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});
  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _ctrl = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, code);
  }

  Future<void> _type() async {
    final v = await inputDialog(context, title: 'Ketik nomor barcode', hint: 'mis. 8996001600146');
    final c = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (c.length >= 8) _finish(c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Pindai barcode'),
        actions: [IconButton(onPressed: () => _ctrl.toggleTorch(), icon: const Icon(Icons.flashlight_on_rounded))],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            for (final b in cap.barcodes) {
              final v = b.rawValue;
              if (v != null && RegExp(r'^\d{8,14}$').hasMatch(v)) {
                _finish(v);
                return;
              }
            }
          },
          errorBuilder: (ctx, e) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Kamera tidak bisa dibuka (${e.errorCode.name}). Izinkan kamera di pengaturan, atau ketik nomor barcode.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(18)),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(children: [
            const Text('Arahkan kamera ke barcode di kemasan', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: _type,
              icon: const Icon(Icons.keyboard_rounded),
              label: const Text('Ketik nomor barcode'),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Dipakai oleh chat: konfirmasi makanan dari kalimat.
Future<void> reviewFoodLog(BuildContext context, WidgetRef ref, FoodLog log) => reviewFoods(context, ref,
    foods: [for (final x in log.items) x.food], qtys: [for (final x in log.items) x.qty], meal: log.meal, day: DateTime.now(), source: 'chat', title: 'Catat makanan');
