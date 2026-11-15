import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

/// Satu periode haid.
class Period {
  const Period(this.start, [this.end]);
  final DateTime start;
  final DateTime? end;

  Map<String, dynamic> toMap() => {'s': dayKey(start), 'e': end == null ? null : dayKey(end!)};
  static Period? fromMap(Map m) {
    final s = parseLocalIso('${m['s']}T00:00');
    if (s == null) return null;
    final e = m['e'] == null ? null : parseLocalIso('${m['e']}T00:00');
    return Period(s, e);
  }
}

class CycleData {
  const CycleData({this.enabled = false, this.periods = const [], this.cycleLen = 28, this.periodLen = 5, this.remind = true});
  final bool enabled;
  final List<Period> periods;
  final int cycleLen;
  final int periodLen;
  final bool remind;

  CycleData copyWith({bool? enabled, List<Period>? periods, int? cycleLen, int? periodLen, bool? remind}) => CycleData(
        enabled: enabled ?? this.enabled,
        periods: periods ?? this.periods,
        cycleLen: cycleLen ?? this.cycleLen,
        periodLen: periodLen ?? this.periodLen,
        remind: remind ?? this.remind,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'periods': periods.map((p) => p.toMap()).toList(),
        'cycleLen': cycleLen,
        'periodLen': periodLen,
        'remind': remind,
      };

  factory CycleData.fromMap(Map m) => CycleData(
        enabled: m['enabled'] == true,
        periods: ((m['periods'] as List?) ?? const []).whereType<Map>().map(Period.fromMap).whereType<Period>().toList(),
        cycleLen: (m['cycleLen'] as num?)?.toInt() ?? 28,
        periodLen: (m['periodLen'] as num?)?.toInt() ?? 5,
        remind: m['remind'] != false,
      );
}

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Hasil perhitungan siklus.
class CycleInfo {
  CycleInfo._({
    required this.periods,
    required this.lastStart,
    required this.lastEnd,
    required this.lastEnded,
    required this.day,
    required this.onPeriod,
    required this.next,
    required this.lateDays,
    required this.cycleLen,
    required this.periodLen,
  });

  final List<Period> periods;
  final DateTime lastStart;
  final DateTime lastEnd;
  final bool lastEnded;
  final int day; // hari ke-berapa siklus
  final bool onPeriod;
  final DateTime next;
  final int lateDays;
  final int cycleLen;
  final int periodLen;

  DateTime get ovulation => addDays(next, -14);
  DateTime get fertileStart => addDays(ovulation, -5);
  DateTime get fertileEnd => addDays(ovulation, 1);
  bool get ongoing => !lastEnded && onPeriod;
  bool inFertile(DateTime d) => !dateOnly(d).isBefore(fertileStart) && !dateOnly(d).isAfter(fertileEnd);

  static CycleInfo? from(CycleData c, [DateTime? now]) {
    if (c.periods.isEmpty) return null;
    final ps = [...c.periods]..sort((a, b) => a.start.compareTo(b.start));
    final gaps = <int>[];
    for (var i = 1; i < ps.length; i++) {
      final g = daysBetween(ps[i - 1].start, ps[i].start);
      if (g >= 18 && g <= 60) gaps.add(g);
    }
    final recent = gaps.length > 6 ? gaps.sublist(gaps.length - 6) : gaps;
    final cycleLen = recent.isEmpty ? c.cycleLen : (recent.reduce((a, b) => a + b) / recent.length).round();
    final lens = ps.where((p) => p.end != null).map((p) => daysBetween(p.start, p.end!) + 1).where((l) => l >= 1 && l <= 12).toList();
    final lensR = lens.length > 6 ? lens.sublist(lens.length - 6) : lens;
    final periodLen = lensR.isEmpty ? c.periodLen : (lensR.reduce((a, b) => a + b) / lensR.length).round();
    final last = ps.last;
    final today = dateOnly(now ?? DateTime.now());
    final day = daysBetween(last.start, today) + 1;
    final lastEnd = last.end ?? addDays(last.start, periodLen - 1);
    final onPeriod = !today.isBefore(last.start) && !today.isAfter(lastEnd) && (last.end != null || day <= periodLen + 3);
    final next = addDays(last.start, cycleLen);
    return CycleInfo._(
      periods: ps,
      lastStart: last.start,
      lastEnd: lastEnd,
      lastEnded: last.end != null,
      day: day,
      onPeriod: onPeriod,
      next: next,
      lateDays: daysBetween(next, today),
      cycleLen: cycleLen,
      periodLen: periodLen,
    );
  }

