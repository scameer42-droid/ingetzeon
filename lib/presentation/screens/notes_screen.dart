import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/notes_provider.dart';
import '../../services/note_parser.dart';
import '../widgets/common.dart';

const kNoteColor = Color(0xFF0D9488);
const kSecretColor = Color(0xFFDB2777);

/// Satu catatan; catatan rahasia disensor dan dibuka dengan sidik jari/PIN HP.
class NoteTile extends ConsumerStatefulWidget {
  const NoteTile(this.note, {super.key, this.inChat = false});
  final Note note;
  final bool inChat;

  @override
  ConsumerState<NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends ConsumerState<NoteTile> {
  String? _shown;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _reveal() async {
    if (_shown != null) {
      setState(() => _shown = null);
      return;
    }
    final v = await ref.read(notesProvider.notifier).reveal(widget.note);
    if (!mounted) return;
    if (v == null) {
      showToast(context, 'Verifikasi dibatalkan');
      return;
    }
    setState(() => _shown = v);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  Future<void> _copy() async {
    final n = widget.note;
    final v = n.secret ? (_shown ?? await ref.read(notesProvider.notifier).reveal(n)) : NoteParser.you(n.value);
    if (v == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (mounted) showToast(context, 'Disalin');
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final color = n.secret ? kSecretColor : kNoteColor;
    return Container(
      margin: EdgeInsets.only(bottom: widget.inChat ? 0 : 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: widget.inChat ? context.card2 : context.glass,
        borderRadius: BorderRadius.circular(14),
        border: widget.inChat ? null : Border.all(color: context.glassLine),
        boxShadow: widget.inChat ? null : context.softShadow,
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Icon(n.secret ? Icons.lock_rounded : Icons.sticky_note_2_rounded, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.secret ? MemoryCap.cap(n.label) : MemoryCap.cap(NoteParser.you(n.value)),
                maxLines: n.secret ? 1 : 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            if (n.secret)
              Text(_shown ?? '••••••••',
                  style: TextStyle(
                    fontSize: _shown == null ? 14 : 15,
                    letterSpacing: _shown == null ? 2 : .2,
                    fontWeight: FontWeight.w700,
                    color: _shown == null ? context.faint : color,
                  ))
            else
              Text('Dicatat ${dayLabel(n.createdAt).toLowerCase()} · ${fmtTime(n.createdAt)}', style: TextStyle(fontSize: 12, color: context.muted)),
          ]),
        ),
        if (n.secret)
          IconButton(
            tooltip: _shown == null ? 'Tampilkan' : 'Sembunyikan',
            onPressed: _reveal,
            icon: Icon(_shown == null ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: color),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.muted),
          onSelected: (v) async {
            final notifier = ref.read(notesProvider.notifier);
            if (v == 'copy') await _copy();
            if (v == 'edit' && context.mounted) await showNoteEditor(context, ref, existing: n);
            if (v == 'del' && context.mounted) {
              final ok = await confirmDialog(context, title: 'Hapus catatan?', message: n.secret ? 'Catatan rahasia ini akan dihapus permanen.' : n.value, ok: 'Hapus', danger: true);
              if (ok) await notifier.remove(n.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'copy', child: Text('Salin')),
            PopupMenuItem(value: 'edit', child: Text('Ubah')),
            PopupMenuItem(value: 'del', child: Text('Hapus')),
          ],
        ),
      ]),
    );
  }
}

class MemoryCap {
  static String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Form tambah / ubah catatan.
Future<void> showNoteEditor(BuildContext context, WidgetRef ref, {Note? existing}) async {
  final notifier = ref.read(notesProvider.notifier);
  String? oldSecret;
  if (existing != null && existing.secret) {
    oldSecret = await notifier.reveal(existing);
    if (oldSecret == null) return;
  }
  if (!context.mounted) return;
  final label = TextEditingController(text: existing?.label ?? '');
  final value = TextEditingController(text: oldSecret ?? '');
  var secret = existing?.secret ?? false;
  var hide = true;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing == null ? 'Catatan baru' : 'Ubah catatan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: label,
            autofocus: existing == null,
            maxLines: secret ? 1 : 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: secret ? 'Untuk apa? (mis. password FB)' : 'Isi catatan',
              hintText: secret ? 'password facebook' : 'mis. saya punya emas 10 gr',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (existing == null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: secret,
              activeTrackColor: kSecretColor,
              onChanged: (v) => setS(() => secret = v),
              title: const Text('Rahasia (password / PIN)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Disimpan terenkripsi & dibuka dengan sidik jari/PIN HP'),
            ),
          if (secret) ...[
            const SizedBox(height: 6),
            TextField(
              controller: value,
              obscureText: hide,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Isi rahasia',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded), onPressed: () => setS(() => hide = !hide)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: 'Simpan',
            icon: Icons.check_rounded,
            onPressed: () async {
              final l = label.text.trim(), v = value.text.trim();
              if (l.isEmpty || (secret && v.isEmpty)) {
                showToast(ctx, secret ? 'Isi judul dan isi rahasianya' : 'Catatan masih kosong');
                return;
              }
              if (existing != null) {
                await notifier.edit(existing, label: l, secretValue: secret ? v : null);
              } else {
                await notifier.add(NoteDraft(text: l, label: l, value: secret ? v : l, secret: secret));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    ),
  );
}

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notesProvider);
    final q = _q.trim();
    final list = q.isEmpty
        ? all
        : (() {
            final tk = NoteParser.tokens(q);
            final m = tk.isEmpty ? <Note>[] : NoteParser.match(all, tk);
            final plain = all.where((n) => n.display.toLowerCase().contains(q.toLowerCase()) && !m.contains(n));
            return [...m, ...plain];
          })();
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan'), centerTitle: false),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showNoteEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catatan'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Cari catatan…',
            filled: true,
            fillColor: context.glass,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.line)),
          ),
        ),
        const SizedBox(height: 14),
        if (all.isEmpty)
          const EmptyState(
            title: 'Belum ada catatan',
            subtitle: 'Bilang ke asisten: "catat saya punya emas 10 gr" atau "catat password fb saya …"',
          )
        else ...[
          for (final n in list) NoteTile(n),
          if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Tidak ketemu', style: TextStyle(color: context.muted)))),
        ],
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_outlined, size: 16, color: context.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Catatan rahasia (password/PIN) dienkripsi di HP ini, hanya bisa dibuka dengan sidik jari/PIN layar, '
              'dan tidak pernah dikirim ke AI/internet.',
              style: TextStyle(fontSize: 12, height: 1.4, color: context.faint),
            ),
          ),
        ]),
      ]),
    );
  }
}
