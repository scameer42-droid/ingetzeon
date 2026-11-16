import 'dart:math' as math;

import 'calorie_data.dart';

export 'calorie_data.dart';

/// Logika kalori — sinkron dengan versi web (website/index.html, bagian KALORI).

const mealKeys = ['pagi', 'siang', 'sore', 'malam'];
const mealNames = {'pagi': 'Sarapan', 'siang': 'Makan siang', 'sore': 'Makan sore', 'malam': 'Makan malam'};
const mealEmoji = {'pagi': '🌅', 'siang': '☀️', 'sore': '🌇', 'malam': '🌙'};
const activityLevels = <({double f, String name, String desc})>[
  (f: 1.2, name: 'Jarang bergerak', desc: 'Kerja duduk, jarang olahraga'),
  (f: 1.375, name: 'Ringan', desc: 'Olahraga 1–3x seminggu'),
  (f: 1.55, name: 'Sedang', desc: 'Olahraga 3–5x seminggu'),
  (f: 1.725, name: 'Aktif', desc: 'Olahraga 6–7x seminggu'),
  (f: 1.9, name: 'Sangat aktif', desc: 'Kerja fisik berat / atlet'),
];
const goals = <({String key, String name, String emoji})>[
  (key: 'turun', name: 'Turun berat', emoji: '📉'),
  (key: 'jaga', name: 'Jaga berat', emoji: '⚖️'),
  (key: 'naik', name: 'Naik berat', emoji: '📈'),
];

String mealByHour(int h) => h < 10 ? 'pagi' : h < 15 ? 'siang' : h < 18 ? 'sore' : 'malam';
double _r1(double x) => (x * 10).round() / 10;

class BodyProfile {
  const BodyProfile({required this.kg, required this.cm, required this.age, required this.male, required this.activity, required this.goal, this.targetKg});
  final double kg, cm;
  final int age;
  final bool male;
  final double activity;
  final String goal; // turun | jaga | naik
  final double? targetKg;

  Map<String, dynamic> toMap() => {'kg': kg, 'cm': cm, 'age': age, 'male': male, 'act': activity, 'goal': goal, 'target': targetKg};
  static BodyProfile? fromMap(dynamic m) {
    if (m is! Map || m['kg'] == null) return null;
    return BodyProfile(
      kg: (m['kg'] as num).toDouble(),
      cm: (m['cm'] as num).toDouble(),
      age: (m['age'] as num).toInt(),
      male: m['male'] == true,
      activity: (m['act'] as num?)?.toDouble() ?? 1.2,
      goal: '${m['goal'] ?? 'jaga'}',
      targetKg: (m['target'] as num?)?.toDouble(),
    );
  }

  BodyProfile withWeight(double v) => BodyProfile(kg: v, cm: cm, age: age, male: male, activity: activity, goal: goal, targetKg: targetKg);
}

class CalorieTarget {
  const CalorieTarget({required this.target, required this.tdee, required this.bmr, required this.goal, required this.note, required this.protein, required this.carbs, required this.fat});
  final int target, tdee, bmr, protein, carbs, fat;
  final String goal, note;
}

class Body {
  static double bmi(double kg, double cm) {
    final m = cm / 100;
    return kg / (m * m);
  }

  /// Kategori BMI Kemenkes: (label, warna ARGB).
  static (String, int) bmiLabel(double b) => b < 18.5
      ? ('Kurus', 0xFF0EA5E9)
      : b <= 25
          ? ('Normal', 0xFF10B981)
          : b <= 27
              ? ('Gemuk', 0xFFF59E0B)
              : ('Obesitas', 0xFFE11D48);

  static (double, double) healthyRange(double cm) {
    final m = cm / 100;
    return (_r1(18.5 * m * m), _r1(25 * m * m));
  }

  static double bmr(BodyProfile p) => 10 * p.kg + 6.25 * p.cm - 5 * p.age + (p.male ? 5 : -161);

