import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/chat_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';
import '../../services/photo_service.dart';
import '../../services/voice_service.dart';
import '../widgets/common.dart';
import '../widgets/photo_view.dart';
import 'ticket_screens.dart';
import '../widgets/reminder_tile.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _listening = false;
  bool _heardFinal = false;
  String? _pendingPhoto;

  static const _suggestions = [
    'Saya parkir di B2, ingatkan saya',
    'Di mana aku parkir?',
    'Tampilkan tiket parkir',
    'Saya simpan kunci motor di laci meja',
    'Di mana kunci motor saya?',
    'Ingatkan besok jam 7 pagi olahraga',
    'Ingatkan minum obat setiap hari jam 8 malam',
    'Jadwal hari ini apa?',
    'Kapan haid berikutnya?',
    'Ingatkan rapat tiap senin jam 9',
    'Ingatkan 10 menit lagi angkat jemuran',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).greet();
      _toBottom();
    });
  }

  @override
  void dispose() {
    VoiceService.instance.stopListening();
    VoiceService.instance.stopSpeaking();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _ctrl.text).trim();
    if (t.isEmpty) {
      if (_pendingPhoto != null) showToast(context, 'Tambahkan keterangan, mis. "parkir di B2"');
      return;
    }
    _ctrl.clear();
    final photo = _pendingPhoto;
    setState(() => _pendingPhoto = null);
    if (_listening) await VoiceService.instance.stopListening();
    await ref.read(chatProvider.notifier).send(t, photoPath: photo);
  }

  Future<void> _takePhoto() async {
    try {
      final p = await PhotoService.instance.pick(camera: true);
      if (p == null) return;
      await PhotoService.instance.delete(_pendingPhoto);
      setState(() => _pendingPhoto = p);
      if (_ctrl.text.trim().isEmpty) {
        _ctrl.text = 'Saya parkir di ';
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      }
    } catch (_) {
      showToast(context, 'Kamera tidak bisa dibuka');
    }
  }

  Future<void> _toggleMic() async {
    final voice = VoiceService.instance;
    if (_listening) {
      await voice.stopListening();
      return;
    }
    _heardFinal = false;
    final ok = await voice.listen(
      onResult: (text, isFinal) {
        _ctrl.text = text;
        _ctrl.selection = TextSelection.collapsed(offset: text.length);
        if (isFinal && text.trim().isNotEmpty && !_heardFinal) {
          _heardFinal = true;
          setState(() => _listening = false);
          _send(text);
        }
      },
      onStatus: (s) {
        if (!mounted) return;
        if (s == 'listening') setState(() => _listening = true);
        if (s == 'notListening' || s == 'done') setState(() => _listening = false);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _listening = false);
        if (e.contains('no_match') || e.contains('speech_timeout')) {
          showToast(context, 'Tidak terdengar suara, coba lagi');
        } else if (e.contains('permission')) {
          showToast(context, 'Izin mikrofon ditolak. Aktifkan di Pengaturan HP.');
        } else {
          showToast(context, 'Input suara gagal ($e)');
        }
      },
    );
    if (!ok && mounted) {
      showToast(context, 'Mikrofon tidak tersedia. Pastikan izin mikrofon aktif dan aplikasi Google terpasang.');
    } else if (mounted) {
      setState(() => _listening = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final hasAi = ref.watch(settingsProvider.select((s) => s.hasAi));
    final reminders = ref.watch(remindersProvider);
    ref.listen(chatProvider, (prev, next) {
      _toBottom();
      final id = next.showTicketId;
      if (id != null && id != prev?.showTicketId) {
        ref.read(chatProvider.notifier).ticketShown();
        final r = ref.read(remindersProvider.notifier).byId(id);
        if (r != null) Future.delayed(const Duration(milliseconds: 500), () { if (mounted) openTicket(context, r); });
      }
    });
    final userSent = chat.messages.any((m) => m.fromUser);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28), onPressed: () => Navigator.pop(context)),
        ),
        titleSpacing: 4,
        title: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Asisten IngetZeon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: hasAi ? const Color(0xFF1FB57A) : const Color(0xFFF2A11B), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(hasAi ? 'Gemini aktif' : 'Mode offline', style: TextStyle(fontSize: 12, color: context.muted)),
            ]),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Bersihkan chat?', message: 'Riwayat percakapan dihapus. Pengingat tetap aman.', ok: 'Bersihkan');
              if (ok) ref.read(chatProvider.notifier).clear();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AestheticBackground(
        child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: chat.messages.length + (chat.thinking ? 1 : 0),
              itemBuilder: (c, i) {
                if (i >= chat.messages.length) return const _Typing();
                final m = chat.messages[i];
                return _Bubble(message: m, reminderExists: m.reminderId != null && reminders.any((r) => r.id == m.reminderId));
              },
            ),
          ),
          if (!userSent)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (c, i) => ActionChip(
                  label: Text(_suggestions[i], style: const TextStyle(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  backgroundColor: context.card,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () => _send(_suggestions[i]),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              border: Border(top: BorderSide(color: context.line)),
            ),
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingPhoto != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      PhotoThumb(_pendingPhoto!, height: 56, width: 56, radius: 12),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Foto terlampir — tulis atau ucapkan keterangannya', style: TextStyle(fontSize: 12.5, color: context.muted))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          PhotoService.instance.delete(_pendingPhoto);
                          setState(() => _pendingPhoto = null);
                        },
                      ),
                    ]),
                  ),
                if (_listening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.graphic_eq_rounded, color: AppColors.pink, size: 18),
                      const SizedBox(width: 8),
                      const Text('Mendengarkan… bicara sekarang', style: TextStyle(color: AppColors.pink, fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Tanya apa saja…',
                          prefixIcon: IconButton(
                            tooltip: 'Foto',
                            icon: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                            onPressed: _takePhoto,
                          ),
                          fillColor: context.card2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RoundBtn(
                      icon: _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      background: _listening ? AppColors.pink : AppColors.primary.withValues(alpha: .12),
                      foreground: _listening ? Colors.white : AppColors.primary,
                      onTap: _toggleMic,
                    ),
                    const SizedBox(width: 10),
                    _RoundBtn(icon: Icons.send_rounded, gradient: true, onTap: () => _send()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.background, this.foreground = Colors.white, this.gradient = false});
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color foreground;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: gradient ? null : background,
        gradient: gradient ? AppColors.gradient : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Icon(icon, color: foreground, size: 22)),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.reminderExists});
  final ChatMessage message;
  final bool reminderExists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = message.fromUser;
    final width = MediaQuery.of(context).size.width * .8;
    final reminder = message.reminderId == null ? null : ref.read(remindersProvider.notifier).byId(message.reminderId!);

    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          gradient: me ? AppColors.gradient : null,
          color: me ? null : context.glass,
          border: me ? null : Border.all(color: context.glassLine),
          boxShadow: me ? null : context.softShadow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(me ? 20 : 6),
            bottomRight: Radius.circular(me ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.photoPath != null) ...[
              PhotoThumb(message.photoPath!, height: 160, radius: 14),
              const SizedBox(height: 8),
            ],
            me
                ? Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5))
                : _RichText(message.text),
            if (!me && message.sources.isNotEmpty) _Sources(message.sources),
            if (message.reminderId != null) ...[
              const SizedBox(height: 10),
              if (reminder != null && reminderExists)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => showReminderDetail(context, ref, reminder, reminder.scheduledAt),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                    decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      if (reminder.photoPath != null && message.photoPath == null)
                        PhotoThumb(reminder.photoPath!, height: 44, width: 44, radius: 12)
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: reminder.category.soft, borderRadius: BorderRadius.circular(12)),
                          child: Icon(reminder.category.icon, size: 18, color: reminder.category.color),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(reminder.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(reminder.alarm ? '${dayLabel(reminder.scheduledAt)} · ${fmtTime(reminder.scheduledAt)} · ${reminder.repeatLabel}' : 'Catatan · ${fmtTime(reminder.createdAt)}',
                              style: TextStyle(fontSize: 12, color: context.muted)),
                        ]),
                      ),
                      if (reminder.hasTicket)
                        IconButton(
                          tooltip: 'Tampilkan tiket',
                          icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                          onPressed: () => openTicket(context, reminder),
                        ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(remindersProvider.notifier).remove(reminder.id);
                          if (context.mounted) showToast(context, reminder.alarm ? 'Pengingat dibatalkan' : 'Catatan dihapus');
                        },
                        style: TextButton.styleFrom(foregroundColor: AppColors.pink, visualDensity: VisualDensity.compact),
                        child: Text(reminder.alarm ? 'Batalkan' : 'Hapus', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                )
              else
                Text('Pengingat ini sudah dihapus', style: TextStyle(fontSize: 12, color: context.faint)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Markdown sederhana: **tebal**, *miring*, poin (-, *, 1.), dan judul (#).
class _RichText extends StatelessWidget {
  const _RichText(this.text);
  final String text;

  List<InlineSpan> _inline(String t, Color ink) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\*([^*\n]+)\*');
    var last = 0;
    for (final m in re.allMatches(t)) {
      if (m.start > last) spans.add(TextSpan(text: t.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)));
      } else {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < t.length) spans.add(TextSpan(text: t.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final base = TextStyle(fontSize: 14.5, height: 1.55, color: ink);
    final children = <Widget>[];
    for (final raw in text.trimRight().split('\n')) {
      final bullet = RegExp(r'^\s*(?:[*\-•]|\d+[.)])\s+(.*)').firstMatch(raw);
      final heading = RegExp(r'^\s*#{1,4}\s+(.*)').firstMatch(raw);
      if (bullet != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            Expanded(child: Text.rich(TextSpan(style: base, children: _inline(bullet.group(1)!, ink)))),
          ]),
        ));
      } else if (heading != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(heading.group(1)!.replaceAll('**', ''), style: base.copyWith(fontWeight: FontWeight.w700)),
        ));
      } else if (raw.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
      } else {
        children.add(Text.rich(TextSpan(style: base, children: _inline(raw, ink))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _Sources extends StatelessWidget {
  const _Sources(this.sources);
  final List<AiSource> sources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in sources)
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => launchUrl(Uri.parse(s.uri), mode: LaunchMode.externalApplication),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.link_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.primary)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(20), boxShadow: context.softShadow),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final v = ((_c.value * 3 - i) % 3);
              final up = v < 1 ? (1 - (v - .5).abs() * 2) : 0.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                transform: Matrix4.translationValues(0, -3 * up, 0),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: context.faint.withValues(alpha: .4 + .6 * up), shape: BoxShape.circle),
              );
            }),
          ),
        ),
      ),
    );
  }
}
