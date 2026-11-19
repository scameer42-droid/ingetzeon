import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/vital_logic.dart';
import 'settings_provider.dart';

/// Satu pengukuran tekanan darah (mmHg) + nadi opsional.
class BpEntry {
  const BpEntry({required this.id, required this.at, required this.sys, required this.dia, this.pulse});
  final String id;
  final DateTime at;
  final int sys, dia;
  final int? pulse;

  VitalLevel get level => classifyBp(sys, dia);

  Map<String, dynamic> toMap() => {'id': id, 'at': at.millisecondsSinceEpoch, 's': sys, 'd': dia, 'p': pulse};
  static BpEntry? fromMap(Map m) {
    final s = (m['s'] as num?)?.toInt(), d = (m['d'] as num?)?.toInt(), at = (m['at'] as num?)?.toInt();
    if (s == null || d == null || at == null) return null;
    return BpEntry(id: '${m['id'] ?? at}', at: DateTime.fromMillisecondsSinceEpoch(at), sys: s, dia: d, pulse: (m['p'] as num?)?.toInt());
  }
}

/// Satu pengukuran gula darah (mg/dL, atau % untuk HbA1c).
class GluEntry {
  const GluEntry({required this.id, required this.at, required this.kind, required this.value});
  final String id;
  final DateTime at;
  final GluKind kind;
  final double value;

  VitalLevel get level => classifyGlu(kind, value);

  Map<String, dynamic> toMap() => {'id': id, 'at': at.millisecondsSinceEpoch, 'k': kind.name, 'v': value};
  static GluEntry? fromMap(Map m) {
    final v = (m['v'] as num?)?.toDouble(), at = (m['at'] as num?)?.toInt();
    if (v == null || at == null) return null;
    return GluEntry(id: '${m['id'] ?? at}', at: DateTime.fromMillisecondsSinceEpoch(at), kind: GluKind.from(m['k'] as String?), value: v);
  }
}

class VitalState {
  const VitalState({this.bp = const [], this.glu = const [], this.diabetic = false});
  final List<BpEntry> bp; // terbaru di akhir
  final List<GluEntry> glu;
  final bool diabetic; // tampilkan target kendali penyandang diabetes

  BpEntry? get lastBp => bp.isEmpty ? null : bp.last;
  GluEntry? get lastGlu => glu.isEmpty ? null : glu.last;

  VitalState copyWith({List<BpEntry>? bp, List<GluEntry>? glu, bool? diabetic}) =>
      VitalState(bp: bp ?? this.bp, glu: glu ?? this.glu, diabetic: diabetic ?? this.diabetic);

  Map<String, dynamic> toMap() => {
        'bp': bp.map((e) => e.toMap()).toList(),
        'glu': glu.map((e) => e.toMap()).toList(),
        'diabetic': diabetic,
      };

  factory VitalState.fromMap(Map m) => VitalState(
        bp: ((m['bp'] as List?) ?? const []).whereType<Map>().map(BpEntry.fromMap).whereType<BpEntry>().toList()..sort((a, b) => a.at.compareTo(b.at)),
        glu: ((m['glu'] as List?) ?? const []).whereType<Map>().map(GluEntry.fromMap).whereType<GluEntry>().toList()..sort((a, b) => a.at.compareTo(b.at)),
        diabetic: m['diabetic'] == true,
      );
}

class VitalNotifier extends Notifier<VitalState> {
  @override
  VitalState build() => VitalState.fromMap(ref.read(settingsRepositoryProvider).get<Map>('vitals', const {}));

  Future<void> _save(VitalState v) async {
    state = v;
    await ref.read(settingsRepositoryProvider).set('vitals', v.toMap());
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> addBp(int sys, int dia, {int? pulse, DateTime? at}) {
    final list = [...state.bp, BpEntry(id: _id(), at: at ?? DateTime.now(), sys: sys, dia: dia, pulse: pulse)]..sort((a, b) => a.at.compareTo(b.at));
    return _save(state.copyWith(bp: list.length > 500 ? list.sublist(list.length - 500) : list));
  }

  Future<void> addGlu(GluKind kind, double value, {DateTime? at}) {
    final list = [...state.glu, GluEntry(id: _id(), at: at ?? DateTime.now(), kind: kind, value: value)]..sort((a, b) => a.at.compareTo(b.at));
    return _save(state.copyWith(glu: list.length > 500 ? list.sublist(list.length - 500) : list));
  }

  Future<void> removeBp(String id) => _save(state.copyWith(bp: state.bp.where((e) => e.id != id).toList()));
  Future<void> removeGlu(String id) => _save(state.copyWith(glu: state.glu.where((e) => e.id != id).toList()));
  Future<void> setDiabetic(bool v) => _save(state.copyWith(diabetic: v));
}

final vitalProvider = NotifierProvider<VitalNotifier, VitalState>(VitalNotifier.new);