  static CalorieTarget target(BodyProfile p) {
    final bmr = Body.bmr(p), tdee = bmr * p.activity;
    final floor = p.male ? 1500.0 : 1200.0;
    var t = tdee;
    var note = '';
    var goal = p.goal;
    if (p.age < 18) {
      goal = 'jaga';
      note = 'Untuk usia di bawah 18 tahun target tidak dikurangi — atur pola makan bersama dokter atau ahli gizi ya.';
    } else if (p.goal == 'turun') {
      if (bmi(p.kg, p.cm) < 18.5) {
        goal = 'jaga';
        note = 'BMI kamu sudah di bawah normal, jadi menurunkan berat tidak disarankan. Target diatur untuk menjaga berat.';
      } else {
        t = tdee - 500;
        if (t < floor) {
          t = floor;
          note = 'Target dibatasi minimal ${fmtKcal(floor)} kkal supaya tubuh tetap sehat.';
        }
      }
    } else if (p.goal == 'naik') {
      t = tdee + 300;
    }
    final r = (t / 10).round() * 10;
    return CalorieTarget(
      target: r,
      tdee: tdee.round(),
      bmr: bmr.round(),
      goal: goal,
      note: note,
      protein: (r * .2 / 4).round(),
      carbs: (r * .5 / 4).round(),
      fat: (r * .3 / 9).round(),
    );
  }

  static int weeksToTarget(double kg, double? target) => target == null ? 0 : ((kg - target).abs() / 0.5).ceil();
}

String fmtKcal(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1).replaceAll('.', ',');

