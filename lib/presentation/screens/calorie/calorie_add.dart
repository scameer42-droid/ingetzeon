import 'dart:async';
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
import 'food_detail.dart';

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
  await showAppSheet(
    context: context,
    scroll: false,
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
        subtitle: Text('${f.portion}${f.gram > 0 ? ' (${fmtQty(f.gram)} g)' : ''}  ·  P ${fmtQty(f.protein)} · K ${fmtQty(f.carbs)} · L ${fmtQty(f.fat)} g',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('${fmtKcal(f.kcal)} kkal', style: const TextStyle(fontWeight: FontWeight.w800, color: kKal)),
      );
}

Future<void> _pick(BuildContext sheetCtx, WidgetRef ref, FoodItem f, String meal, DateTime day) async {
  final r = await showFoodDetail(sheetCtx, f, meal: meal);
  if (r == null) return;
  await ref.read(calorieProvider.notifier).add(r.meal, [(food: f, qty: r.qty)], day: day);
  if (sheetCtx.mounted) {
    Navigator.pop(sheetCtx);
    showToast(sheetCtx, '${f.emoji} ${f.name} +${fmtKcal(f.kcal * r.qty)} kkal → ${mealNames[r.meal]}');
  }
}

/// ---------- Input manual ----------
Future<void> manualFood(BuildContext context, WidgetRef ref, {required String meal, required DateTime day, String name = '', String? barcode}) async {
  final nameC = TextEditingController(text: name);
  final kcalC = TextEditingController();
  final porC = TextEditingController(text: barcode != null ? '1 kemasan' : '1 porsi');
  var m = meal;
  await showAppSheet(
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
  String? usedPath = path;
  if (path != null) {
    bytes = await XFile(path).readAsBytes();
  } else {
    final src = await showAppSheet<ImageSource>(
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
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, maxWidth: 800, maxHeight: 800, imageQuality: 75);
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final denied = e.code.contains('denied') || e.code.contains('access');
      await _scanProblem(context, ref,
          meal: meal,
          day: day,
          title: denied ? 'Izin kamera ditolak' : 'Kamera tidak bisa dibuka',
          msg: denied
              ? 'Buka Pengaturan HP → Aplikasi → IngetZeon → Izin → Kamera → Izinkan. Atau pilih foto dari galeri.'
              : 'Kamera sedang dipakai aplikasi lain atau bermasalah (${e.code}). Coba lagi, atau pilih foto dari galeri.');
      return;
    }
    if (x == null) {
      // di beberapa HP aplikasi dimuat ulang saat kamera terbuka — ambil foto yang tertinggal
      final lost = await ImagePicker().retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;
      x = lost.file;
    }
    final file = x!;
    usedPath = file.path;
    bytes = await file.readAsBytes();
  }
  if (!context.mounted) return;
  ({List<Map<String, dynamic>> items, String note})? res;
  String? err;
  var cancelled = false;
  try {
    res = await runWithWait(context, 'AI sedang mengenali makananmu… 🍽️',
        () => ref.read(aiServiceProvider).scanFood(bytes, apiKey: settings.apiKey, model: settings.model));
    cancelled = res == null;
  } catch (e) {
    err = AiService.scanErrorText(e);
  }
  if (!context.mounted || cancelled) return;
  if (err != null || res == null) {
    await _scanProblem(context, ref, meal: meal, day: day, title: 'AI belum berhasil', msg: err ?? 'Gagal memindai', retryPath: usedPath);
    return;
  }
  if (res.items.isEmpty) {
    await _scanProblem(context, ref, meal: meal, day: day, title: 'Makanan tidak terlihat', msg: res.note.isNotEmpty ? res.note : 'Coba foto makanannya dari atas, lebih dekat dan terang.');
    return;
  }
  double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  final foods = [
    for (final x in res.items)
      FoodItem(foodEmoji('${x['name']}'), '${x['name']}', const [], '${x['portion'] ?? '1 porsi'}', d(x['gram']), d(x['kcal']), d(x['protein']), d(x['carbs']), d(x['fat']), 'foto'),
  ];
  await reviewFoods(context, ref, foods: foods, meal: meal, day: day, source: 'foto', title: 'Hasil pindai foto', note: res.note);
}

