import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/i18n/en_dict.dart';
import 'ai_service.dart';

/// Hasil terjemahan beserta mesin yang dipakai.
class TranslateResult {
  const TranslateResult(this.text, this.engine);
  final String text;

  /// 'gemini', 'mymemory', atau 'offline'.
  final String engine;
}

class TranslateException implements Exception {
  TranslateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Terjemah Indonesia ⇄ Inggris.
///
/// Memakai Gemini bila kunci API sudah diisi (paling natural), kalau tidak memakai
/// layanan gratis MyMemory. Teks yang sudah ada di kamus aplikasi bisa diterjemahkan
/// tanpa internet.
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
  };
  static const _enWords = {
    'the', 'and', 'is', 'are', 'was', 'were', 'to', 'of', 'in', 'on', 'for', 'with', 'this', 'that', 'it', 'you', 'i',
    'me', 'my', 'your', 'we', 'they', 'he', 'she', 'not', 'do', 'does', 'did', 'have', 'has', 'be', 'will', 'can', 'what',
    'how', 'why', 'when', 'where', 'who', 'please', 'thank', 'thanks', 'hello', 'good', 'morning', 'night', 'tomorrow',
    'today', 'a', 'an', 'at', 'from', 'by', 'about', 'would', 'could', 'should', 'there', 'here', 'very', 'price', 'buy',
  };

  /// Tebak bahasa teks: 'id', 'en', atau null bila ragu.
  static String? detect(String text) {
    final words = RegExp(r"[a-zA-Z']+").allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return null;
    var id = 0, en = 0;
    for (final w in words) {
      if (_idWords.contains(w) || w.endsWith('nya') || w.startsWith('meng') || w.startsWith('ber')) id++;
      if (_enWords.contains(w) || w.endsWith('ing') || w.endsWith("n't")) en++;
    }
    if (id == en) return null;
    return id > en ? 'id' : 'en';
  }

  Future<TranslateResult> translate(String text, {required String from, required String to, String apiKey = '', String model = ''}) async {
    final src = text.trim();
    if (src.isEmpty) return const TranslateResult('', 'offline');
    if (from == to) return TranslateResult(src, 'offline');

    // 1) kalimat yang sudah dikenal aplikasi (tanpa internet)
    final known = _offline(src, from, to);

    // 2) Gemini (kalau kunci sudah diisi)
    if (apiKey.trim().isNotEmpty) {
      try {
        final out = await _ai.translate(src, from: from, to: to, apiKey: apiKey, model: model);
        if (out.isNotEmpty) return TranslateResult(out, 'gemini');
      } catch (_) {
        // lanjut ke layanan gratis
      }
    }

    // 3) MyMemory (gratis, tanpa kunci)
    try {
      final out = await _myMemory(src, from, to);
      if (out.isNotEmpty) return TranslateResult(out, 'mymemory');
    } on TranslateException {
      if (known != null) return TranslateResult(known, 'offline');
      rethrow;
    }
    if (known != null) return TranslateResult(known, 'offline');
    throw TranslateException('Terjemahan belum berhasil. Coba lagi sebentar lagi.');
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

  Future<String> _myMemory(String s, String from, String to) async {
    final pieces = <String>[];
    for (final c in _chunks(s)) {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {'q': c, 'langpair': '$from|$to'});
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
      final t = data is Map && data['responseData'] is Map ? '${data['responseData']['translatedText'] ?? ''}' : '';
      final status = data is Map ? '${data['responseStatus']}' : '';
      if (status != '200' && t.toUpperCase().contains('MYMEMORY WARNING')) {
        throw TranslateException('Batas terjemahan gratis hari ini habis. Isi kunci Gemini di Profil supaya bisa terus menerjemahkan.');
      }
      pieces.add(_unescape(t));
    }
    return pieces.join(' ').trim();
  }

  static String _unescape(String s) => s
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
