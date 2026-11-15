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
    if (status == 400 && message.toLowerCase().contains('api key')) return 'Kunci API Gemini tidak valid';
    if (status == 403) return 'Kunci API ditolak (cek izin kunci)';
    if (status == 404) return 'Model Gemini tidak ditemukan';
    if (status == 429) return 'Kuota Gemini habis untuk sementara';
    return 'Gemini tidak bisa dihubungi';
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

/// Menghubungi Google Gemini lewat REST API (tanpa Firebase).
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

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
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': contents,
      if (json) 'generationConfig': {'responseMimeType': 'application/json'},
    };
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_base/${Uri.encodeComponent(model)}:generateContent'),
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
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
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first is Map ? candidates.first['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';
    return parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => (p['text'] ?? '').toString())
        .join()
        .trim();
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

  /// Ngobrol bebas dengan Gemini.
  Future<String> chat({
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
    return _generate(apiKey: apiKey, model: model, system: system, contents: contents);
  }
}