/// Jalankan [job] sambil menampilkan layar tunggu (detik berjalan + tombol Batal). Hasil null = dibatalkan.
Future<T?> runWithWait<T extends Object>(BuildContext context, String msg, Future<T> Function() job) async {
  var cancelled = false;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WaitDialog(
      msg: msg,
      onCancel: () {
        cancelled = true;
        nav.pop();
      },
    ),
  );
  try {
    final r = await job();
    if (cancelled) return null;
    nav.pop();
    return r;
  } catch (e) {
    if (cancelled) return null;
    nav.pop();
    rethrow;
  }
}

class _WaitDialog extends StatefulWidget {
  const _WaitDialog({required this.msg, required this.onCancel});
  final String msg;
  final VoidCallback onCancel;
  @override
  State<_WaitDialog> createState() => _WaitDialogState();
}

class _WaitDialogState extends State<_WaitDialog> {
  final _sw = Stopwatch()..start();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _sw.elapsed.inSeconds;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 6),
          const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: kKal, strokeWidth: 4)),
          const SizedBox(height: 16),
          Text(widget.msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(s < 15 ? 'Biasanya 5–15 detik · $s dtk' : 'Internet agak lambat, sebentar lagi… · $s dtk', textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12.5)),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [TextButton(onPressed: widget.onCancel, child: const Text('Batal'))],
      ),
    );
  }
}

/// Dialog saat pindai gagal: alasan jelas + jalan keluar.
Future<void> _scanProblem(BuildContext context, WidgetRef ref,
    {required String meal, required DateTime day, required String title, required String msg, String? retryPath}) async {
  final act = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Text('📷', style: TextStyle(fontSize: 34)),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'manual'), child: const Text('Cari manual')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kKal), onPressed: () => Navigator.pop(ctx, 'retry'), child: const Text('Coba lagi')),
      ],
    ),
  );
  if (!context.mounted) return;
  if (act == 'retry') await scanFoodPhoto(context, ref, meal: meal, day: day, path: retryPath);
  if (act == 'manual') await showAddFood(context, ref, meal: meal, day: day);
}

/// Daftar hasil (foto/chat) yang bisa diubah sebelum disimpan.
Future<void> reviewFoods(BuildContext context, WidgetRef ref,
    {required List<FoodItem> foods, required String meal, required DateTime day, required String source, required String title, String note = '', List<double>? qtys}) async {
  final q = qtys ?? List<double>.filled(foods.length, 1);
  final on = List<bool>.filled(foods.length, true);
  var m = meal;
  await showAppSheet(
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
                      subtitle: Text('${foods[i].portion}${foods[i].gram > 0 ? ' · ±${fmtQty(foods[i].gram * q[i])} g' : ''}\n'
                          'P ${(foods[i].protein * q[i]).round()} g · K ${(foods[i].carbs * q[i]).round()} g · L ${(foods[i].fat * q[i]).round()} g'),
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
  for (final c in PackFood.codeVariants(code)) {
    final res = await http.get(
      Uri.parse('https://world.openfoodfacts.org/api/v2/product/$c.json?fields=product_name,product_name_id,generic_name,brands,nutriments,serving_size,serving_quantity'),
      headers: {'User-Agent': 'IngetZeon/1.0 (aplikasi pengingat)'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) continue;
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is Map && data['status'] == 1 && data['product'] is Map) {
      final p = PackFood.fromOff(data['product'] as Map);
      if (p != null) return p;
    }
  }
  return null;
}

void _busy(BuildContext context, String msg) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(content: Row(children: [const CircularProgressIndicator(color: kKal), const SizedBox(width: 18), Expanded(child: Text(msg))])),
    );

void _unbusy(BuildContext context) => Navigator.of(context, rootNavigator: true).pop();