String normFood(String s) => s.toLowerCase().replaceAll(RegExp(r'[-_]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

class FoodSearch {
  static List<FoodItem> search(String q, {List<FoodItem> extra = const []}) {
    final n = normFood(q);
    final all = [...extra, ...foodDb];
    if (n.isEmpty) return all;
    final words = n.split(' ');
    final scored = <(int, FoodItem)>[];
    for (final f in all) {
      final name = normFood(f.name), al = f.alias.map(normFood).toList();
      var s = 0;
      if (name == n || al.contains(n)) {
        s = 10;
      } else if (name.startsWith(n)) {
        s = 6;
      } else if (name.contains(n)) {
        s = 4;
      } else if (al.any((a) => a.contains(n))) {
        s = 3;
      } else if (words.every((w) => name.contains(w) || al.any((a) => a.contains(w)))) {
        s = 2;
      }
      if (s > 0) scored.add((s, f));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final x in scored) x.$2];
  }
}

class FoodLog {
  const FoodLog(this.meal, this.items);
  final String meal;
  final List<({FoodItem food, double qty})> items;
}

/// Memahami kalimat seperti "tadi siang aku makan nasi goreng 2 piring sama es teh".
class FoodParse {
  static const _qtyWord = {'satu': 1.0, 'sebuah': 1.0, 'se': 1.0, 'dua': 2.0, 'tiga': 3.0, 'empat': 4.0, 'lima': 5.0, 'enam': 6.0, 'setengah': .5, 'separuh': .5, '½': .5};
  static const _unit =
      r'(?:piring|mangkok|mangkuk|gelas|cangkir|potong|buah|butir|bungkus|porsi|tusuk|cup|botol|kaleng|lembar|sdm|sendok makan|sendok|sdt|biji|ekor|keping|tongkol|genggam|gram|gr|g)';
  static final _seRe = RegExp(r'\bse(piring|mangkok|mangkuk|gelas|cangkir|potong|buah|butir|bungkus|porsi|tusuk|cup|botol|kaleng|lembar|sendok|biji|ekor|keping|tongkol|genggam)\s*$');
  static final _before = RegExp('(\\d+(?:[.,]\\d+)?|setengah|separuh|½|satu|sebuah|dua|tiga|empat|lima|enam)\\s*($_unit)?\\s*\$');
  static final _after = RegExp('^\\s*(\\d+(?:[.,]\\d+)?|setengah|satu|dua|tiga|empat|lima)\\s*($_unit)\\b');
  static final _letter = RegExp('[a-z]');
  static List<(String, FoodItem)>? _keys;

  static List<(String, FoodItem)> get keys {
    if (_keys != null) return _keys!;
    final k = <(String, FoodItem)>[
      for (final f in foodDb)
        for (final s in [f.name, ...f.alias]) (normFood(s), f),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return _keys = k;
  }

  static double _qty(String numTxt, String? unit, FoodItem food) {
    final q = _qtyWord[numTxt] ?? double.tryParse(numTxt.replaceAll(',', '.')) ?? 1;
    if (q <= 0) return 1;
    final u = (unit ?? '').trim();
    if (RegExp(r'^(gram|gr|g)$').hasMatch(u)) return math.max(.1, q / food.gram);
    final pm = RegExp(r'^(\d+)\s+(.+)$').firstMatch(food.portion);
    if (pm != null && int.parse(pm[1]!) > 1 && u.isNotEmpty && pm[2]!.startsWith(u.substring(0, math.min(4, u.length)))) return q / int.parse(pm[1]!);
    return q;
  }

  static bool _boundary(String t, int i, int j) => !((i > 0 && _letter.hasMatch(t[i - 1])) || (j < t.length && _letter.hasMatch(t[j])));

  static FoodLog? parse(String text, {DateTime? now}) {
    final t = normFood(text);
    if (RegExp(r'\b(ingatkan|ingetin|ingatin|ingetkan|alarm|nanti|besok|mau makan|pengen|ingin|resep|cara)\b').hasMatch(t)) return null;
    if (t.contains('?') || RegExp(r'\b(apa|berapa|kapan|gimana|bagaimana|boleh|enak|sebaiknya)\b').hasMatch(t)) return null;
    if (!RegExp(r'\b(makan|sarapan|minum|ngemil|nyemil|maem|mamam|abis makan|habis makan|nyarap)\b').hasMatch(t)) return null;
    final found = <({FoodItem food, double qty, int at})>[];
    final used = <(int, int)>[];
    for (final (k, f) in keys) {
      var from = 0;
      while (true) {
        final i = t.indexOf(k, from);
        if (i < 0) break;
        from = i + 1;
        final j = i + k.length;
        if (!_boundary(t, i, j)) continue;
        if (used.any((u) => i < u.$2 && j > u.$1)) continue;
        if (k == 'air' && !RegExp(r'\bminum air\b').hasMatch(t)) continue;
        used.add((i, j));
        final before = t.substring(math.max(0, i - 24), i), after = t.substring(j, math.min(t.length, j + 24));
        var qty = 1.0;
        final mb = _before.firstMatch(before);
        if (mb != null) {
          qty = _qty(mb[1]!, mb[2], f);
        } else if (!_seRe.hasMatch(before)) {
          final ma = _after.firstMatch(after);
          if (ma != null) qty = _qty(ma[1]!, ma[2], f);
        }
        found.add((food: f, qty: _r1(qty), at: i));
      }
    }
    if (found.isEmpty) return null;
    found.sort((a, b) => a.at.compareTo(b.at));
    var meal = mealByHour((now ?? DateTime.now()).hour);
    if (RegExp(r'\b(sarapan|nyarap|pagi)\b').hasMatch(t)) {
      meal = 'pagi';
    } else if (RegExp(r'\bsiang\b').hasMatch(t)) {
      meal = 'siang';
    } else if (RegExp(r'\bsore\b').hasMatch(t)) {
      meal = 'sore';
    } else if (RegExp(r'\b(malam|malem)\b').hasMatch(t)) {
      meal = 'malam';
    }
    return FoodLog(meal, [for (final x in found) (food: x.food, qty: x.qty)]);
  }

  /// "berapa kalori nasi goreng" → makanan yang ditanyakan.
  static FoodItem? askCalorie(String text) {
    final t = normFood(text);
    if (!RegExp(r'\b(kalori|kalorinya|kkal|kcal)\b').hasMatch(t)) return null;
    for (final (k, f) in keys) {
      final i = t.indexOf(k);
      if (i >= 0 && _boundary(t, i, i + k.length)) return f;
    }
    return null;
  }

  static bool askToday(String text) => RegExp(
          r'\b(kalori|kkal)\b.*\b(hari ini|sisa|tersisa|sudah|udah|masuk)\b|\bsisa kalori\b|\b(sudah|udah) makan berapa\b|\btarget kalori\b')
      .hasMatch(normFood(text));

  /// "berat badan saya 68,5 kg" → 68.5
  static double? weight(String text) {
    final t = normFood(text);
    if (t.contains('?') || RegExp(r'\b(ideal|berapa|target)\b').hasMatch(t)) return null;
    final m = RegExp(r'\b(?:berat(?: badan)?|bb|timbangan)\b[^\d]{0,24}(\d{2,3}(?:[.,]\d)?)\s*(?:kg|kilo|kilogram)?\b').firstMatch(t);
    if (m == null) return null;
    final v = double.parse(m[1]!.replaceAll(',', '.'));
    return v >= 25 && v <= 300 ? v : null;
  }
}

/// Produk kemasan dari Open Food Facts.
class PackFood {
  const PackFood({required this.name, required this.kcal100, required this.p100, required this.c100, required this.f100, this.serving, this.servingLabel = ''});
  final String name, servingLabel;
  final double kcal100, p100, c100, f100;
  final double? serving; // gram per sajian

  static PackFood? fromOff(Map p) {
    final n = p['nutriments'] is Map ? p['nutriments'] as Map : const {};
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    var kcal = d(n['energy-kcal_100g']);
    if (kcal == null && d(n['energy_100g']) != null) kcal = d(n['energy_100g'])! / 4.184;
    if (kcal == null) return null;
    final brand = '${p['brands'] ?? ''}'.split(',').first.trim();
    final nm = '${p['product_name_id'] ?? ''}'.trim().isNotEmpty ? '${p['product_name_id']}' : '${p['product_name'] ?? p['generic_name'] ?? ''}';
    final name = [nm.trim(), brand].where((s) => s.isNotEmpty).join(' · ');
    final sv = d(p['serving_quantity']);
    return PackFood(
      name: name.isEmpty ? 'Produk kemasan' : name,
      kcal100: _r1(kcal),
      p100: _r1(d(n['proteins_100g']) ?? 0),
      c100: _r1(d(n['carbohydrates_100g']) ?? 0),
      f100: _r1(d(n['fat_100g']) ?? 0),
      serving: sv != null && sv > 0 ? sv : null,
      servingLabel: '${p['serving_size'] ?? ''}',
    );
  }

  /// Dijadikan FoodItem per sajian (atau per 100 g bila sajian tak diketahui).
  FoodItem toFood() {
    final g = serving ?? 100;
    final k = g / 100;
    return FoodItem('📦', name, const [], serving != null ? '1 sajian' : '100 gram', g, _r1(kcal100 * k), _r1(p100 * k), _r1(c100 * k), _r1(f100 * k), 'kemasan');
  }
}

Map<String, dynamic> foodToMap(FoodItem f) =>
    {'e': f.emoji, 'n': f.name, 'a': f.alias, 'po': f.portion, 'g': f.gram, 'k': f.kcal, 'p': f.protein, 'c': f.carbs, 'f': f.fat, 'cat': f.cat};

FoodItem foodFromMap(Map m) {
  double d(dynamic v) => v is num ? v.toDouble() : 0;
  return FoodItem('${m['e'] ?? '🍽️'}', '${m['n'] ?? 'Makanan'}', [for (final a in (m['a'] as List? ?? const [])) '$a'], '${m['po'] ?? '1 porsi'}', d(m['g']), d(m['k']), d(m['p']),
      d(m['c']), d(m['f']), '${m['cat'] ?? 'lain'}');
}
