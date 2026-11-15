import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
      final indo = locales.where((l) => l.localeId.toLowerCase().startsWith('id'));
      if (indo.isNotEmpty) _localeId = indo.first.localeId;
    }
    return _sttReady;
  }

  /// Mulai mendengarkan. Mengembalikan false bila mikrofon tidak tersedia/ditolak.
  Future<bool> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (!await _initStt()) return false;
    await stopSpeaking();
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      localeId: _localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
    return true;
  }

  Future<void> stopListening() => _stt.stop();

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _ttsReady = true;
  }

  Future<void> speak(String text) async {
    await _initTts();
    final clean = text
        .replaceAll(RegExp(r'[*_#`•]'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2705}]', unicode: true), '')
        .replaceAll('—', ',')
        .replaceAll('\n', '. ');
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stopSpeaking() async {
    if (_ttsReady) await _tts.stop();
  }
}
