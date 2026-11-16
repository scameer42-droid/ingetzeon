import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/calorie_logic.dart';
import 'settings_provider.dart';

class FoodEntry {
  const FoodEntry({required this.id, required this.meal, required this.food, required this.qty, required this.at, this.source = ''});
  final String id, meal, source; // source: '', 'foto', 'barcode', 'chat'
  final FoodItem food;
  final double qty;
  final DateTime at;

  double get kcal => food.kcal * qty;
  double get protein => food.protein * qty;
  double get carbs => food.carbs * qty;
  double get fat => food.fat * qty;

  Map<String, dynamic> toMap() => {'id': id, 'm': meal, 'f': foodToMap(food), 'q': qty, 'at': at.millisecondsSinceEpoch, 's': source};
  static FoodEntry fromMap(Map m) => FoodEntry(
        id: '${m['id']}',
        meal: '${m['m'] ?? 'siang'}',
        food: foodFromMap(m['f'] as Map? ?? const {}),
        qty: (m['q'] as num?)?.toDouble() ?? 1,
        at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0),
        source: '${m['s'] ?? ''}',
      );
  FoodEntry withQty(double q) => FoodEntry(id: id, meal: meal, food: food, qty: q, at: at, source: source);
}

class CalorieState {
  const CalorieState({this.profile, this.days = const {}, this.weights = const [], this.barcodes = const {}, this.recent = const []});
  final BodyProfile? profile;
  final Map<String, List<FoodEntry>> days;
  final List<({String day, double kg})> weights; // urut naik
  final Map<String, FoodItem> barcodes; // produk yang pernah dipindai
  final List<FoodItem> recent; // makanan terakhir dicatat

  CalorieTarget? get target => profile == null ? null : Body.target(profile!);
  List<FoodEntry> on(DateTime d) => days[dayKey(d)] ?? const [];
  double kcalOn(DateTime d) => on(d).fold(0.0, (a, e) => a + e.kcal);
  double mealKcal(DateTime d, String meal) => on(d).where((e) => e.meal == meal).fold(0.0, (a, e) => a + e.kcal);
  ({double p, double c, double f}) macrosOn(DateTime d) {
    var p = 0.0, c = 0.0, f = 0.0;
    for (final e in on(d)) {
      p += e.protein;
      c += e.carbs;
      f += e.fat;
    }
    return (p: p, c: c, f: f);
  }

  /// Hari berturut-turut ada catatan makan.
  int get streak {
    var n = 0;
    var d = DateTime.now();
    if (on(d).isEmpty) d = addDays(d, -1);
    while (on(d).isNotEmpty) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  CalorieState copyWith({BodyProfile? profile, Map<String, List<FoodEntry>>? days, List<({String day, double kg})>? weights, Map<String, FoodItem>? barcodes, List<FoodItem>? recent}) =>
      CalorieState(
        profile: profile ?? this.profile,
        days: days ?? this.days,
        weights: weights ?? this.weights,
        barcodes: barcodes ?? this.barcodes,
        recent: recent ?? this.recent,
      );

  Map<String, dynamic> toMap() => {
        'profile': profile?.toMap(),
        'days': {for (final e in days.entries) e.key: [for (final x in e.value) x.toMap()]},
        'weights': [for (final w in weights) [w.day, w.kg]],
        'barcodes': {for (final e in barcodes.entries) e.key: foodToMap(e.value)},
        'recent': [for (final f in recent) foodToMap(f)],
      };

  static CalorieState fromMap(Map m) => CalorieState(
        profile: BodyProfile.fromMap(m['profile']),
        days: {
          for (final e in ((m['days'] as Map?) ?? const {}).entries)
            '${e.key}': [for (final x in (e.value as List? ?? const [])) if (x is Map) FoodEntry.fromMap(x)],
        },
        weights: [
          for (final w in (m['weights'] as List? ?? const []))
            if (w is List && w.length == 2) (day: '${w[0]}', kg: (w[1] as num).toDouble()),
        ],
        barcodes: {for (final e in ((m['barcodes'] as Map?) ?? const {}).entries) '${e.key}': foodFromMap(e.value as Map)},
        recent: [for (final f in (m['recent'] as List? ?? const [])) if (f is Map) foodFromMap(f)],
      );
}

class CalorieNotifier extends Notifier<CalorieState> {
  @override
  CalorieState build() {
    final raw = ref.read(settingsRepositoryProvider).get<String>('calorie', '');
    if (raw.isEmpty) return const CalorieState();
    try {
      return CalorieState.fromMap(jsonDecode(raw) as Map);
    } catch (_) {
      return const CalorieState();
    }
  }

  Future<void> _save(CalorieState s) async {
    state = s;
    await ref.read(settingsRepositoryProvider).set('calorie', jsonEncode(s.toMap()));
  }

  Future<void> setProfile(BodyProfile p) async {
    var s = state.copyWith(profile: p);
    s = _withWeight(s, p.kg);
    await _save(s);
  }

  CalorieState _withWeight(CalorieState s, double kg) {
    final today = dayKey(DateTime.now());
    final w = [...s.weights.where((x) => x.day != today), (day: today, kg: kg)]..sort((a, b) => a.day.compareTo(b.day));
    while (w.length > 365) {
      w.removeAt(0);
    }
    return s.copyWith(weights: w);
  }

  Future<void> logWeight(double kg) async {
    var s = _withWeight(state, kg);
    if (s.profile != null) s = s.copyWith(profile: s.profile!.withWeight(kg));
    await _save(s);
  }

  Future<void> add(String meal, List<({FoodItem food, double qty})> items, {DateTime? day, String source = ''}) async {
    final d = day ?? DateTime.now();
    final key = dayKey(d);
    final now = DateTime.now();
    final at = sameDay(d, now) ? now : DateTime(d.year, d.month, d.day, 12);
    var i = 0;
    final list = [
      ...state.on(d),
      for (final x in items) FoodEntry(id: '${now.microsecondsSinceEpoch}${i++}', meal: meal, food: x.food, qty: x.qty, at: at, source: source),
    ];
    final days = {...state.days, key: list};
    // simpan 120 hari terakhir
    final keys = days.keys.toList()..sort();
    while (keys.length > 120) {
      days.remove(keys.removeAt(0));
    }
    final names = {for (final x in items) x.food.name};
    final recent = [for (final x in items) x.food, ...state.recent.where((f) => !names.contains(f.name))].take(12).toList();
    await _save(state.copyWith(days: days, recent: recent));
  }

  Future<void> remove(String id, DateTime day) async {
    final key = dayKey(day);
    await _save(state.copyWith(days: {...state.days, key: state.on(day).where((e) => e.id != id).toList()}));
  }

  Future<void> setQty(String id, DateTime day, double qty) async {
    final key = dayKey(day);
    await _save(state.copyWith(days: {...state.days, key: [for (final e in state.on(day)) e.id == id ? e.withQty(qty) : e]}));
  }

  Future<void> saveBarcode(String code, FoodItem food) => _save(state.copyWith(barcodes: {...state.barcodes, code: food}));
}

final calorieProvider = NotifierProvider<CalorieNotifier, CalorieState>(CalorieNotifier.new);
