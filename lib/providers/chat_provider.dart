import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/models/reminder.dart';
import '../services/ai_service.dart';
import '../services/cycle_parser.dart';
import '../services/memory_parser.dart';
import '../services/vocab.dart';
import '../services/wellbeing_logic.dart';
import '../services/natural_parser.dart';
import '../services/note_parser.dart';
import '../services/voice_service.dart';
import 'cycle_provider.dart';
import 'muslim_provider.dart';
import 'calorie_provider.dart';
import '../services/calorie_logic.dart';
import '../services/islam_logic.dart';
import 'notes_provider.dart';
import 'reminder_provider.dart';
import 'settings_provider.dart';

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.reminderId, this.photoPath, this.sources = const [], this.noteIds = const [], this.tools = const []});
  final bool fromUser;
  final String text;
  final String? reminderId;
  final String? photoPath;
  final List<AiSource> sources;

  /// Catatan yang ditampilkan sebagai kartu di bawah balasan.
  final List<String> noteIds;

  /// Tombol alat bantu (latihan napas, jurnal, Healing119, …) di bawah balasan.
  final List<String> tools;

  ChatMessage withText(String t) => ChatMessage(fromUser: fromUser, text: t, reminderId: reminderId, photoPath: photoPath, sources: sources, noteIds: noteIds, tools: tools);

  Map<String, dynamic> toMap() => {
        'u': fromUser,
        't': text,
        'r': reminderId,
        'p': photoPath,
        's': [for (final x in sources) {'t': x.title, 'u': x.uri}],
        'n': noteIds,
        'k': tools,
      };
  factory ChatMessage.fromMap(Map m) => ChatMessage(
        fromUser: m['u'] == true,
        text: (m['t'] ?? '').toString(),
        reminderId: m['r']?.toString(),
        photoPath: m['p']?.toString(),
        sources: [
          for (final x in (m['s'] as List? ?? const []).whereType<Map>()) AiSource((x['t'] ?? '').toString(), (x['u'] ?? '').toString()),
        ],
        noteIds: [for (final x in (m['n'] as List? ?? const [])) x.toString()],
        tools: [for (final x in (m['k'] as List? ?? const [])) x.toString()],
      );
}

class ChatState {
  const ChatState({this.messages = const [], this.thinking = false, this.showTicketId, this.support = false});
  final List<ChatMessage> messages;
  final bool thinking;

  /// Sedang dalam mode "teman cerita" (pengguna curhat).
  final bool support;

  /// Bila diisi, layar asisten membuka tiket parkir pengingat ini.
  final String? showTicketId;
  ChatState copyWith({List<ChatMessage>? messages, bool? thinking, String? showTicketId, bool clearTicket = false, bool? support}) => ChatState(
        messages: messages ?? this.messages,
        thinking: thinking ?? this.thinking,
        showTicketId: clearTicket ? null : (showTicketId ?? this.showTicketId),
        support: support ?? this.support,
      );
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());

