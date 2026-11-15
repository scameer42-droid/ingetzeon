import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/models/reminder.dart';
import '../services/ai_service.dart';
import '../services/natural_parser.dart';
import '../services/voice_service.dart';
import 'reminder_provider.dart';
import 'settings_provider.dart';

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.reminderId, this.photoPath});
  final bool fromUser;
  final String text;
  final String? reminderId;
  final String? photoPath;

  Map<String, dynamic> toMap() => {'u': fromUser, 't': text, 'r': reminderId, 'p': photoPath};
  factory ChatMessage.fromMap(Map m) => ChatMessage(
        fromUser: m['u'] == true,
        text: (m['t'] ?? '').toString(),
        reminderId: m['r']?.toString(),
        photoPath: m['p']?.toString(),
      );
}

class ChatState {
  const ChatState({this.messages = const [], this.thinking = false});
  final List<ChatMessage> messages;
  final bool thinking;
  ChatState copyWith({List<ChatMessage>? messages, bool? thinking}) =>
      ChatState(messages: messages ?? this.messages, thinking: thinking ?? this.thinking);
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final _remindRe = RegExp(
  r'\b(ingatkan|ingetin|ingatin|ingetkan|remind|reminder|jadwalkan|bikin pengingat|buat pengingat|tambah pengingat|pasang pengingat)\b',
  caseSensitive: false,
);

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    final raw = ref.read(settingsRepositoryProvider).get<List>('chat', const []);
    return ChatState(messages: raw.whereType<Map>().map(ChatMessage.fromMap).toList());
  }

  AppSettings get _settings => ref.read(settingsProvider);

  void _push(ChatMessage m) {
    final list = [...state.messages, m];
    state = state.copyWith(messages: list.length > 60 ? list.sublist(list.length - 60) : list);
    ref.read(settingsRepositoryProvider).set('chat', state.messages.map((e) => e.toMap()).toList());
  }

  void _bot(String text, {String? reminderId, String? speech}) {
    _push(ChatMessage(fromUser: false, text: text, reminderId: reminderId));
    if (_settings.voice) VoiceService.instance.speak(speech ?? text);
  }

  void greet() {
    if (state.messages.isNotEmpty) return;
    final n = _settings.name.isEmpty ? '' : ' ${_settings.name}';
    _push(ChatMessage(
      fromUser: false,
      text: 'Halo$n! 👋 Aku asisten IngetZeon.\nBilang saja "ingatkan…" lewat ketikan atau suara, nanti aku buatkan pengingatnya. '
          'Kamu juga bisa tanya "jadwal hari ini apa?"',
    ));
  }

  Future<void> clear() async {
    state = const ChatState();
    await ref.read(settingsRepositoryProvider).set('chat', const []);
    greet();
  }

  Future<void> send(String input, {String? photoPath}) async {
    final text = input.trim();
    if (text.isEmpty || state.thinking) return;
    _push(ChatMessage(fromUser: true, text: text, photoPath: photoPath));
    state = state.copyWith(thinking: true);
    try {
      final lower = text.toLowerCase();
      final aboutParking = lower.contains('parkir');
      final asksWhere = RegExp(r'di ?mana|\bmana\b').hasMatch(lower);
      if (aboutParking && asksWhere && photoPath == null) {
        _answerParking();
      } else if (_remindRe.hasMatch(text) || aboutParking || photoPath != null) {
        await _handleReminder(text, photoPath: photoPath);
      } else {
        await _handleChat(text);
      }
    } finally {
      state = state.copyWith(thinking: false);
    }
  }

  void _answerParking() {
    final p = activeParking(ref.read(remindersProvider));
    if (p == null) {
      _bot('Aku belum punya catatan parkir terbaru. Foto lokasi parkirmu lalu bilang, misalnya, "saya parkir di B2".');
      return;
    }
    final lokasi = p.title.replaceFirst(RegExp(r'^parkir di ', caseSensitive: false), '');
    _bot('Kamu parkir di **$lokasi** 📍 (dicatat ${dayLabel(p.createdAt).toLowerCase()} jam ${fmtTime(p.createdAt)}).',
        reminderId: p.id, speech: 'Kamu parkir di $lokasi.');
  }

  Future<void> _handleReminder(String text, {String? photoPath}) async {
    ParsedReminder? data;
    var note = '';
    final s = _settings;
    if (s.hasAi) {
      try {
        data = await ref.read(aiServiceProvider).parseReminder(text, apiKey: s.apiKey, model: s.model);
      } on AiException catch (e) {
        note = '\n\n(${e.friendly}, jadi aku pakai pemahaman offline.)';
      }
    }
    data ??= NaturalParser.parse(text);

    var at = data.scheduledAt;
    if (data.alarm && data.repeat == RepeatType.once && !at.isAfter(DateTime.now())) at = addDays(at, 1);

    final r = Reminder.create(
      title: data.title,
      note: data.note,
      scheduledAt: at,
      repeat: data.repeat,
      category: data.category,
      photoPath: photoPath,
      alarm: data.alarm,
    );
    await ref.read(remindersProvider.notifier).upsert(r);

    if (!r.alarm) {
      _bot('Oke, aku catat **${r.title}**${photoPath != null ? ' beserta fotonya 📸' : ' 📍'}. Tanya aku "di mana aku parkir?" kapan saja.',
          reminderId: r.id, speech: 'Oke, aku catat ${r.title}. Tanya aku di mana aku parkir kapan saja.');
      return;
    }

    final when = switch (r.repeat) {
      RepeatType.daily => 'setiap hari jam ${fmtTime(at)}',
      RepeatType.weekly => 'setiap ${hariList[jsDay(at)]} jam ${fmtTime(at)}',
      RepeatType.monthly => 'setiap tanggal ${at.day} jam ${fmtTime(at)}',
      RepeatType.once => () {
          final l = dayLabel(at);
          final d = (l == 'Hari ini' || l == 'Besok' || l == 'Lusa') ? l.toLowerCase() : 'pada ${fmtDateLong(at)}';
          return '$d jam ${fmtTime(at)}';
        }(),
    };
    final speechWhen = when.replaceAll(fmtTime(at), speakTime(at));
    _bot('Siap! Aku ingatkan **${r.title}** $when. ✅$note',
        reminderId: r.id, speech: 'Siap! Aku ingatkan ${r.title} $speechWhen.');
  }

  String _localAnswer(String text) {
    final t = ' ${text.toLowerCase()} ';
    final list = ref.read(remindersProvider);
    final now = DateTime.now();
    final asksSchedule = RegExp(r'jadwal|agenda|acara|kegiatan|pengingat|reminder|ada apa').hasMatch(t);
    DateTime? day;
    var label = '';
    if (t.contains(' lusa ')) {
      day = addDays(dateOnly(now), 2);
      label = 'lusa';
    } else if (RegExp(r' (besok|besuk) ').hasMatch(t)) {
      day = addDays(dateOnly(now), 1);
      label = 'besok';
    } else if (RegExp(r' (hari ini|sekarang|nanti) ').hasMatch(t) || asksSchedule) {
      day = dateOnly(now);
      label = 'hari ini';
    }
    if (asksSchedule && day != null) {
      final its = occurrencesOn(list, day);
      if (its.isEmpty) return 'Jadwal $label masih kosong. Mau aku buatkan pengingat?';
      final left = its.where((x) => !x.done).length;
      final head = 'Jadwal $label ada ${its.length}${label == 'hari ini' ? ', $left belum selesai' : ''}:';
      return '$head\n${its.map((x) => '• ${fmtTime(x.at)} — ${x.reminder.title}${x.done ? ' ✓' : ''}').join('\n')}';
    }
    if (RegExp(r' (terdekat|berikutnya|selanjutnya) ').hasMatch(t)) {
      final nx = nextUpcoming(list);
      return nx == null
          ? 'Belum ada jadwal berikutnya.'
          : 'Jadwal terdekat: **${nx.reminder.title}**, ${dayLabel(nx.at).toLowerCase()} jam ${fmtTime(nx.at)} (${countdown(nx.at)}).';
    }
    if (RegExp(r' (halo|hai|hi|hello|pagi|siang|sore|malam|assalamualaikum) ').hasMatch(t)) {
      return '${greeting()}! Ada yang mau aku ingatkan hari ini?';
    }
    if (RegExp(r' (terima kasih|makasih|thanks|thx|mksh) ').hasMatch(t)) return 'Sama-sama! Semoga harimu lancar 😊';
    if (RegExp(r' (jam berapa|pukul berapa) ').hasMatch(t)) return 'Sekarang jam ${fmtTime(now)}.';
    if (RegExp(r' (tanggal berapa|hari apa) ').hasMatch(t)) return 'Hari ini ${fmtDateLong(now)}.';
    return 'Aku bisa membuat pengingat dan memberi tahu jadwalmu.\nCoba bilang: "ingatkan besok jam 7 pagi olahraga" '
        'atau "jadwal hari ini apa?"${_settings.hasAi ? '' : '\n\nUntuk ngobrol lebih bebas, isi kunci API Gemini di menu Profil.'}';
  }

  String _speechOf(String s) =>
      s.replaceAllMapped(RegExp(r'(\d{2})\.(\d{2})'), (m) => m[2] == '00' ? 'jam ${int.parse(m[1]!)}' : 'jam ${int.parse(m[1]!)} lewat ${int.parse(m[2]!)}')
          .replaceAll('jam jam', 'jam');

  String _chatPrompt() {
    final list = ref.read(remindersProvider);
    final now = DateTime.now();
    String fmt(List<Occurrence> l) =>
        l.isEmpty ? '(kosong)' : l.map((x) => '- ${fmtTime(x.at)} ${x.reminder.title}${x.done ? ' (selesai)' : ''}').join('\n');
    return 'Kamu adalah "Asisten IngetZeon", asisten pengingat harian yang ramah, berbahasa Indonesia santai dan sopan.\n'
        'Jawab singkat (maksimal 3 kalimat), tanpa tabel, karena jawabanmu juga dibacakan dengan suara.\n'
        'Sekarang: ${fmtDateLong(now)} jam ${fmtTime(now)}. Nama pengguna: ${_settings.name.isEmpty ? 'tidak diketahui' : _settings.name}.\n'
        'Jadwal hari ini:\n${fmt(occurrencesOn(list, now))}\n'
        'Jadwal besok:\n${fmt(occurrencesOn(list, addDays(dateOnly(now), 1)))}\n'
        'Kalau pengguna ingin membuat pengingat, sarankan dia mengetik kalimat yang diawali kata "ingatkan", '
        'contoh: "ingatkan besok jam 7 olahraga".';
  }

  Future<void> _handleChat(String text) async {
    final s = _settings;
    final lower = text.toLowerCase();
    if (!s.hasAi || RegExp(r'jadwal|agenda|acara|kegiatan|terdekat|berikutnya').hasMatch(lower)) {
      final a = _localAnswer(text);
      _bot(a, speech: _speechOf(a));
      return;
    }
    try {
      final msgs = state.messages;
      final hist = msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
      final recent = hist.length > 10 ? hist.sublist(hist.length - 10) : hist;
      final out = await ref.read(aiServiceProvider).chat(
            text: text,
            history: recent.map((m) => AiTurn(fromUser: m.fromUser, text: m.text)).toList(),
            system: _chatPrompt(),
            apiKey: s.apiKey,
            model: s.model,
          );
      _bot(out.isEmpty ? 'Hmm, aku belum punya jawaban untuk itu.' : out);
    } on AiException catch (e) {
      final a = '${e.friendly}. ${_localAnswer(text)}';
      _bot(a, speech: _speechOf(a));
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
