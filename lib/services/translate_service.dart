import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/i18n/en_dict.dart';
import 'ai_service.dart';

/// Hasil terjemahan beserta mesin & arah yang dipakai.
class TranslateResult {
  const TranslateResult(this.text, this.engine, {this.from = 'id'});
  final String text;

  /// 'gemini', 'mymemory', atau 'offline'.
  final String engine;

  /// Bahasa sumber yang benar-benar dipakai ('id' / 'en') — bisa beda dari pilihan
  /// pengguna bila teksnya ternyata bahasa lain.
  final String from;

  String get to => from == 'id' ? 'en' : 'id';
}

class TranslateException implements Exception {
  TranslateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Terjemah Indonesia ⇄ Inggris.
///
/// Bahasa teks ditebak otomatis. Memakai Gemini bila kunci API sudah diisi (paling
/// natural); kalau tidak memakai layanan gratis MyMemory. Bila bahasanya masih ragu
/// (mis. satu kata "singa"), kedua arah dicoba lalu dipilih hasil yang paling cocok.
class TranslateService {
  TranslateService._();
  static final TranslateService instance = TranslateService._();

  final http.Client _client = http.Client();
  final AiService _ai = AiService();

  static const _idWords = {
    'yang', 'dan', 'di', 'ke', 'dari', 'ini', 'itu', 'aku', 'saya', 'kamu', 'anda', 'tidak', 'gak', 'nggak', 'ya', 'apa',
    'ada', 'akan', 'sudah', 'udah', 'belum', 'bisa', 'mau', 'dengan', 'untuk', 'pada', 'juga', 'karena', 'jadi', 'kalau',
    'tapi', 'atau', 'sangat', 'banget', 'lagi', 'dong', 'sih', 'kok', 'nya', 'kita', 'kami', 'mereka', 'dia', 'besok',
    'hari', 'malam', 'pagi', 'siang', 'sore', 'terima', 'kasih', 'selamat', 'tolong', 'bagaimana', 'kenapa', 'mengapa',
    'siapa', 'kapan', 'dimana', 'berapa', 'harga', 'beli', 'jual', 'barang', 'sama', 'buat', 'lebih', 'masih', 'baru',
    'singa', 'kambing', 'kucing', 'anjing', 'ayam', 'sapi', 'ikan', 'burung', 'gajah', 'harimau', 'kuda', 'monyet', 'ular',
    'rumah', 'mobil', 'motor', 'jalan', 'makan', 'minum', 'tidur', 'kerja', 'sekolah', 'buku', 'meja', 'kursi', 'pintu',
    'air', 'nasi', 'roti', 'susu', 'kopi', 'teh', 'gula', 'garam', 'merah', 'biru', 'hijau', 'kuning', 'hitam', 'putih',
    'besar', 'kecil', 'cantik', 'ganteng', 'senang', 'sedih', 'marah', 'takut', 'sakit', 'sehat', 'cinta', 'sayang',
    'teman', 'ibu', 'bapak', 'ayah', 'adik', 'kakak', 'anak', 'orang', 'uang', 'waktu', 'tahun', 'bulan', 'minggu',
    'pergi', 'datang', 'pulang', 'lihat', 'dengar', 'bicara', 'tulis', 'baca', 'belajar', 'main', 'enak',
  };
  static const _enWords = {
    'the', 'and', 'is', 'are', 'was', 'were', 'to', 'of', 'in', 'on', 'for', 'with', 'this', 'that', 'it', 'you', 'i',
    'me', 'my', 'your', 'we', 'they', 'he', 'she', 'not', 'do', 'does', 'did', 'have', 'has', 'be', 'will', 'can', 'what',
    'how', 'why', 'when', 'where', 'who', 'please', 'thank', 'thanks', 'hello', 'good', 'morning', 'night', 'tomorrow',
    'today', 'a', 'an', 'at', 'from', 'by', 'about', 'would', 'could', 'should', 'there', 'here', 'very', 'price', 'buy',
    'lion', 'goat', 'cat', 'dog', 'chicken', 'cow', 'fish', 'bird', 'elephant', 'tiger', 'horse', 'monkey', 'snake',
    'house', 'car', 'eat', 'drink', 'sleep', 'work', 'school', 'book', 'table', 'chair', 'door', 'water', 'rice', 'bread',
    'milk', 'coffee', 'tea', 'red', 'blue', 'green', 'yellow', 'black', 'white', 'big', 'small', 'beautiful', 'happy',
    'sad', 'love', 'friend', 'mother', 'father', 'child', 'people', 'money', 'time', 'year', 'month', 'week', 'go', 'come',
  };