/// Barcode → database Open Food Facts → AI cari di internet → foto kemasan (AI baca). Semua otomatis.
Future<void> lookupBarcode(BuildContext context, WidgetRef ref, String code, {required String meal, required DateTime day}) async {
  final known = ref.read(calorieProvider).barcodes[code];
  if (known != null) {
    final r = await showFoodDetail(context, known, meal: meal);
    if (r == null) return;
    await ref.read(calorieProvider.notifier).add(r.meal, [(food: known, qty: r.qty)], day: day, source: 'barcode');
    if (context.mounted) showToast(context, '📦 ${known.name} +${fmtKcal(known.kcal * r.qty)} kkal → ${mealNames[r.meal]}');
    return;
  }
  final settings = ref.read(settingsProvider);
  _busy(context, 'Mencari produk di database…');
  PackFood? p;
  try {
    p = await fetchOpenFoodFacts(code);
  } catch (_) {}
  if (p == null && settings.hasAi) {
    if (context.mounted) {
      _unbusy(context);
      _busy(context, 'Belum ada di database — AI mencari produk ini di internet… 🔎');
    }
    try {
      final d = await ref.read(aiServiceProvider).lookupBarcode(code, apiKey: settings.apiKey, model: settings.model);
      if (d != null) p = PackFood.fromAi(d);
    } catch (_) {}
  }
  if (!context.mounted) return;
  _unbusy(context);
  if (p != null) {
    await _packSheet(context, ref, code, p, meal: meal, day: day);
    return;
  }
  if (!settings.hasAi) {
    await manualFood(context, ref, meal: meal, day: day, barcode: code);
    return;
  }
  // terakhir: foto kemasannya, biar AI yang membaca
  final go = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Text('📦', style: TextStyle(fontSize: 34)),
      title: const Text('Produk belum dikenal', textAlign: TextAlign.center),
      content: const Text('Foto kemasannya (bagian label "Informasi Nilai Gizi" paling bagus), nanti AI membaca nama & kalorinya otomatis. Lain kali cukup pindai barcode.',
          textAlign: TextAlign.center, style: TextStyle(height: 1.45)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'manual'), child: const Text('Isi manual')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kKal),
          onPressed: () => Navigator.pop(ctx, 'foto'),
          icon: const Icon(Icons.photo_camera_rounded),
          label: const Text('Foto kemasan'),
        ),
      ],
    ),
  );
  if (!context.mounted || go == null) return;
  if (go == 'manual') {
    await manualFood(context, ref, meal: meal, day: day, barcode: code);
    return;
  }
  await _readPackPhoto(context, ref, code, meal: meal, day: day);
}

Future<void> _readPackPhoto(BuildContext context, WidgetRef ref, String code, {required String meal, required DateTime day}) async {
  XFile? x;
  try {
    x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
  } on PlatformException {
    x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
  }
  if (x == null) {
    final lost = await ImagePicker().retrieveLostData();
    x = lost.file;
  }
  if (x == null || !context.mounted) return;
  final bytes = await x.readAsBytes();
  if (!context.mounted) return;
  final settings = ref.read(settingsProvider);
  PackFood? p;
  String? err;
  try {
    final d = await runWithWait(context, 'AI sedang membaca kemasan… 📦',
        () => ref.read(aiServiceProvider).readPackage(bytes, apiKey: settings.apiKey, model: settings.model).then((v) => v ?? const <String, dynamic>{}));
    if (d == null) return; // dibatalkan
    if (d.isNotEmpty) p = PackFood.fromAi(d);
  } catch (e) {
    err = AiService.scanErrorText(e);
  }
  if (!context.mounted) return;
  if (p == null) {
    showToast(context, err ?? 'Kemasan belum terbaca — isi manual dulu ya');
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
  await showAppSheet(
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
          Text(p.ai ? 'Dibaca/dicari oleh AI — angka bisa sedikit berbeda dari label asli' : 'Data gizi dari Open Food Facts', textAlign: TextAlign.center, style: TextStyle(color: ctx.faint, fontSize: 11.5)),
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
