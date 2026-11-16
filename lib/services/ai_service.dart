import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/date_utils.dart';
import '../data/models/reminder.dart';
import 'natural_parser.dart';

class AiException implements Exception {
  AiException(this.status, this.message);
  final int status;
  final String message;

  /// Pesan ramah untuk pengguna.
  String get friendly {
    if (status == -1) return 'Gemini terlalu lama merespons';
    if (status == -2) return 'Tidak ada koneksi internet';
    final m = message.toLowerCase();
    final detail = message.isEmpty ? '' : ' (${message.length > 140 ? message.substring(0, 140) : message})';
    if (message.contains('ACCESS_TOKEN_TYPE_UNSUPPORTED')) {
      return 'Google menolak kunci AQ. ini (masalah di sisi Google, bukan aplikasinya). Coba hapus kunci lama, lalu buat kunci baru di aistudio.google.com';
    }
    if ((status == 400 || status == 401) && (m.contains('api key') || m.contains('credential') || m.contains('auth'))) {
      return 'Kunci API Gemini tidak valid$detail';
    }
    if (status == 401 || status == 403) return 'Kunci API ditolak oleh Google$detail';
    if (status == 404) return 'Model Gemini tidak tersedia untuk kunci ini$detail';
    if (status == 429) return 'Kuota Gemini habis untuk sementara, coba lagi sebentar lagi';
    return 'Gemini tidak bisa dihubungi$detail';
  }

  @override
  String toString() => 'AiException($status, $message)';
}

/// Pesan untuk riwayat chat Gemini.
class AiTurn {
  const AiTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Jawaban Gemini beserta sumber (Google Search).
class AiReply {
  const AiReply(this.text, [this.sources = const []]);
  final String text;
  final List<AiSource> sources;
}

class AiSource {
  const AiSource(this.title, this.uri);
  final String title;
  final String uri;
}

/// Menghubungi Google Gemini lewat REST API (tanpa Firebase).
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// AI Studio kini mengeluarkan kunci "AQ." (Auth key) selain "AIza"; keduanya dipakai di server Gemini biasa.
  /// Server Vertex AI express hanya dicoba sebagai cadangan untuk kunci "AQ.".
  static bool isVertexKey(String key) => key.trim().startsWith('AQ.');

  /// Model & server yang terakhir berhasil dipakai.
  static String? workingModel;
  static bool workingVertex = false;

  static List<bool> _endpointOrder(String apiKey) {
    final eps = <bool>[false, if (isVertexKey(apiKey)) true]; // false = AI Studio, true = Vertex
    if (workingVertex && eps.contains(true)) return [true, false];
    return eps;
  }

  static List<String> _candidates(bool vertex, String userModel) {
    final auto = userModel.trim().isEmpty || userModel == 'gemini-flash-latest' || userModel == 'otomatis';
    final defaults = vertex
        ? ['gemini-3.5-flash', 'gemini-3-flash-preview', 'gemini-2.5-flash']
        : ['gemini-flash-latest', 'gemini-3.7-flash', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-2.5-flash'];
    return {
      if (workingModel != null && workingVertex == vertex) workingModel!,
      if (!auto) userModel.trim(),
      ...defaults,
    }.toList();
  }

  static Uri _endpoint(bool vertex, String model) => vertex
      ? Uri.parse('https://aiplatform.googleapis.com/v1/publishers/google/models/${Uri.encodeComponent(model)}:generateContent')
      : Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(model)}:generateContent');

  /// Prompt dari pengguna, dengan waktu sekarang diisi otomatis.
  static String reminderPrompt(DateTime now) {
    final off = now.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final tz = '$sign${two(off.inHours.abs())}:${two(off.inMinutes.abs() % 60)}';
    final besok = dayKey(addDays(now, 1));
    return '''Kamu adalah asisten penjadwalan pintar. Tugasmu adalah mengubah input bahasa alami dari user (Bahasa Indonesia) menjadi format JSON reminder.

Format JSON yang WAJIB kamu kembalikan:
{
  "title": string (judul singkat kegiatan),
  "note": string | null (catatan tambahan jika ada),
  "scheduledAt": "ISO8601 datetime" (waktu lengkap),
  "repeat": "once" | "daily" | "weekly" | "monthly",
  "category": "kerja" | "pribadi" | "kesehatan" | "edukasi" | "parkir" | "lainnya",
  "alarm": boolean
}

Aturan Ketat:
1. Jika user tidak menyebut tanggal, gunakan tanggal hari ini.
2. Jika user tidak menyebut jam, gunakan jam 09:00 pagi.
3. Jika user menyebut "setiap hari", "tiap minggu", ubah nilai "repeat" sesuai.
4. Kembalikan HANYA kode JSON murni, tanpa teks pembuka, penutup, atau markdown (tanpa ```json).
5. Waktu saat ini adalah: ${hariList[jsDay(now)]}, ${toLocalIso(now)} (zona waktu $tz). Tulis scheduledAt dalam waktu lokal tanpa zona, format YYYY-MM-DDTHH:mm:ss.
6. Jika tentang lokasi parkir (mis. "saya parkir di B2") dan user TIDAK menyebut jam, isi scheduledAt dengan waktu saat ini dan "alarm": false. Judulnya "Parkir di <lokasi>". Selain itu "alarm": true.

Contoh Input: "ingatkan besok jam 7 pagi olahraga"
Contoh Output:
{"title": "Olahraga", "note": null, "scheduledAt": "${besok}T07:00:00", "repeat": "once", "category": "kesehatan", "alarm": true}''';
  }

