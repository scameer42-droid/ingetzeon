import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/i18n/i18n.dart';
import 'speech_text.dart';

/// Input suara (speech_to_text) dan suara balasan (flutter_tts), Bahasa Indonesia.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  bool _ttsReady = false;
  String _localeId = 'id_ID';

  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  bool get isListening => _stt.isListening;

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onStatus: (s) => _onStatus?.call(s),
      onError: (e) => _onError?.call(e.errorMsg),
    );
    if (_sttReady) {
      final locales = await _stt.locales();
      _sttLocales = locales.map((l) => l.localeId).toList();
      final indo = locales.where((l) => l.localeId.toLowerCase().startsWith('id'));
      if (indo.isNotEmpty) _localeId = indo.first.localeId;
    }
    return _sttReady;
  }

  List<String> _sttLocales = const [];

  /// Kode bahasa pengenalan suara untuk 'id' / 'en'.
  String _sttLocaleFor(String lang) {
    if (lang != 'en') return _localeId;
    for (final p in const ['en_US', 'en-US', 'en_GB', 'en']) {
      for (final l in _sttLocales) {
        if (l.toLowerCase().startsWith(p.toLowerCase())) return l;
      }
    }
    return 'en_US';
  }

  /// Mulai mendengarkan. Mengembalikan false bila mikrofon tidak tersedia/ditolak.
  Future<bool> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
    String? lang,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (!await _initStt()) return false;
    await stopSpeaking();
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(SpeechText.fromStt(r.recognizedWords), r.finalResult),
      localeId: _sttLocaleFor(lang ?? I18n.lang),
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        // dictation: dioptimalkan untuk kalimat panjang (confirmation hanya untuk "ya/tidak")
        listenMode: stt.ListenMode.dictation,
        autoPunctuation: true,
      ),
    );
    return true;
  }

  Future<void> stopListening() => _stt.stop();

  bool _hasIndonesian = true;

  /// false bila HP belum punya suara Bahasa Indonesia (balasan terdengar logat Inggris).
  bool get hasIndonesianVoice => _hasIndonesian;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      // Android lama memakai kode "in" untuk Bahasa Indonesia
      String lang = 'id-ID';
      for (final l in const ['id-ID', 'in-ID', 'id', 'in']) {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          lang = l;
          _hasIndonesian = true;
          break;
        }
        _hasIndonesian = false;
      }
      await _tts.setLanguage(lang);
      // pilih suara Indonesia yang terpasang di HP (utamakan yang offline/berkualitas)
      final voices = await _tts.getVoices;
      if (voices is List) {
        final indo = voices
            .whereType<Map>()
            .where((v) => RegExp(r'^(id|in)[-_]', caseSensitive: false).hasMatch('${v['locale'] ?? ''}'))
            .toList();
        if (indo.isNotEmpty) {
          _hasIndonesian = true;
          indo.sort((a, b) => '${a['name']}'.contains('network') ? 1 : ('${b['name']}'.contains('network') ? -1 : 0));
          final v = indo.first;
          await _tts.setVoice({'name': '${v['name']}', 'locale': '${v['locale']}'});
        }
      }
    } catch (_) {
      await _tts.setLanguage('id-ID');
    }
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ttsReady = true;
  }

  /// Cek dukungan suara Indonesia (untuk ditampilkan di Profil).
  Future<bool> checkIndonesianVoice() async {
    await _initTts();
    return _hasIndonesian;
  }

  /// Bahasa suara yang sedang dipasang di mesin TTS ('id' / 'en').
  String _ttsLang = 'id';

  Future<void> _useLang(String lang) async {
    if (_ttsLang == lang) return;
    try {
      if (lang == 'en') {
        await _tts.setLanguage('en-US');
        final voices = await _tts.getVoices;
        if (voices is List) {
          final en = voices.whereType<Map>().where((v) => RegExp(r'^en[-_]US', caseSensitive: false).hasMatch('${v['locale'] ?? ''}')).toList();
          en.sort((a, b) => '${a['name']}'.contains('network') ? 1 : ('${b['name']}'.contains('network') ? -1 : 0));
          if (en.isNotEmpty) await _tts.setVoice({'name': '${en.first['name']}', 'locale': '${en.first['locale']}'});
        }
        _ttsLang = 'en';
      } else {
        _ttsReady = false;
        _ttsLang = 'id';
        await _initTts();
      }
    } catch (_) {}
  }

  /// Bacakan teks. Saat bahasa tampilan Inggris, teks ikut diterjemahkan & dibaca berlogat Inggris.
  Future<void> speak(String text) async {
    await _initTts();
    final en = I18n.isEn;
    await _useLang(en ? 'en' : 'id');
    final clean = SpeechText.forTts(en ? tr(text) : text);
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  /// Bacakan teks dalam bahasa tertentu tanpa diterjemahkan (dipakai fitur Terjemah).
  Future<void> speakIn(String text, String lang) async {
    await _initTts();
    await _useLang(lang == 'en' ? 'en' : 'id');
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stopSpeaking() async {
    if (_ttsReady) await _tts.stop();
  }
}
