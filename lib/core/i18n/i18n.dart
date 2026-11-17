/// Bahasa tampilan aplikasi: Indonesia (bawaan) atau Inggris.
///
/// Teks aplikasi ditulis dalam Bahasa Indonesia. Saat bahasa Inggris dipilih,
/// [tr] menerjemahkannya memakai kamus [kEnDict]: cocok persis dulu, lalu pola
/// dengan bagian yang berubah ("{} menit lagi" → "in {} minutes"), lalu per baris.
library;

import 'en_dict.dart';

class I18n {
  I18n._();

  /// 'id' atau 'en'.
  static String lang = 'id';

  static bool get isEn => lang == 'en';

  static const languages = {'id': 'Bahasa Indonesia', 'en': 'English'};

  static final Map<String, String> _cache = {};
  static List<_Tpl>? _tpls;

  static void setLang(String l) {
    lang = l == 'en' ? 'en' : 'id';
    _cache.clear();
  }

  /// Terjemahkan [s] ke bahasa aktif. Teks yang tidak dikenal dibiarkan apa adanya.
  static String tr(String s) {
    if (!isEn || s.isEmpty) return s;
    final c = _cache[s];
    if (c != null) return c;
    final r = _translate(s, 0);
    if (_cache.length > 4000) _cache.clear();
    _cache[s] = r;
    return r;
  }

  static final _edgeWs = RegExp(r'^(\s*)([\s\S]*?)(\s*)$');
  static final _letters = RegExp(r'[A-Za-z]');
  static final _leadSym = RegExp(r'^([^A-Za-z]*?\s)([A-Za-z][\s\S]*)$');
  static final _trailPunct = RegExp(r'^([\s\S]*?[A-Za-z)])([,:;.!?…]+)$');

  static String _translate(String s, int depth) {
    final exact = kEnDict[s];
    if (exact != null) return exact;
    final m = _edgeWs.firstMatch(s)!;
    final core = m.group(2)!;
    if (core.isEmpty || !_letters.hasMatch(core)) return s;
    String? out = core != s ? kEnDict[core] : null;
    out ??= depth < 3 ? _template(core, depth) : null;
    if (out == null) {
      final lm = _leadSym.firstMatch(core);
      final base = lm == null ? null : kEnDict[lm.group(2)!];
      if (base != null) out = '${lm!.group(1)}$base';
    }
    if (out == null) {
      final pm = _trailPunct.firstMatch(core);
      final base = pm == null ? null : kEnDict[pm.group(1)!];
      if (base != null) out = '$base${pm!.group(2)}';
    }
    if (out == null && core.contains('\n')) {
      final lines = core.split('\n');
      var changed = false;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final t = _translate(lines[i], depth + 1);
        if (t != lines[i]) {
          lines[i] = t;
          changed = true;
        }
      }
      if (changed) out = lines.join('\n');
    }
    if (out == null) return s;
    return '${m.group(1)}$out${m.group(3)}';
  }

  static String? _template(String s, int depth) {
    final tpls = _tpls ??= _buildTemplates();
    for (final t in tpls) {
      if (!s.contains(t.key)) continue;
      final m = t.re.firstMatch(s);
      if (m == null) continue;
      final parts = t.out.split('{}');
      final b = StringBuffer(parts[0]);
      for (var i = 1; i < parts.length; i++) {
        final g = i <= m.groupCount ? (m.group(i) ?? '') : '';
        b
          ..write(_translate(g, depth + 1))
          ..write(parts[i]);
      }
      return b.toString();
    }
    return null;
  }

  static List<_Tpl> _buildTemplates() {
    final list = <_Tpl>[];
    final nonWord = RegExp(r'[\s\p{P}\p{S}0-9]', unicode: true);
    kEnDict.forEach((k, v) {
      if (!k.contains('{}')) return;
      final lits = k.split('{}');
      if ('{}'.allMatches(v).length != lits.length - 1) return;
      final literal = lits.join();
      if (literal.replaceAll(nonWord, '').length < 2) return;
      var key = '';
      for (final l in lits) {
        if (l.length > key.length) key = l;
      }
      final re = RegExp('^${lits.map(RegExp.escape).join(r'([\s\S]+?)')}\$');
      list.add(_Tpl(key, re, v, literal.length));
    });
    list.sort((a, b) => b.weight.compareTo(a.weight));
    return list;
  }
}

class _Tpl {
  _Tpl(this.key, this.re, this.out, this.weight);
  final String key;
  final RegExp re;
  final String out;
  final int weight;
}

/// Terjemahkan teks ke bahasa tampilan yang dipilih.
String tr(String s) => I18n.tr(s);

/// Seperti [tr] tapi menerima null.
String? trn(String? s) => s == null ? null : I18n.tr(s);

/// Pilih teks sesuai bahasa: `tl('Halo', 'Hello')`.
String tl(String id, String en) => I18n.isEn ? en : id;