  static Set<String>? _idVocab, _enVocab;

  /// Kosakata tambahan dari kamus aplikasi (kunci = Indonesia, nilai = Inggris).
  static void _buildVocab() {
    if (_idVocab != null) return;
    final idv = <String>{}, env = <String>{};
    final re = RegExp(r'[a-z]{3,}');
    kEnDict.forEach((k, v) {
      for (final m in re.allMatches(k.toLowerCase())) {
        idv.add(m.group(0)!);
      }
      for (final m in re.allMatches(v.toLowerCase())) {
        env.add(m.group(0)!);
      }
    });
    final both = idv.intersection(env);
    _idVocab = idv.difference(both);
    _enVocab = env.difference(both);
  }

  /// Tebak bahasa teks: 'id', 'en', atau null bila ragu.
  static String? detect(String text) {
    _buildVocab();
    final words = RegExp(r"[a-zA-Z']+").allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return null;
    double id = 0, en = 0;
    for (final w in words) {
      if (_idWords.contains(w)) {
        id += 2;
      } else if (_enWords.contains(w)) {
        en += 2;
      } else if (_idVocab!.contains(w)) {
        id += 1;
      } else if (_enVocab!.contains(w)) {
        en += 1;
      } else {
        if (w.endsWith('nya') || w.endsWith('kan') || RegExp(r'^(meng|meny|mem|ber|ter|per)').hasMatch(w)) id += .6;
        if (w.endsWith("n't") || w.endsWith('tion') || w.endsWith('ly') || RegExp(r'(th|sh|ph|ck|wh|ee|oo)').hasMatch(w)) en += .6;
      }
    }
    if ((id - en).abs() < .5) return null;
    return id > en ? 'id' : 'en';
  }

  /// Terjemahkan. [from] = arah pilihan pengguna; bila teksnya ternyata bahasa lain,
  /// arah dibalik otomatis (lihat [TranslateResult.from]).
  Future<TranslateResult> translate(String text, {required String from, String apiKey = '', String model = ''}) async {
    final src = text.trim();
    if (src.isEmpty) return TranslateResult('', 'offline', from: from);
    final det = detect(src);
    final f = det ?? from;
    final t = f == 'id' ? 'en' : 'id';

    // 1) Gemini (kalau kunci sudah diisi) — sekaligus menebak bahasanya
    if (apiKey.trim().isNotEmpty) {
      try {
        final r = await _gemini(src, det, apiKey, model);
        if (r != null) return r;
      } catch (_) {
        // lanjut ke layanan gratis
      }
    }

    // 2) MyMemory (gratis, tanpa kunci)
    try {
      if (det == null && src.length <= 60) {
        // bahasa masih ragu → coba dua arah, ambil yang paling cocok
        final a = await _myMemory(src, f, t);
        ({String text, double match}) b = (text: '', match: 0.0);
        try {
          b = await _myMemory(src, t, f);
        } catch (_) {}
        bool same(String x) => x.trim().toLowerCase() == src.toLowerCase();
        final aOk = a.text.isNotEmpty && !same(a.text), bOk = b.text.isNotEmpty && !same(b.text);
        if (bOk && (!aOk || b.match > a.match + .05)) return TranslateResult(b.text, 'mymemory', from: t);
        if (a.text.isNotEmpty) return TranslateResult(a.text, 'mymemory', from: f);
      } else {
        final a = await _myMemory(src, f, t);
        if (a.text.isNotEmpty) return TranslateResult(a.text, 'mymemory', from: f);
      }
    } on TranslateException {
      final known = _offline(src, f, t);
      if (known != null) return TranslateResult(known, 'offline', from: f);
      rethrow;
    }
    final known = _offline(src, f, t);
    if (known != null) return TranslateResult(known, 'offline', from: f);
    throw TranslateException('Terjemahan belum berhasil. Coba lagi sebentar lagi.');
  }