  Future<String> _generate({
    required String apiKey,
    required String model,
    required String system,
    required List<Map<String, dynamic>> contents,
    bool json = false,
    Duration timeout = const Duration(seconds: 30),
  }) async =>
      (await _generateFull(apiKey: apiKey, model: model, system: system, contents: contents, json: json, timeout: timeout)).text;

  /// Mencoba beberapa model sampai ada yang tersedia untuk kunci ini.
  Future<AiReply> _generateFull({
    required String apiKey,
    required String model,
    required String system,
    required List<Map<String, dynamic>> contents,
    bool json = false,
    bool search = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    AiException? last, firstAuth;
    for (final vertex in _endpointOrder(apiKey)) {
      for (final m in _candidates(vertex, model)) {
        try {
          final r = await _generateOnce(
              apiKey: apiKey, model: m, vertex: vertex, system: system, contents: contents, json: json, search: search, timeout: timeout);
          workingModel = m;
          workingVertex = vertex;
          return r;
        } on AiException catch (e) {
          last = e;
          final msg = e.message.toLowerCase();
          if (e.status == 404 || (e.status == 400 && (msg.contains('model') || msg.contains('not found') || msg.contains('not supported')))) {
            continue; // coba model lain
          }
          if (e.status == 401 || e.status == 403) {
            firstAuth ??= e;
            break; // coba server lain
          }
          rethrow;
        }
      }
    }
    throw firstAuth ?? last ?? AiException(404, 'model tidak tersedia');
  }

  Future<AiReply> _generateOnce({
    required String apiKey,
    required String model,
    required bool vertex,
    required String system,
    required List<Map<String, dynamic>> contents,
    bool json = false,
    bool search = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': contents,
      if (json) 'generationConfig': {'responseMimeType': 'application/json'},
      if (search)
        'tools': [
          {'googleSearch': <String, dynamic>{}}
        ],
    };
    final http.Response res;
    try {
      res = await _client
          .post(
            _endpoint(vertex, model),
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey.trim()},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AiException(-1, 'timeout');
    } catch (e) {
      throw AiException(-2, e.toString());
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode != 200) {
      final msg = data is Map && data['error'] is Map ? (data['error']['message'] ?? '').toString() : res.reasonPhrase ?? '';
      throw AiException(res.statusCode, msg);
    }
    final candidates = data is Map ? data['candidates'] : null;
    if (candidates is! List || candidates.isEmpty) return const AiReply('');
    final first = candidates.first is Map ? candidates.first as Map : const {};
    final content = first['content'];
    final parts = content is Map ? content['parts'] : null;
    final text = parts is! List
        ? ''
        : parts.whereType<Map>().where((p) => p['thought'] != true).map((p) => (p['text'] ?? '').toString()).join().trim();
    final sources = <AiSource>[];
    final gm = first['groundingMetadata'];
    final chunks = gm is Map ? gm['groundingChunks'] : null;
    if (chunks is List) {
      for (final c in chunks.whereType<Map>()) {
        final web = c['web'];
        if (web is Map && web['uri'] != null) sources.add(AiSource((web['title'] ?? 'sumber').toString(), web['uri'].toString()));
        if (sources.length >= 4) break;
      }
    }
    return AiReply(text, sources);
  }

  /// Mengubah kalimat menjadi pengingat dengan Gemini. Melempar [AiException] bila gagal.
  Future<ParsedReminder?> parseReminder(String text, {required String apiKey, required String model}) async {
    final now = DateTime.now();
    final out = await _generate(
      apiKey: apiKey,
      model: model,
      system: reminderPrompt(now),
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ]
        }
      ],
      json: true,
    );
    final cleaned = out.replaceAll(RegExp(r'^```(?:json)?', caseSensitive: false), '').replaceAll(RegExp(r'```$'), '').trim();
    dynamic obj;
    try {
      obj = jsonDecode(cleaned);
    } catch (_) {
      return null;
    }
    if (obj is List && obj.isNotEmpty) obj = obj.first;
    if (obj is! Map) return null;

    final at = parseLocalIso(obj['scheduledAt']?.toString());
    if (at == null) return null;
    final local = NaturalParser.parse(text, now: now);
    final title = (obj['title'] ?? '').toString().trim();
    final note = obj['note']?.toString().trim();
    final repeatName = obj['repeat']?.toString();
    final catName = obj['category']?.toString();
    return ParsedReminder(
      title: title.isEmpty ? local.title : title,
      note: (note == null || note.isEmpty || note == 'null') ? null : note,
      scheduledAt: at,
      repeat: RepeatType.values.any((e) => e.name == repeatName) ? RepeatType.fromName(repeatName) : local.repeat,
      category: ReminderCategory.values.any((e) => e.name == catName) ? ReminderCategory.fromName(catName) : local.category,
      alarm: obj['alarm'] == false ? false : (obj['alarm'] == true ? true : local.alarm),
    );
  }

  /// Cek cepat apakah kunci berfungsi. Mengembalikan nama model yang dipakai.
  Future<String> testKey(String apiKey, String model) async {
    await _generate(
      apiKey: apiKey,
      model: model,
      system: 'Jawab satu kata saja.',
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Tes. Balas: oke'}
          ]
        }
      ],
    );
    return workingModel ?? model;
  }

  /// Ngobrol bebas dengan Gemini (dengan Google Search untuk info terbaru).
  Future<AiReply> chat({
    required String text,
    required List<AiTurn> history,
    required String system,
    required String apiKey,
    required String model,
  }) async {
    final contents = <Map<String, dynamic>>[
      for (final h in history)
        {
          'role': h.fromUser ? 'user' : 'model',
          'parts': [
            {'text': h.text}
          ]
        },
      {
        'role': 'user',
        'parts': [
          {'text': text}
        ]
      },
    ];
    // Gemini mewajibkan giliran pertama dari user.
    while (contents.isNotEmpty && contents.first['role'] != 'user') {
      contents.removeAt(0);
    }
    try {
      return await _generateFull(apiKey: apiKey, model: model, system: system, contents: contents, search: true);
    } on AiException catch (e) {
      // model yang tidak mendukung Google Search → coba tanpa
      if (e.status == 400 || e.status == 403) return _generateFull(apiKey: apiKey, model: model, system: system, contents: contents);
      rethrow;
    }
  }

  /// Penjelasan error pindai foto yang mudah dipahami.
  static String scanErrorText(Object e) {
    if (e is AiException) {
      final m = e.message.toLowerCase();
      if (e.status == -1) return 'AI terlalu lama menjawab — biasanya karena internet lambat. Coba lagi di sinyal yang lebih bagus.';
      if (e.status == -2) return 'Tidak tersambung ke internet. Nyalakan data/Wi-Fi lalu coba lagi.';
      if (e.status == 429 || m.contains('quota') || m.contains('exhausted')) {
        return 'Kuota gratis Gemini sedang habis. Tunggu 1–2 menit lalu coba lagi (kuota harian kembali penuh tiap hari).';
      }
      if (e.status == 401 || e.status == 403 || (e.status == 400 && (m.contains('api key') || m.contains('api_key')))) {
        return 'Kunci API Gemini ditolak. Cek atau ganti kuncinya di Profil → Kunci API Gemini (tombol "Tes").';
      }
      if (e.status >= 500) return 'Server Gemini sedang sibuk. Coba lagi sebentar lagi.';
      return 'AI belum bisa membaca foto ini (kode ${e.status}${e.message.isNotEmpty ? ': ${e.message.length > 80 ? e.message.substring(0, 80) : e.message}' : ''}).';
    }
    if (e is FormatException) return 'Jawaban AI terpotong. Coba foto ulang ya.';
    return 'Foto belum bisa dikenali. Coba foto lebih dekat dan terang.';
  }

  static const foodScanPrompt = 'Kamu ahli gizi Indonesia. Kenali semua makanan & minuman di foto ini dan perkirakan porsinya. '
      'Balas HANYA JSON: {"items":[{"name":"nama makanan dalam bahasa Indonesia","portion":"mis. 1 piring","gram":150,"kcal":195,"protein":3.6,"carbs":42,"fat":0.3}],"note":"catatan singkat"}. '
      'Pakai acuan TKPI Kemenkes. Jika foto bukan makanan, kembalikan {"items":[],"note":"alasan"}.';

  /// Memindai foto makanan → daftar makanan + perkiraan kalori.
  Future<({List<Map<String, dynamic>> items, String note})> scanFood(List<int> bytes, {required String apiKey, required String model, String mime = 'image/jpeg'}) async {
    final out = await _generate(
      apiKey: apiKey,
      model: model,
      system: foodScanPrompt,
      json: true,
      timeout: const Duration(seconds: 75),
      contents: [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': mime, 'data': base64Encode(bytes)}
            },
            {'text': 'Hitung kalori makanan di foto ini.'}
          ]
        }
      ],
    );
    var txt = out.trim();
    final a = txt.indexOf('{'), b = txt.lastIndexOf('}');
    if (a >= 0 && b > a) txt = txt.substring(a, b + 1);
    final data = jsonDecode(txt);
    final items = <Map<String, dynamic>>[
      if (data is Map && data['items'] is List)
        for (final x in data['items'] as List)
          if (x is Map && x['name'] != null) Map<String, dynamic>.from(x),
    ];
    return (items: items, note: data is Map ? '${data['note'] ?? ''}' : '');
  }
}
