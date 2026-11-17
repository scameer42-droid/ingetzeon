import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../services/translate_service.dart';
import '../../services/voice_service.dart';
import '../widgets/common.dart';

const kTrColor = Color(0xFF0EA5E9);
const kTrGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]);

String _ln(String l) => l == 'id' ? tl('Indonesia', 'Indonesian') : tl('Inggris', 'English');
const _flag = {'id': '🇮🇩', 'en': '🇬🇧'};

/// Satu riwayat terjemahan.
class TrItem {
  const TrItem(this.src, this.out, this.from, this.to, this.at);
  final String src, out, from, to;
  final DateTime at;

  Map<String, dynamic> toMap() => {'s': src, 't': out, 'f': from, 'o': to, 'a': at.millisecondsSinceEpoch};

  static TrItem? fromMap(Object? m) {
    if (m is! Map) return null;
    return TrItem('${m['s'] ?? ''}', '${m['t'] ?? ''}', '${m['f'] ?? 'id'}', '${m['o'] ?? 'en'}',
        DateTime.fromMillisecondsSinceEpoch(m['a'] is int ? m['a'] as int : 0));
  }
}

void openTranslate(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TranslateScreen()));

class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String _from = 'id';
  String _to = 'en';
  String _out = '';
  String _engine = '';
  String? _note;
  String? _error;
  bool _busy = false;
  bool _listening = false;
  List<TrItem> _history = [];

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    final raw = repo.get<List>('trHist', const []);
    _history = raw.map(TrItem.fromMap).whereType<TrItem>().toList();
    final dir = repo.get<String>('trDir', 'id');
    if (dir == 'en') {
      _from = 'en';
      _to = 'id';
    }
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    if (_listening) VoiceService.instance.stopListening();
    super.dispose();
  }

  Future<void> _saveHistory() async {
    await ref.read(settingsRepositoryProvider).set('trHist', _history.take(30).map((e) => e.toMap()).toList());
  }

  void _swap() {
    setState(() {
      final f = _from;
      _from = _to;
      _to = f;
      if (_out.isNotEmpty) {
        final o = _out;
        _out = '';
        _input.text = o;
      }
      _note = null;
      _error = null;
    });
    ref.read(settingsRepositoryProvider).set('trDir', _from);
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
    });
    final s = ref.read(settingsProvider);
    try {
      final r = await TranslateService.instance.translate(text, from: _from, apiKey: s.apiKey, model: s.model);
      if (!mounted) return;
      setState(() {
        if (r.from != _from) {
          _note = r.from == 'en' ? 'Terdeteksi Bahasa Inggris — diterjemahkan ke Indonesia' : 'Terdeteksi Bahasa Indonesia — diterjemahkan ke Inggris';
          _from = r.from;
          _to = r.to;
          ref.read(settingsRepositoryProvider).set('trDir', _from);
        }
        _out = r.text;
        _engine = r.engine;
      });
      _history.removeWhere((e) => e.src == text && e.from == _from);
      _history.insert(0, TrItem(text, r.text, _from, _to, DateTime.now()));
      await _saveHistory();
    } catch (e) {
      if (mounted) setState(() => _error = e is TranslateException ? e.message : 'Terjemahan belum berhasil. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mic() async {
    final v = VoiceService.instance;
    if (_listening) {
      await v.stopListening();
      setState(() => _listening = false);
      return;
    }
    final ok = await v.listen(
      lang: _from,
      onResult: (text, isFinal) {
        if (!mounted) return;
        _input.text = text;
        _input.selection = TextSelection.collapsed(offset: text.length);
        if (isFinal) {
          setState(() => _listening = false);
          _translate();
        }
      },
      onStatus: (st) {
        if (mounted && (st == 'done' || st == 'notListening')) setState(() => _listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      showToast(context, 'Mikrofon tidak tersedia. Pastikan izin mikrofon aktif dan aplikasi Google terpasang.');
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) {
      if (mounted) showToast(context, 'Papan klip kosong');
      return;
    }
    _input.text = t;
    _input.selection = TextSelection.collapsed(offset: t.length);
  }

  Future<void> _copy(String t) async {
    await Clipboard.setData(ClipboardData(text: t));
    if (mounted) showToast(context, 'Disalin');
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasAi));
    return Scaffold(
      appBar: AppBar(title: const Text('Terjemahkan'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _LangBar(from: _from, to: _to, onSwap: _swap),
          const SizedBox(height: 14),
          _inputCard(context),
          const SizedBox(height: 12),
          GradientButton(
            label: _busy ? 'Menerjemahkan…' : 'Terjemahkan',
            icon: Icons.translate_rounded,
            onPressed: _input.text.trim().isEmpty || _busy ? null : _translate,
          ),
          if (_note != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: kTrColor),
              const SizedBox(width: 6),
              Expanded(child: Text(_note!, style: TextStyle(fontSize: 12.5, color: context.muted))),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.pink, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13.5))),
              ]),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
          ],
          if (_out.isNotEmpty && !_busy) ...[
            const SizedBox(height: 16),
            _resultCard(context),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Icon(hasKey ? Icons.auto_awesome_rounded : Icons.public_rounded, size: 15, color: context.faint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasKey ? 'Diterjemahkan dengan Gemini AI — hasil lebih natural.' : 'Memakai layanan terjemahan gratis. Isi kunci Gemini di Profil untuk hasil yang lebih natural.',
                style: TextStyle(fontSize: 12, color: context.faint),
              ),
            ),
          ]),
          if (_history.isNotEmpty) ...[
            SectionHeader('Riwayat', action: 'Hapus', onAction: () async {
              final ok = await confirmDialog(context, title: 'Hapus riwayat?', message: 'Semua riwayat terjemahan akan dihapus.', ok: 'Hapus', danger: true);
              if (!ok) return;
              setState(() => _history = []);
              await _saveHistory();
            }),
            for (final h in _history.take(20)) _historyTile(context, h),
          ],
        ],
      ),
    );
  }

  Widget _inputCard(BuildContext context) {
    final empty = _input.text.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _focus.hasFocus ? kTrColor : context.line, width: _focus.hasFocus ? 1.6 : 1),
        boxShadow: context.softShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${_flag[_from]}  ${_ln(_from)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kTrColor)),
          const Spacer(),
          if (!empty)
            IconButton(
              tooltip: tr('Hapus'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 20, color: context.muted),
              onPressed: () => setState(() {
                _input.clear();
                _out = '';
                _note = null;
                _error = null;
              }),
            ),
        ]),
        TextField(
          controller: _input,
          focusNode: _focus,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(fontSize: 17, height: 1.45),
          decoration: InputDecoration(
            hintText: _from == 'id' ? tr('Ketik atau ucapkan teks Bahasa Indonesia…') : tr('Ketik atau ucapkan teks Bahasa Inggris…'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
            counterText: '',
          ),
        ),
        Row(children: [
          _RoundIcon(
            icon: _listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: _listening ? AppColors.pink : kTrColor,
            filled: _listening,
            tooltip: _listening ? 'Berhenti' : 'Bicara',
            onTap: _mic,
          ),
          const SizedBox(width: 6),
          _RoundIcon(icon: Icons.content_paste_rounded, color: kTrColor, tooltip: 'Tempel', onTap: _paste),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${_input.text.length}/2000', translate: false, style: TextStyle(fontSize: 11.5, color: context.faint)),
          ),
        ]),
        if (_listening)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 0, 4),
            child: Text('Mendengarkan… bicara sekarang', style: TextStyle(fontSize: 12.5, color: AppColors.pink.withValues(alpha: .9), fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _resultCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: kTrGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: kTrColor.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -12)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${_flag[_to]}  ${_ln(_to)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
          const Spacer(),
          if (_engine.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
              child: Text(_engine == 'gemini' ? 'Gemini AI' : (_engine == 'offline' ? 'Offline' : 'MyMemory'),
                  translate: false, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 8),
        SelectableText(_out, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.45, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _RoundIcon(icon: Icons.volume_up_rounded, color: Colors.white, onGradient: true, tooltip: 'Dengarkan', onTap: () => VoiceService.instance.speakIn(_out, _to)),
          const SizedBox(width: 6),
          _RoundIcon(icon: Icons.copy_rounded, color: Colors.white, onGradient: true, tooltip: 'Salin', onTap: () => _copy(_out)),
          const SizedBox(width: 6),
          _RoundIcon(icon: Icons.swap_vert_rounded, color: Colors.white, onGradient: true, tooltip: 'Balik', onTap: _swap),
        ]),
      ]),
    );
  }

  Widget _historyTile(BuildContext context, TrItem h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => setState(() {
          _from = h.from;
          _to = h.to;
          _input.text = h.src;
          _out = h.out;
          _engine = '';
          _note = null;
          _error = null;
        }),
        child: Row(children: [
          Text('${_flag[h.from]}→${_flag[h.to]}', translate: false, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.src, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.muted)),
              const SizedBox(height: 2),
              Text(h.out, translate: false, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(
            tooltip: tr('Salin'),
            icon: Icon(Icons.copy_rounded, size: 18, color: context.faint),
            onPressed: () => _copy(h.out),
          ),
        ]),
      ),
    );
  }
}

class _LangBar extends StatelessWidget {
  const _LangBar({required this.from, required this.to, required this.onSwap});
  final String from, to;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    Widget pill(String l) => Expanded(
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${_flag[l]}  ${_ln(l)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: kTrGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kTrColor.withValues(alpha: .4), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -14)],
      ),
      child: Row(children: [
        pill(from),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSwap,
              child: const SizedBox(width: 46, height: 46, child: Icon(Icons.swap_horiz_rounded, color: Color(0xFF4F46E5), size: 26)),
            ),
          ),
        ),
        pill(to),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap, this.tooltip, this.filled = false, this.onGradient = false});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  final bool filled;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final bg = onGradient ? Colors.white.withValues(alpha: .18) : (filled ? color : color.withValues(alpha: context.isDark ? .2 : .1));
    final fg = filled && !onGradient ? Colors.white : color;
    return Tooltip(
      message: tr(tooltip ?? ''),
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, color: fg, size: 21)),
        ),
      ),
    );
  }
}