  Future<TranslateResult?> _gemini(String src, String? det, String apiKey, String model) async {
    if (det != null) {
      final out = await _ai.translate(src, from: det, to: det == 'id' ? 'en' : 'id', apiKey: apiKey, model: model);
      return out.isEmpty ? null : TranslateResult(out, 'gemini', from: det);
    }
    final raw = await _ai.translateAuto(src, apiKey: apiKey, model: model);
    try {
      final m = jsonDecode(raw.replaceAll(RegExp(r'^```(json)?|```$'), '').trim());
      if (m is Map && '${m['out'] ?? ''}'.trim().isNotEmpty) {
        return TranslateResult('${m['out']}'.trim(), 'gemini', from: m['src'] == 'en' ? 'en' : 'id');
      }
    } catch (_) {}
    return null;
  }

  String? _offline(String s, String from, String to) {
    if (from == 'id' && to == 'en') return kEnDict[s];
    if (from == 'en' && to == 'id') {
      final low = s.toLowerCase();
      for (final e in kEnDict.entries) {
        if (e.value.toLowerCase() == low && !e.key.contains('{}')) return e.key;
      }
    }
    return null;
  }

  /// Pecah teks panjang jadi potongan ≤ 450 huruf (batas MyMemory 500).
  static List<String> _chunks(String s) {
    final out = <String>[];
    final parts = s.split(RegExp(r'(?<=[.!?\n])\s+'));
    var cur = '';
    for (final p in parts) {
      if (p.length > 450) {
        if (cur.isNotEmpty) out.add(cur);
        cur = '';
        for (var i = 0; i < p.length; i += 450) {
          out.add(p.substring(i, i + 450 > p.length ? p.length : i + 450));
        }
        continue;
      }
      if (cur.length + p.length + 1 > 450) {
        out.add(cur);
        cur = p;
      } else {
        cur = cur.isEmpty ? p : '$cur $p';
      }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  Future<({String text, double match})> _myMemory(String s, String from, String to) async {
    final pieces = <String>[];
    var match = 1.0;
    for (final c in _chunks(s)) {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {'q': c, 'langpair': '$from|$to', 'mt': '1'});
      http.Response res;
      try {
        res = await _client.get(uri).timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw TranslateException('Internet lambat — coba lagi.');
      } catch (_) {
        throw TranslateException('Tidak tersambung ke internet. Nyalakan data/Wi-Fi lalu coba lagi.');
      }
      if (res.statusCode == 429) throw TranslateException('Batas terjemahan gratis hari ini habis. Isi kunci Gemini di Profil supaya bisa terus menerjemahkan.');
      if (res.statusCode != 200) throw TranslateException('Layanan terjemahan sedang sibuk (kode ${res.statusCode}).');
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final rd = data is Map && data['responseData'] is Map ? data['responseData'] as Map : const {};
      var t = '${rd['translatedText'] ?? ''}';
      final status = data is Map ? '${data['responseStatus']}' : '';
      if (status != '200' && t.toUpperCase().contains('MYMEMORY WARNING')) {
        throw TranslateException('Batas terjemahan gratis hari ini habis. Isi kunci Gemini di Profil supaya bisa terus menerjemahkan.');
      }
      final m = rd['match'];
      final mv = m is num ? m.toDouble() : double.tryParse('$m') ?? 0;
      // hasil memori yang tidak nyambung (cocok rendah) → pakai terjemahan mesin bila ada
      if (mv < .5 && data is Map && data['matches'] is List) {
        for (final x in (data['matches'] as List).whereType<Map>()) {
          if ('${x['created-by']}' == 'MT!' && '${x['translation'] ?? ''}'.trim().isNotEmpty) {
            t = '${x['translation']}';
            break;
          }
        }
      }
      if (mv < match) match = mv;
      pieces.add(_unescape(t));
    }
    return (text: pieces.join(' ').trim(), match: match);
  }

  static String _unescape(String s) => s
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