/// Dinaikkan untuk meminta layar utama membuka asisten (mis. dari Ruang Tenang).
final openChatRequestProvider = StateProvider<int>((ref) => 0);

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

  void _bot(String text, {String? reminderId, String? speech, List<AiSource> sources = const [], List<String> noteIds = const [], List<String> tools = const []}) {
    _push(ChatMessage(fromUser: false, text: text, reminderId: reminderId, sources: sources, noteIds: noteIds, tools: tools));
    if (_settings.voice) {
      // bacakan bagian awal saja agar tidak terlalu panjang
      var plain = (speech ?? text).replaceAll(RegExp(r'[#*_`>]'), '').replaceAll(RegExp(r'\n+'), '. ');
      if (plain.length > 320) {
        final cut = plain.lastIndexOf('.', 320);
        plain = plain.substring(0, cut > 40 ? cut + 1 : 320);
      }
      VoiceService.instance.speak(plain);
    }
  }

  void greet() {
    if (state.messages.isNotEmpty) return;
    final n = _settings.name.isEmpty ? '' : ' ${_settings.name}';
    _push(ChatMessage(
      fromUser: false,
      text: 'Halo$n! 👋 Aku asisten IngetZeon.\nBilang saja "ingatkan…" lewat ketikan atau suara, nanti aku buatkan pengingatnya. '
          'Aku juga bisa mengingat letak barangmu ("saya simpan kunci di laci") dan menjawab pertanyaan apa saja — jadwal, "di mana aku parkir?", resep, tips jualan, info terbaru, dan lainnya.',
    ));
  }

  Future<void> clear() async {
    state = const ChatState();
    await ref.read(settingsRepositoryProvider).set('chat', const []);
    greet();
  }

  String _kcalToday() {
    final c = ref.read(calorieProvider);
    final eaten = c.kcalOn(DateTime.now());
    final t = c.target;
    if (t == null) return 'Total hari ini **${fmtKcal(eaten)} kkal**. Atur berat & tinggi badan di menu Kalori supaya target harianmu dihitung otomatis.';
    final left = t.target - eaten;
    return 'Total hari ini **${fmtKcal(eaten)} / ${fmtKcal(t.target)} kkal** — ${left >= 0 ? 'sisa ${fmtKcal(left)} kkal 💪' : 'lebih ${fmtKcal(-left)} kkal, besok seimbangkan lagi ya 🙂'}';
  }

  /// Catat makan, tanya kalori, catat berat badan — tanpa internet.
  Future<bool> _answerCalorie(String text) async {
    final log = FoodParse.parse(text);
    if (log != null) {
      await ref.read(calorieProvider.notifier).add(log.meal, log.items, source: 'chat');
      final rows = [for (final x in log.items) '• ${x.food.emoji} ${x.food.name} ${fmtQty(x.qty)}× ${x.food.portion} — **${fmtKcal(x.food.kcal * x.qty)} kkal**'].join('\n');
      final sum = log.items.fold(0.0, (a, x) => a + x.food.kcal * x.qty);
      _bot('✅ Dicatat ke **${mealNames[log.meal]}** (${fmtKcal(sum)} kkal):\n$rows\n\n${_kcalToday()}', tools: const ['kalori'],
          speech: 'Dicatat ${fmtKcal(sum)} kilo kalori ke ${mealNames[log.meal]}.');
      return true;
    }
    final kg = FoodParse.weight(text);
    if (kg != null) {
      final c = ref.read(calorieProvider);
      await ref.read(calorieProvider.notifier).logWeight(kg);
      final p = ref.read(calorieProvider).profile;
      var extra = '';
      if (p != null) {
        final b = Body.bmi(kg, p.cm);
        extra = ' BMI kamu ${b.toStringAsFixed(1)} (${Body.bmiLabel(b).$1}).';
        final prev = c.weights.isNotEmpty ? c.weights.last.kg : null;
        if (prev != null && prev != kg) extra += kg < prev ? ' Turun ${fmtQty(double.parse((prev - kg).toStringAsFixed(1)))} kg dari catatan sebelumnya 🎉' : '';
      } else {
        extra = ' Isi juga tinggi badanmu di menu Kalori supaya BMI & target kalori dihitung.';
      }
      _bot('⚖️ Berat **${fmtQty(kg)} kg** dicatat.$extra', tools: const ['kalori']);
      return true;
    }
    final f = FoodParse.askCalorie(text);
    if (f != null) {
      _bot('${f.emoji} **${f.name}** (${f.portion}${f.gram > 0 ? ', ±${fmtQty(f.gram)} g' : ''}) sekitar **${fmtKcal(f.kcal)} kkal**.\nProtein ${fmtQty(f.protein)} g · Karbo ${fmtQty(f.carbs)} g · Lemak ${fmtQty(f.fat)} g.\n\nMau dicatat? Ketik misalnya "aku makan ${f.name.toLowerCase()}".',
          tools: const ['kalori']);
      return true;
    }
    if (FoodParse.askToday(text)) {
      _bot('🥗 ${_kcalToday()}', tools: const ['kalori']);
      return true;
    }
    return false;
  }

  Future<void> _scanFoodChat(String path) async {
    if (!_settings.hasAi) {
      _bot('📷 Untuk menghitung kalori dari foto, isi dulu kunci API Gemini (gratis) di Profil. Atau buka menu Kalori untuk cari makanan dari daftar.', tools: const ['kalori']);
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final r = await ref.read(aiServiceProvider).scanFood(bytes, apiKey: _settings.apiKey, model: _settings.model);
      if (r.items.isEmpty) {
        _bot(r.note.isNotEmpty ? '🤔 ${r.note}' : '🤔 Aku tidak melihat makanan di foto itu.');
        return;
      }
      double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
      final foods = [
        for (final x in r.items) (food: FoodItem(foodEmoji('${x['name']}'), '${x['name']}', const [], '${x['portion'] ?? '1 porsi'}', d(x['gram']), d(x['kcal']), d(x['protein']), d(x['carbs']), d(x['fat']), 'foto'), qty: 1.0),
      ];
      final meal = mealByHour(DateTime.now().hour);
      await ref.read(calorieProvider.notifier).add(meal, foods, source: 'foto');
      final sum = foods.fold(0.0, (a, x) => a + x.food.kcal);
      final rows = [for (final x in foods) '• ${x.food.name} (${x.food.portion}) — **${fmtKcal(x.food.kcal)} kkal**'].join('\n');
      _bot('📷 Dari fotomu, perkiraan **${fmtKcal(sum)} kkal** — dicatat ke ${mealNames[meal]}:\n$rows\n\n${_kcalToday()}\n\n*Perkiraan AI, porsinya bisa diubah di menu Kalori.*',
          tools: const ['kalori']);
    } catch (_) {
      _bot('Foto makanan belum bisa dibaca sekarang. Coba lagi, atau catat lewat menu Kalori.', tools: const ['kalori']);
    }
  }

  /// Jadwal sholat, kiblat, Hijriah & doa — dijawab langsung tanpa internet.
  bool _answerIslam(String text) {
    final doa = IslamAsk.doa(text);
    if (doa != null) {
      _bot('${doa.emoji} **Doa ${doa.judul.toLowerCase()}**\n\n${doa.arab}\n\n*${doa.latin}*\n\nArtinya: "${doa.arti}"\n(${doa.sumber})',
          tools: ['muslim:doa:${doa.judul}', 'muslim'], speech: 'Ini doa ${doa.judul.toLowerCase()}. Artinya: ${doa.arti}');
      return true;
    }
    final k = IslamAsk.prayer(text);
    if (k == null) return false;
    final s = ref.read(muslimProvider);
    final now = DateTime.now();
    if (k == 'kiblat') {
      final q = PrayerCalc.qibla(s.lat, s.lng);
      _bot('🧭 Arah kiblat dari **${s.city}**: **${q.toStringAsFixed(0)}°** dari utara (kira-kira ke barat laut). Buka kompas kiblat biar dipandu sampai pas 👇',
          tools: const ['muslim:kiblat']);
      return true;
    }
    if (k == 'hijri') {
      _bot('📅 Hari ini **${Hijri.fromDate(now)}** (perkiraan, bisa beda ±1 hari dari ketetapan resmi).', tools: const ['muslim']);
      return true;
    }
    final t = s.timesOn(now);
    if (k == 'jadwal') {
      final n = s.next(now);
      final rows = [for (final x in const ['imsak', 'subuh', 'terbit', 'dzuhur', 'ashar', 'maghrib', 'isya']) '• ${prayerNames[x]}: **${PrayerCalc.hm(t[x]!)}**'].join('\n');
      _bot('🕌 Jadwal sholat hari ini di **${s.city}**:\n$rows\n\nBerikutnya ${prayerNames[n.key]} pukul ${fmtTime(n.at)}.',
          tools: const ['muslim'], speech: 'Sholat berikutnya ${prayerNames[n.key]} pukul ${fmtTime(n.at)}.');
      return true;
    }
    final at = PrayerCalc.at(now, t[k]!);
    final name = prayerNames[k] ?? k;
    String extra;
    if (at.isAfter(now)) {
      final d = at.difference(now);
      final h = d.inHours, m = d.inMinutes % 60;
      extra = '— ${h > 0 ? '$h jam ' : ''}$m menit lagi.';
    } else {
      final tm = s.timesOn(now.add(const Duration(days: 1)));
      extra = '(sudah lewat — besok pukul ${PrayerCalc.hm(tm[k]!)}).';
    }
    _bot('🕌 $name hari ini di **${s.city}** pukul **${fmtTime(at)}** $extra', tools: const ['muslim']);
    return true;
  }

  Future<void> send(String input, {String? photoPath}) async {
    final text = input.trim();
    if (text.isEmpty || state.thinking) return;
    _push(ChatMessage(fromUser: true, text: text, photoPath: photoPath));
    final wasSupport = state.support;
    state = state.copyWith(thinking: true, support: false);
    try {
      final lower = text.toLowerCase();
      // keselamatan dulu: tanda krisis selalu dijawab dengan bantuan, apa pun isinya
      if (photoPath == null && Feelings.isCrisis(text)) {
        final r = SupportReply.crisis();
        _bot(r.text, tools: r.tools, speech: 'Terima kasih sudah mau cerita. Kamu tidak sendirian. Tolong hubungi Healing119, telepon 119 lalu tekan 8.');
        state = state.copyWith(support: true);
        return;
      }
      final testReq = photoPath == null ? Feelings.testRequest(text) : null;
      if (testReq != null) {
        final t = PsyTest.byId(testReq);
        _bot(
            t == null
                ? 'Ada ${PsyTest.all.length} tes yang bisa kamu coba: stres-cemas-depresi, suasana hati, kecemasan, burnout, kebahagiaan, kesepian, percaya diri, tidur, dan trauma. Mulai dari yang paling kamu rasakan ya 🌈\n*Hasilnya skrining, bukan diagnosis.*'
                : '${t.emoji} **Tes ${t.title}** — ${t.items.length} pertanyaan singkat (${t.short}). Ketuk tombol di bawah untuk mulai, semangat! 💪\n*Hasilnya skrining, bukan diagnosis.*',
            tools: t == null ? const ['tes:dass21', 'tes:phq9', 'tes:gad7', 'tes:burnout', 'tes:menu'] : ['tes:${t.id}']);
        return;
      }
      if (photoPath == null && !RegExp(r'^(?:tolong\s+|tlg\s+)?(?:ingatkan|ingetin|ingatin|ingetkan|alarm|catat|catet|setel|bangunkan)').hasMatch(lower) && _answerIslam(text)) {
        return;
      }
      if (photoPath == null && await _answerCalorie(text)) return;
      if (photoPath != null && RegExp(r'kalori|kkal|makan|makanan|gizi|diet').hasMatch(lower)) {
        await _scanFoodChat(photoPath);
        return;
      }
      final aboutParking = lower.contains('parkir');
      final asksWhere = RegExp(r'di ?mana|\bmana\b').hasMatch(lower);
      final asksTicket = RegExp(r'tiket|karcis|qr|barcode').hasMatch(lower) && RegExp(r'tampil|lihat|buka|mana|tunjuk|show').hasMatch(lower);
      final store = aboutParking ? null : MemoryParser.parseStore(text);
      final noteDraft = (aboutParking || photoPath != null) ? null : NoteParser.parseStore(text);
      final cycNow = ref.read(cycleProvider).enabled ? ref.read(cycleProvider.notifier).info : null;
      final cyc = (aboutParking || photoPath != null) ? null : CycleParser.parse(text, ongoing: cycNow?.ongoing ?? false);
      if (cyc != null) {
        await _answerCycle(cyc);
      } else if (((aboutParking && asksWhere) || asksTicket) && photoPath == null) {
        _answerParking(showTicket: asksTicket);
      } else if (noteDraft != null && (noteDraft.secret || store == null)) {
        await _saveNote(noteDraft);
      } else if (!aboutParking && MemoryParser.isWhereQuestion(lower) && photoPath == null && _answerItem(text)) {
        // dijawab dari catatan barang
      } else if (store != null) {
        await _saveItem(store, photoPath);
      } else if (!aboutParking && photoPath == null && await _answerNote(text)) {
        // dijawab dari catatan
      } else if (!aboutParking && MemoryParser.isWhereQuestion(lower) && !_settings.hasAi) {
        _bot('Aku belum punya catatan soal itu. Bilang dulu, misalnya: "saya simpan kunci motor di laci meja", nanti aku ingatkan.');
      } else {
        final intent = Vocab.classify(text);
        final feel = photoPath == null ? Feelings.detect(text) : null;
        if (intent == 'reminder' || aboutParking || photoPath != null) {
          await _handleReminder(text, photoPath: photoPath);
        } else if (feel != null && intent != 'schedule') {
          await _support(text, feel);
        } else if (wasSupport && intent == 'other' && Vocab.smallTalk(text, name: _settings.name, greeting: greeting()) == null && Vocab.calc(text) == null) {
          await _support(text, null);
        } else {
          await _handleChat(text, scheduleQuestion: intent == 'schedule');
        }
      }
    } finally {
      state = state.copyWith(thinking: false);
    }
  }

  Future<void> _answerCycle(CycleIntent c) async {
    final n = ref.read(cycleProvider.notifier);
    final now = DateTime.now();
    final today = dateOnly(now);
    final date = DateTime(today.year, today.month, today.day - c.daysAgo);
    final when = c.daysAgo == 0 ? 'hari ini' : (c.daysAgo == 1 ? 'kemarin' : '${c.daysAgo} hari lalu (${fmtDateShort(date)})');
    String inDays(DateTime d) {
      final k = daysBetween(today, d);
      return k == 0 ? 'hari ini' : (k == 1 ? 'besok' : (k > 0 ? '$k hari lagi' : '${-k} hari lalu'));
    }

    const noData = 'Aku belum punya data siklus haidmu 🌸\nBilang saja saat haid datang, misalnya **"haid aku mulai hari ini"**, '
        '**"mens kemarin"**, atau **"datang bulan 3 hari lalu"** — atau isi di **Profil → Pengingat haid**.';
    final info = ref.read(cycleProvider).enabled ? n.info : null;

    switch (c.cmd) {
      case CycleCmd.start:
        if (info != null && info.ongoing && daysBetween(info.lastStart, date) < 10) {
          _bot('Haidmu sudah tercatat mulai ${fmtDateShort(info.lastStart)} (hari ke-${info.day}) 🌸\n'
              'Perkiraan selesai **${fmtDateShort(info.lastEnd)}** (${inDays(info.lastEnd)}). Kalau sudah selesai, bilang **"haid selesai"**.');
          return;
        }
        await n.logStart(date);
        final i = n.info!;
        _bot('Oke, hari pertama haid dicatat **$when** 🌸\n'
            '• Perkiraan selesai: **${fmtDateLong(i.lastEnd)}** (${inDays(i.lastEnd)})\n'
            '• Haid berikutnya: **${fmtDateLong(i.next)}**\n'
            '${ref.read(cycleProvider).remind ? 'Aku ingatkan saat perkiraan selesai & 2 hari sebelum haid berikutnya. ' : ''}'
            'Jaga kondisi & minum air putih yang cukup ya 💧',
            speech: 'Oke, hari pertama haid dicatat $when. Perkiraan selesai ${inDays(i.lastEnd)}.');
      case CycleCmd.end:
        final ok = await n.logEnd(date);
        if (!ok) {
          _bot(info == null
              ? noData
              : 'Haid terakhirmu (${fmtDateShort(info.lastStart)}) sudah tercatat selesai ${fmtDateShort(info.lastEnd)}. '
                  'Kalau haid baru datang, bilang **"haid aku mulai hari ini"**.');
          return;
        }
        final i = n.info!;
        _bot('Sip, haid selesai dicatat **$when** 🌿 Lamanya ${daysBetween(i.lastStart, i.lastEnd) + 1} hari.\n'
            'Haid berikutnya diperkirakan **${fmtDateLong(i.next)}** (${inDays(i.next)}).',
            speech: 'Sip, haid selesai dicatat $when.');
      case CycleCmd.remindOff:
        await n.setRemind(false);
        _bot('Oke, pengingat haid dimatikan. Nyalakan lagi kapan saja dengan bilang **"ingatkan aku kalau mau haid"** 🙂');
      case CycleCmd.remindOn:
        if (info == null) {
          _bot('Siap, nanti aku ingatkan! Tapi aku perlu tahu dulu kapan haid terakhirmu.\n$noData');
          return;
        }
        await n.setRemind(true);
        _bot('Siap, pengingat haid aktif 🔔\n'
            '${info.ongoing ? '• Perkiraan haid selesai: **${fmtDateShort(info.lastEnd)}** (${inDays(info.lastEnd)}) — aku tanyakan apakah sudah selesai\n' : ''}'
            '• 2 hari sebelum haid: **${fmtDateShort(DateTime(info.next.year, info.next.month, info.next.day - 2))}**\n'
            '• Hari perkiraan haid: **${fmtDateLong(info.next)}** (${inDays(info.next)})',
            speech: 'Siap, pengingat haid aktif.');
      case CycleCmd.askEnd:
        if (info == null) {
          _bot(noData);
          return;
        }
        if (info.onPeriod && !info.lastEnded) {
          _bot('Haidmu sekarang hari ke-**${info.day}**. Perkiraan selesai **${fmtDateLong(info.lastEnd)}** (${inDays(info.lastEnd)}) '
              '— rata-rata haidmu ±${info.periodLen} hari.\nKalau sudah selesai, bilang **"haid selesai"** ya.',
              speech: 'Perkiraan haid selesai ${inDays(info.lastEnd)}.');
        } else {
          final nextEnd = DateTime(info.next.year, info.next.month, info.next.day + info.periodLen - 1);
          _bot('Haid terakhirmu selesai **${fmtDateShort(info.lastEnd)}**.\n'
              'Haid berikutnya diperkirakan **${fmtDateShort(info.next)} – ${fmtDateShort(nextEnd)}** (mulai ${inDays(info.next)}).',
              speech: 'Haid berikutnya diperkirakan ${inDays(info.next)}.');
        }
      case CycleCmd.askDay:
        if (info == null) {
          _bot(noData);
          return;
        }
        _bot(info.onPeriod
            ? 'Hari ini haid hari ke-**${info.day}** 🌸 Perkiraan selesai ${fmtDateShort(info.lastEnd)} (${inDays(info.lastEnd)}).'
            : 'Kamu sedang tidak haid — sekarang hari ke-**${info.day}** siklusmu. Haid berikutnya **${fmtDateShort(info.next)}** (${inDays(info.next)}).');
      case CycleCmd.askLate:
        if (info == null) {
          _bot(noData);
          return;
        }
        if (info.onPeriod) {
          _bot('Haidmu sedang berlangsung (hari ke-${info.day}), jadi tidak terlambat 🌸');
        } else if (info.lateDays > 0) {
          _bot('Haidmu terlambat **${info.lateDays} hari** dari perkiraan (${fmtDateShort(info.next)}).\n'
              'Siklus bisa bergeser karena stres, kurang tidur, kelelahan, atau perubahan berat badan. '
              'Kalau terlambat lebih dari seminggu atau ada kemungkinan hamil, coba tes kehamilan atau periksa ke dokter.\n'
              'Kalau haid sudah datang, bilang **"haid aku mulai hari ini"**.');
        } else {
          _bot('Belum terlambat kok 🙂 Haid berikutnya diperkirakan **${fmtDateLong(info.next)}** (${inDays(info.next)}).');
        }
      case CycleCmd.askFertile:
        if (info == null) {
          _bot(noData);
          return;
        }
        final fert = info.inFertile(now)
            ? 'Saat ini kamu **sedang masa subur** (sampai ${fmtDateShort(info.fertileEnd)}).'
            : 'Masa subur berikutnya: **${fmtDateShort(info.fertileStart)} – ${fmtDateShort(info.fertileEnd)}**.';
        _bot('$fert\nOvulasi sekitar **${fmtDateShort(info.ovulation)}**.\n(Perkiraan saja, bukan alat kontrasepsi.)', speech: fert);
      case CycleCmd.askNext:
        if (info == null) {
          _bot(noData);
          return;
        }
        if (info.onPeriod && !info.lastEnded) {
          _bot('Kamu sedang haid hari ke-**${info.day}** 🌸 Perkiraan selesai **${fmtDateShort(info.lastEnd)}** (${inDays(info.lastEnd)}).\n'
              'Haid berikutnya sekitar **${fmtDateLong(info.next)}**.');
          return;
        }
        final st = info.status();
        _bot('**${st.title}** — ${st.sub}.\n'
            'Masa subur: ${fmtDateShort(info.fertileStart)} – ${fmtDateShort(info.fertileEnd)} · siklus rata-rata ${info.cycleLen} hari.\n'
            '(Perkiraan saja, bukan alat kontrasepsi.)',
            speech: st.title);
    }
  }

  Future<void> _saveNote(NoteDraft d) async {
    final n = await ref.read(notesProvider.notifier).add(d);
    if (d.secret) {
      // jangan biarkan isi rahasia tersimpan di riwayat chat (riwayat juga dikirim ke Gemini)
      final msgs = [...state.messages];
      for (var i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].fromUser) {
          msgs[i] = msgs[i].withText(msgs[i].text.replaceAll(d.value, '••••••'));
          break;
        }
      }
      state = state.copyWith(messages: msgs);
      ref.read(settingsRepositoryProvider).set('chat', msgs.map((e) => e.toMap()).toList());
      _bot('🔒 Tersimpan aman: **${NoteParser.you(d.label)}**.\nIsinya dienkripsi di HP ini, tidak dikirim ke AI, dan hanya bisa dibuka dengan sidik jari/PIN HP. '
          'Tanya kapan saja, misalnya **"apa ${d.label.replaceAll(RegExp(r'\b(saya|aku|gue|gw)\b', caseSensitive: false), 'saya').trim()}?"**',
          noteIds: [n.id], speech: 'Tersimpan aman.');
    } else {
      final q = NoteParser.tokens(d.text).where((t) => !RegExp(r'^\d+$').hasMatch(t) && !NoteParser.isGeneric(t)).take(2).join(' ');
      _bot('📝 Oke, aku catat: **${NoteParser.you(d.text)}**.\nTanya kapan saja, misalnya **"${q.isEmpty ? 'lihat catatan saya' : 'berapa $q saya?'}"**',
          noteIds: [n.id], speech: 'Oke, aku catat. ${NoteParser.you(d.text)}.');
    }
  }

  /// Menjawab pertanyaan dari catatan. false = bukan pertanyaan catatan / tidak ketemu.
  Future<bool> _answerNote(String text) async {
    final q = NoteParser.parseQuery(text);
    if (q == null) return false;
    final notes = ref.read(notesProvider);
    switch (q.kind) {
      case NoteQueryKind.list:
        if (notes.isEmpty) {
          _bot('Belum ada catatan. Coba bilang **"catat saya punya emas 10 gr"** atau **"catat password fb saya …"** 📝');
        } else {
          _bot('Ini catatanmu (${notes.length}) 📝', noteIds: notes.take(10).map((n) => n.id).toList());
        }
        return true;
      case NoteQueryKind.delete:
        final m = q.tokens.isEmpty ? <Note>[] : NoteParser.match(notes, q.tokens);
        if (m.isEmpty) {
          if (!RegExp(r'catatan').hasMatch(text.toLowerCase())) return false;
          _bot('Aku tidak menemukan catatan itu. Ketik **"lihat semua catatan"** untuk melihat daftarnya.');
          return true;
        }
        final n = m.first;
        await ref.read(notesProvider.notifier).remove(n.id);
        _bot('🗑️ Catatan **${n.secret ? n.label : NoteParser.you(n.value)}** sudah dihapus.');
        return true;
      case NoteQueryKind.find:
        final m = NoteParser.match(notes, q.tokens, personal: q.personal);
        if (m.isEmpty) {
          // tanya rahasia yang tidak ada → jangan lempar ke AI
          if (NoteParser.secretRe.hasMatch(text) && q.personal) {
            final others = notes.where((n) => n.secret).take(5).map((n) => n.label).join(', ');
            _bot('Aku belum punya catatan untuk itu 🔒${others.isEmpty ? '' : '\nYang tersimpan: $others.'}\n'
                'Untuk menyimpan, bilang misalnya **"catat password ig saya …"**.');
            return true;
          }
          return false;
        }
        // pertanyaan lebih luas dari catatan (mis. "berapa harga emas saya") → biar Gemini yang hitung
        if (!NoteParser.fullMatch(m.first, q.tokens) && _settings.hasAi && !m.first.secret) return false;
        final top = m.take(3).toList();
        final n = top.first;
        if (n.secret) {
          _bot('🔒 Ini **${NoteParser.you(n.label)}**. Ketuk ikon 👁 untuk melihat isinya (perlu sidik jari/PIN HP).',
              noteIds: top.where((x) => x.secret).map((x) => x.id).toList(), speech: 'Ini ${NoteParser.you(n.label)}. Ketuk ikon mata untuk melihat isinya.');
        } else {
          final more = top.length > 1 ? '\nCatatan lain yang mirip:\n${top.skip(1).map((x) => '• ${x.secret ? x.label : NoteParser.you(x.value)}').join('\n')}' : '';
          _bot('📝 Menurut catatanmu: **${NoteParser.you(n.value)}** (dicatat ${dayLabel(n.createdAt).toLowerCase()}).$more',
              noteIds: [n.id], speech: 'Menurut catatanmu, ${NoteParser.you(n.value)}.');
        }
        return true;
    }
  }

  /// Mulai sesi "teman cerita" (dari Ruang Tenang).
  void startSupport() {
    final n = _settings.name.isEmpty ? '' : ', ${_settings.name}';
    _push(ChatMessage(
      fromUser: false,
      text: 'Hai$n 💛 Aku di sini buat dengerin. Ceritakan apa saja yang sedang kamu rasakan — tidak ada yang salah, dan aku tidak akan menghakimi.\n\n'
          'Kamu bisa mulai dengan, misalnya: "aku lagi cemas soal kerjaan" atau "hari ini rasanya capek banget".',
      tools: const [Tool.napas, Tool.grounding, 'tes:menu'],
    ));
    state = state.copyWith(support: true);
  }

  static const _supportPrompt =
      'Kamu sedang berperan sebagai "Teman Cerita" di aplikasi IngetZeon: pendengar yang hangat, tenang, dan tidak menghakimi, '
      'dalam bahasa Indonesia sehari-hari yang lembut. Pedoman:\n'
      '1. Validasi perasaan pengguna dulu dengan tulus dan spesifik pada ceritanya, jangan langsung menceramahi.\n'
      '2. Ajukan SATU pertanyaan terbuka untuk memahami lebih dalam. Jawaban singkat (maksimal ±120 kata).\n'
      '3. Bila cocok, tawarkan satu langkah kecil berbasis bukti: napas lambat/napas kotak, grounding 5-4-3-2-1, menulis jurnal, '
      'aktivitas kecil yang menyenangkan, tidur teratur, atau menghubungi orang terdekat. Aplikasi punya tombol untuk latihan napas, grounding, jurnal, dan tes psikologi.\n'
      '4. JANGAN mendiagnosis, jangan menyarankan obat atau dosis, dan jangan mengaku sebagai psikolog atau manusia.\n'
      '5. Bila keluhan sudah lama (lebih dari 2 minggu), berat, atau mengganggu aktivitas, sarankan dengan lembut untuk bicara dengan psikolog/psikiater/puskesmas, '
      'atau layanan gratis Healing119 (telepon 119 lalu tekan 8, atau healing119.id).\n'
      '6. Bila ada tanda ingin menyakiti diri atau bunuh diri: tanggapi dengan peduli, minta dia segera menghubungi Healing119 (119 tekan 8) atau 112 bila dalam bahaya, '
      'dan orang yang dipercaya. Jangan pernah memberi informasi cara menyakiti diri.\n'
      '7. Jangan mengulang kalimat yang sama dengan balasan sebelumnya.';

  Future<void> _support(String text, FeelingResult? feel) async {
    final local = feel == null ? SupportReply.listening() : SupportReply.forFeeling(feel, name: _settings.name);
    final s = _settings;
    if (s.hasAi) {
      try {
        final msgs = state.messages;
        final hist = msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
        final recent = hist.length > 12 ? hist.sublist(hist.length - 12) : hist;
        final out = await ref.read(aiServiceProvider).chat(
              text: text,
              history: recent.map((m) => AiTurn(fromUser: m.fromUser, text: m.text)).toList(),
              system: '$_supportPrompt\nNama pengguna: ${s.name.isEmpty ? '(belum diisi)' : s.name}. Waktu sekarang: ${fmtDateLong(DateTime.now())} ${fmtTime(DateTime.now())}.',
              apiKey: s.apiKey,
              model: s.model,
            );
        if (out.text.trim().isNotEmpty) {
          _bot(out.text, tools: local.tools);
          state = state.copyWith(support: true);
          return;
        }
      } on AiException {
        // pakai jawaban lokal di bawah
      }
    }
    _bot(local.text, tools: local.tools);
    state = state.copyWith(support: true);
  }

  void ticketShown() => state = state.copyWith(clearTicket: true);

  bool _answerItem(String text) {
    final found = MemoryParser.findItems(ref.read(remindersProvider), text);
    if (found.isEmpty) return false;
    final r = found.first;
    final more = found.length > 1 ? '\nAku juga punya catatan lain yang mirip: ${found.skip(1).take(2).map((x) => '${x.item} ${x.place}').join('; ')}.' : '';
    _bot('**${MemoryParser.cap(r.item!)}** kamu ada ${r.place} 📍 (dicatat ${dayLabel(r.createdAt).toLowerCase()} jam ${fmtTime(r.createdAt)}).$more',
        reminderId: r.id, speech: '${r.item} kamu ada ${r.place}.');
    return true;
  }

  Future<void> _saveItem(StoredItem s, String? photoPath) async {
    final now = DateTime.now();
    final r = Reminder.create(
      title: '${MemoryParser.cap(s.item)} ${s.place}',
      scheduledAt: now,
      category: ReminderCategory.barang,
      alarm: false,
      photoPath: photoPath,
      item: s.item,
      place: s.place,
    );
    await ref.read(remindersProvider.notifier).upsert(r);
    _bot('Oke, aku ingat: **${MemoryParser.cap(s.item)}** ${s.place}${photoPath != null ? ' (beserta fotonya 📸)' : ''}. Tanya saja nanti, "di mana ${s.item} saya?"',
        reminderId: r.id, speech: 'Oke, aku ingat. ${s.item} ${s.place}.');
  }

  void _answerParking({bool showTicket = false}) {
    final p = activeParking(ref.read(remindersProvider));
    if (p == null) {
      _bot('Aku belum punya catatan parkir terbaru. Foto lokasi parkirmu lalu bilang, misalnya, "saya parkir di B2".');
      return;
    }
    final lokasi = p.title.replaceFirst(RegExp(r'^parkir di ', caseSensitive: false), '');
    _bot('Kamu parkir di **$lokasi** 📍 (dicatat ${dayLabel(p.createdAt).toLowerCase()} jam ${fmtTime(p.createdAt)}).${p.hasTicket ? ' Tiketnya juga tersimpan.' : ''}',
        reminderId: p.id, speech: 'Kamu parkir di $lokasi.');
    if (showTicket && p.hasTicket) state = state.copyWith(showTicketId: p.id);
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
    var bumped = false;
    if (data.alarm && data.repeat == RepeatType.once && !at.isAfter(DateTime.now())) {
      at = addDays(at, 1);
      bumped = true;
    }

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
    final lewat = bumped ? '\n(Jam itu hari ini sudah lewat, jadi aku pasang untuk besok. Ubah di detail pengingat kalau perlu.)' : '';
    _bot('Siap! Aku ingatkan **${r.title}** $when. ✅$lewat$note',
        reminderId: r.id, speech: 'Siap! Aku ingatkan ${r.title} $speechWhen.');
  }

  String _localAnswer(String text) {
    final t = Vocab.normalize(text);
    final list = ref.read(remindersProvider);
    final now = DateTime.now();
    if (Vocab.classify(text) != 'schedule') {
      final st = Vocab.smallTalk(text, name: _settings.name, greeting: greeting());
      if (st != null) return st;
    }
    final asksSchedule = RegExp(r'jadwal|agenda|acara|kegiatan|pengingat|reminder|ada apa|rencana|tugas').hasMatch(t);
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
    const opener = ['Hmm, aku belum paham maksudnya 🤔', 'Maaf, aku belum mengerti kalimat itu.', 'Aku belum bisa menjawab itu tanpa Gemini.'];
    return '${opener[DateTime.now().millisecond % 3]}\nCoba bilang: "ingatkan besok jam 7 pagi olahraga", "jadwal hari ini?", atau ketik "bantuan" untuk melihat semua yang bisa aku lakukan.'
        '${_settings.hasAi ? '' : '\n\nUntuk tanya apa saja (pengetahuan umum, resep, dll.), isi kunci Gemini di menu Profil.'}';
  }

  String _speechOf(String s) =>
      s.replaceAllMapped(RegExp(r'(\d{2})\.(\d{2})'), (m) => m[2] == '00' ? 'jam ${int.parse(m[1]!)}' : 'jam ${int.parse(m[1]!)} lewat ${int.parse(m[2]!)}')
          .replaceAll('jam jam', 'jam');

  String _chatPrompt() {
    final list = ref.read(remindersProvider);
    final now = DateTime.now();
    String fmt(List<Occurrence> l) =>
        l.isEmpty ? '(kosong)' : l.map((x) => '- ${fmtTime(x.at)} ${x.reminder.title}${x.done ? ' (selesai)' : ''}').join('\n');
    return 'Kamu adalah "Asisten IngetZeon", asisten pribadi yang ramah, cerdas, dan serba bisa, berbahasa Indonesia santai dan sopan.\n'
        'Kamu boleh menjawab pertanyaan APA SAJA: pengetahuan umum, berita & info terbaru (pakai Google Search bila perlu), resep, '
        'tips usaha & jualan online, hitung-hitungan, terjemahan, ide konten, kesehatan umum, dan lain-lain.\n'
        'Jawab langsung ke intinya. Pertanyaan sederhana cukup 1–3 kalimat; penjelasan/langkah boleh lebih panjang dengan poin-poin singkat. Jangan pakai tabel.\n'
        'Sekarang: ${fmtDateLong(now)} jam ${fmtTime(now)}. Nama pengguna: ${_settings.name.isEmpty ? 'tidak diketahui' : _settings.name}.\n'
        'Jadwal hari ini:\n${fmt(occurrencesOn(list, now))}\n'
        'Jadwal besok:\n${fmt(occurrencesOn(list, addDays(dateOnly(now), 1)))}\n'
        'Catatan barang/lokasi yang pernah user simpan (jawab dari sini kalau ditanya):\n'
        '${list.where((r) => !r.alarm).take(30).map((r) => '- ${r.title}${r.hasTicket ? ' (ada tiket tersimpan)' : ''} — dicatat ${fmtDateShort(r.createdAt)} ${fmtTime(r.createdAt)}').join('\n').ifEmpty('(kosong)')}\n'
        'Catatan pribadi pengguna (pakai untuk menjawab & menghitung; catatan rahasia seperti password TIDAK ada di sini dan jangan ditebak):\n'
        '${ref.read(notesProvider).where((n) => !n.secret).take(40).map((n) => '- ${n.value} (dicatat ${fmtDateShort(n.createdAt)})').join('\n').ifEmpty('(kosong)')}\n'
        'Kalau pengguna ingin membuat pengingat, sarankan dia mengetik kalimat yang diawali kata "ingatkan", '
        'contoh: "ingatkan besok jam 7 olahraga".';
  }

  Future<void> _handleChat(String text, {bool scheduleQuestion = false}) async {
    final s = _settings;
    if (!s.hasAi || scheduleQuestion) {
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
      _bot(out.text.isEmpty ? 'Hmm, aku belum punya jawaban untuk itu.' : out.text, sources: out.sources);
    } on AiException catch (e) {
      final a = '${e.friendly}. ${_localAnswer(text)}';
      _bot(a, speech: _speechOf(a));
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

extension _IfEmpty on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
