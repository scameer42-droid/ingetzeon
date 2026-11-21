import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_widgets.dart';

/// Buka halaman "Simpan aktivitas". Mengembalikan aktivitas tersimpan, atau null bila dibuang.
Future<Activity?> openSaveActivity(BuildContext context, Activity a) =>
    Navigator.of(context).push<Activity>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => TrackSaveScreen(a: a)));

/// Halaman simpan gaya Strava: judul, catatan, jenis, pratinjau rute, usaha (RPE).
class TrackSaveScreen extends ConsumerStatefulWidget {
  const TrackSaveScreen({super.key, required this.a});
  final Activity a;
  @override
  ConsumerState<TrackSaveScreen> createState() => _TrackSaveScreenState();
}

class _TrackSaveScreenState extends ConsumerState<TrackSaveScreen> {
  late final _title = TextEditingController(text: widget.a.title);
  final _note = TextEditingController();
  late ActivityType _type = widget.a.type;
  double _rpe = 0;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<bool> _discard() => confirmDialog(context, title: 'Buang aktivitas ini?', message: 'Rute dan waktunya tidak disimpan.', ok: 'Buang', danger: true);

  @override
  Widget build(BuildContext context) {
    final a = widget.a, st = a.stats;
    final rpe = _rpe.round();
    InputDecoration deco(String hint) => InputDecoration(
          hintText: tr(hint),
          filled: true,
          fillColor: context.card2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        if (await _discard() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Simpan aktivitas'),
          centerTitle: true,
          leading: IconButton(
            tooltip: tr('Buang'),
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _discard() && context.mounted) Navigator.pop(context);
            },
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          TextField(controller: _title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink), decoration: deco('Judul aktivitas')),
          const SizedBox(height: 10),
          TextField(controller: _note, minLines: 2, maxLines: 4, decoration: deco('Gimana rasanya hari ini?')),
          const SizedBox(height: 10),
          Material(
            color: context.card2,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final t = await pickActivityType(context, _type);
                if (t != null) setState(() => _type = t);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Text(_type.emoji, translate: false, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr(_type.label), translate: false, style: TextStyle(fontWeight: FontWeight.w600, color: context.ink))),
                  Text('Ganti', style: TextStyle(color: kTrack, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const Icon(Icons.chevron_right_rounded, color: kTrack),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // pratinjau rute + angka
          Container(
            decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.line)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                height: 170,
                color: kTrack.withValues(alpha: context.isDark ? .10 : .06),
                child: CustomPaint(painter: RoutePainter(a.segments, width: 3.6), child: const SizedBox.expand()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(children: [
                  Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(st.distance), unit: 'km')),
                  Expanded(child: StatBox(label: tr(paceLabel(_type)), value: paceOrSpeed(_type, st.distance, st.moving), unit: paceUnit(_type))),
                  Expanded(child: StatBox(label: tr('Waktu'), value: fmtDur(st.moving))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // usaha (RPE)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Seberapa berat?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: context.ink))),
                Text(rpe == 0 ? tr('Belum diisi') : '$rpe/10 · ${tr(rpeLabel(rpe))}', translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: rpe == 0 ? context.faint : kTrack)),
              ]),
              const SizedBox(height: 2),
              Text('Catat seberapa capek kamu, supaya bisa dibandingkan dengan aktivitas lain.', style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.35)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: kTrack, thumbColor: kTrack, inactiveTrackColor: kTrack.withValues(alpha: .18), overlayColor: kTrack.withValues(alpha: .12)),
                child: Slider(value: _rpe, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _rpe = v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(child: Text('Ringan', style: TextStyle(fontSize: 11.5, color: context.muted))),
                  Text('Sedang', style: TextStyle(fontSize: 11.5, color: context.muted)),
                  Expanded(child: Text('Maksimal', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: context.muted))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kTrack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final t = _title.text.trim().isEmpty ? a.title : _title.text.trim();
                final saved = await ref.read(trackProvider.notifier).add(a.copyWith(title: t, note: _note.text.trim(), type: _type, rpe: rpe));
                if (context.mounted) Navigator.pop(context, saved);
              },
              child: const Text('Simpan aktivitas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              if (await _discard() && context.mounted) Navigator.pop(context);
            },
            child: const Text('Buang aktivitas', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