  ({String title, String sub}) status([DateTime? now]) {
    if (onPeriod) return (title: 'Hari ke-$day haid', sub: '${lastEnded ? 'Selesai' : 'Perkiraan selesai'} ${fmtDateShort(lastEnd)}');
    if (lateDays > 0) return (title: 'Terlambat $lateDays hari', sub: 'Perkiraan haid ${fmtDateShort(next)}');
    final d = daysBetween(now ?? DateTime.now(), next);
    return (
      title: d == 0 ? 'Haid diperkirakan hari ini' : 'Haid $d hari lagi',
      sub: '${fmtDateLong(next)}${inFertile(now ?? DateTime.now()) ? ' · sedang masa subur' : ''}',
    );
  }

  /// 'haid', 'haid-pred', 'subur', atau null untuk tanggal [d].
  String? markOn(DateTime d) {
    final x = dateOnly(d);
    for (final p in periods) {
      final e = p.end ?? addDays(p.start, periodLen - 1);
      if (!x.isBefore(p.start) && !x.isAfter(e)) return 'haid';
    }
    for (var k = 0; k < 3; k++) {
      final ns = addDays(next, cycleLen * k);
      if (!x.isBefore(ns) && !x.isAfter(addDays(ns, periodLen - 1))) return 'haid-pred';
      final ov = addDays(ns, -14);
      if (!x.isBefore(addDays(ov, -5)) && !x.isAfter(addDays(ov, 1))) return 'subur';
    }
    return null;
  }
}

class CycleNotifier extends Notifier<CycleData> {
  @override
  CycleData build() {
    final raw = ref.read(settingsRepositoryProvider).get<Map>('cycle', const {});
    return CycleData.fromMap(raw);
  }

  CycleInfo? get info => CycleInfo.from(state);

  Future<void> _save(CycleData c) async {
    state = c;
    await ref.read(settingsRepositoryProvider).set('cycle', c.toMap());
    await reschedule();
  }

  Future<void> reschedule() => NotificationService.instance.scheduleCycle(state.enabled && state.remind ? info?.next : null);

  Future<void> setup(DateTime lastStart, int cycleLen, int periodLen) async {
    final today = dateOnly(DateTime.now());
    final end = daysBetween(lastStart, today) >= periodLen ? addDays(lastStart, periodLen - 1) : null;
    await _save(state.copyWith(enabled: true, cycleLen: cycleLen, periodLen: periodLen, periods: [Period(dateOnly(lastStart), end)]));
  }

  /// Catat hari pertama haid. Mengembalikan false bila haid sedang berlangsung.
  Future<bool> logStart([DateTime? date]) async {
    final d = dateOnly(date ?? DateTime.now());
    final i = info;
    if (i != null && i.ongoing && daysBetween(i.lastStart, d) < 10) return false;
    final ps = [...state.periods.where((p) => !sameDay(p.start, d)), Period(d)]..sort((a, b) => a.start.compareTo(b.start));
    await _save(state.copyWith(enabled: true, periods: ps.length > 24 ? ps.sublist(ps.length - 24) : ps));
    return true;
  }

  Future<bool> logEnd([DateTime? date]) async {
    final d = dateOnly(date ?? DateTime.now());
    if (state.periods.isEmpty) return false;
    final ps = [...state.periods]..sort((a, b) => a.start.compareTo(b.start));
    final last = ps.last;
    if (last.end != null || d.isBefore(last.start)) return false;
    ps[ps.length - 1] = Period(last.start, d);
    await _save(state.copyWith(periods: ps));
    return true;
  }

  Future<void> addPast(DateTime start) async {
    final s = dateOnly(start);
    if (state.periods.any((p) => sameDay(p.start, s))) return;
    final ps = [...state.periods, Period(s, addDays(s, state.periodLen - 1))]..sort((a, b) => a.start.compareTo(b.start));
    await _save(state.copyWith(enabled: true, periods: ps));
  }

  Future<void> setRemind(bool v) => _save(state.copyWith(remind: v));
  Future<void> setCycleLen(int v) => _save(state.copyWith(cycleLen: v.clamp(18, 60).toInt()));
  Future<void> setPeriodLen(int v) => _save(state.copyWith(periodLen: v.clamp(1, 12).toInt()));
  Future<void> reset() => _save(const CycleData());
}

final cycleProvider = NotifierProvider<CycleNotifier, CycleData>(CycleNotifier.new);
