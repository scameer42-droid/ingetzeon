import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_detail_screen.dart';
import 'track_save_screen.dart';
import 'track_widgets.dart';

/// Layar rekam gaya Strava: peta penuh sebelum mulai, lalu tampilan angka besar
/// (bisa ganti ke peta), tombol bulat Mulai / Jeda / Lap / Lanjutkan / Selesai.
class TrackRecordScreen extends ConsumerStatefulWidget {
  const TrackRecordScreen({super.key});
  @override
  ConsumerState<TrackRecordScreen> createState() => _TrackRecordScreenState();
}

class _TrackRecordScreenState extends ConsumerState<TrackRecordScreen> {
  String? _err;
  bool _map = false; // saat merekam: false = angka besar, true = peta

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final e = await ref.read(recorderProvider.notifier).warmUp();
      if (mounted) setState(() => _err = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(recorderProvider);
    final rec = ref.read(recorderProvider.notifier);
    final showMap = !r.active || _map;
    final err = _err ?? r.error;
    return Scaffold(
      backgroundColor: context.card,
      body: Column(children: [
        // ---------------- atas: peta atau angka besar
        Expanded(
          child: showMap
              ? Stack(children: [
                  Positioned.fill(child: RouteMap(segments: r.segments, here: r.here, follow: true, zoom: 17)),
                  Positioned(left: 0, right: 0, top: 0, child: _TopBar(type: r.type, onMap: true)),
                  if (r.active) Positioned(left: 0, right: 0, top: MediaQuery.paddingOf(context).top + 60, child: _StatusBanner(r)),
                  if (!r.active)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: MediaQuery.paddingOf(context).top + 64,
                      child: Center(child: _GpsPill(ok: r.gpsOk, has: r.here != null)),
                    ),
                ])
              : Column(children: [
                  _TopBar(type: r.type, onMap: false),
                  _StatusBanner(r),
                  Expanded(child: _BigStats(r)),
                ]),
        ),
        // ---------------- strip angka ringkas saat peta tampil ketika merekam
        if (r.active && _map) _MiniStats(r),
        if (err != null && !r.active)
          Container(
            width: double.infinity,
            color: AppColors.error.withValues(alpha: .1),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Text(err, translate: false, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        // ---------------- kontrol bawah
        Container(
          decoration: BoxDecoration(color: context.card, border: Border(top: BorderSide(color: context.line))),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: SafeArea(
            top: false,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!r.active) ...[
                RoundBtn(
                  icon: Icons.directions_run_rounded,
                  label: tr(r.type.label),
                  onTap: () async {
                    final t = await pickActivityType(context, r.type);
                    if (t != null) rec.setType(t);
                  },
                ),
                RoundBtn(
                  icon: Icons.play_arrow_rounded,
                  label: r.gpsOk ? 'Mulai' : (r.here == null ? 'Mencari GPS…' : 'Mulai'),
                  size: 84,
                  big: true,
                  bg: kTrack,
                  fg: Colors.white,
                  onTap: err != null && r.here == null
                      ? () async {
                          final e = await rec.warmUp();
                          setState(() => _err = e);
                        }
                      : () {
                          setState(() => _map = false);
                          rec.start();
                        },
                ),
                RoundBtn(icon: Icons.tune_rounded, label: 'Pengaturan', onTap: () => showTrackSettings(context)),
              ] else if (r.status == RecStatus.recording) ...[
                RoundBtn(icon: _map ? Icons.speed_rounded : Icons.map_outlined, label: _map ? 'Angka' : 'Peta', onTap: () => setState(() => _map = !_map)),
                RoundBtn(icon: Icons.stop_rounded, label: 'Jeda', size: 84, big: true, bg: kTrack, fg: Colors.white, onTap: rec.pause),
                RoundBtn(
                  icon: Icons.flag_outlined,
                  label: r.laps.isEmpty ? 'Lap' : '${tr('Lap')} ${r.laps.length + 1}',
                  onTap: () {
                    final before = ref.read(recorderProvider).laps.length;
                    rec.lap();
                    final n = ref.read(recorderProvider).laps.length;
                    showToast(context, n > before ? '${tr('Lap')} $n ${tr('selesai')}' : tr('Lap terlalu pendek'));
                  },
                ),
              ] else ...[
                RoundBtn(icon: _map ? Icons.speed_rounded : Icons.map_outlined, label: _map ? 'Angka' : 'Peta', size: 52, onTap: () => setState(() => _map = !_map)),
                RoundBtn(icon: Icons.play_arrow_rounded, label: 'Lanjutkan', size: 76, big: true, bg: kTrack, fg: Colors.white, onTap: rec.resume),
                RoundBtn(icon: Icons.stop_rounded, label: 'Selesai', size: 76, big: true, bg: context.ink, fg: context.card, onTap: _finish),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _finish() async {
    final a = ref.read(recorderProvider.notifier).finish();
    if (!mounted) return;
    if (a == null) {
      showToast(context, tr('Jaraknya terlalu pendek, aktivitas tidak disimpan.'));
      Navigator.pop(context);
      return;
    }
    final saved = await openSaveActivity(context, a);
    if (!mounted) return;
    if (saved != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackDetailScreen(id: saved.id)));
    } else {
      Navigator.pop(context);
    }
  }
}

/// Bilah atas: tutup (kiri), judul jenis aktivitas (tengah).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.type, required this.onMap});
  final ActivityType type;
  final bool onMap;
  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: onMap ? context.card : Colors.transparent,
      shape: const CircleBorder(),
      elevation: onMap ? 2 : 0,
      child: IconButton(
        tooltip: tr('Kembali'),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.ink, size: 28),
        onPressed: () => Navigator.maybePop(context),
      ),
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(children: [
          btn,
          Expanded(
            child: Center(
              child: Container(
                padding: onMap ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8) : EdgeInsets.zero,
                decoration: onMap ? BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]) : null,
                child: Text('${type.emoji}  ${tr(type.label)}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.ink)),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ]),
      ),
    );
  }
}

/// Pita oranye "Dijeda" / "Jeda otomatis".
class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.r);
  final RecState r;
  @override
  Widget build(BuildContext context) {
    final paused = r.status == RecStatus.paused;
    if (!paused && !r.autoPaused) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: paused ? kTrack : const Color(0xFFF59E0B),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(paused ? 'Dijeda' : 'Jeda otomatis — lanjut sendiri saat kamu bergerak',
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
    );
  }
}

/// Tampilan angka besar (seperti layar statistik Strava): Waktu, pace split & rata-rata, Jarak.
class _BigStats extends StatelessWidget {
  const _BigStats(this.r);
  final RecState r;
  @override
  Widget build(BuildContext context) {
    final st = r.stats;
    final dist = st?.distance ?? 0, moving = st?.moving ?? 0;
    final t = r.type;
    final split = st == null ? 0.0 : currentSplitPace(st);
    final splitTxt = t.usesSpeed ? (split <= 0 ? '0,0' : (3600 / split).toStringAsFixed(1).replaceAll('.', ',')) : fmtPace(split);
    Widget block(String label, String value, String unit, double size) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, translate: false, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: context.ink, height: 1.05, letterSpacing: -1, fontFeatures: const [FontFeature.tabularFigures()])),
              if (unit.isNotEmpty) Text(' $unit', translate: false, style: TextStyle(fontSize: size * .3, fontWeight: FontWeight.w600, color: context.muted)),
            ]),
          ),
        ]);
    Widget divider() => Divider(height: 1, thickness: 1, color: context.line, indent: 24, endIndent: 24);
    return LayoutBuilder(builder: (context, c) {
      final big = (c.maxHeight / 6.2).clamp(44.0, 84.0);
      return Column(children: [
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: block(tr('Waktu'), fmtDur((r.elapsedMs / 1000).round()), '', big)))),
        divider(),
        Expanded(
          child: Row(children: [
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: block('${tr(paceLabel(t))} ${tr('split')}', splitTxt, paceUnit(t), big * .6)))),
            Container(width: 1, height: big * 1.1, color: context.line),
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: block('${tr(paceLabel(t))} ${tr('rata-rata')}', paceOrSpeed(t, dist, moving), paceUnit(t), big * .6)))),
          ]),
        ),
        divider(),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: block(tr('Jarak'), fmtKm(dist), 'km', big)))),
      ]);
    });
  }
}

/// Strip angka ringkas di bawah peta saat merekam.
class _MiniStats extends StatelessWidget {
  const _MiniStats(this.r);
  final RecState r;
  @override
  Widget build(BuildContext context) {
    final st = r.stats;
    final dist = st?.distance ?? 0, moving = st?.moving ?? 0;
    Widget cell(String label, String value, String unit) => Expanded(
          child: Column(children: [
            Text(label, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(value, translate: false, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: context.ink, fontFeatures: const [FontFeature.tabularFigures()])),
                if (unit.isNotEmpty) Text(' $unit', translate: false, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        );
    return Container(
      color: context.card,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(children: [
        cell(tr('Waktu'), fmtDur((r.elapsedMs / 1000).round()), ''),
        cell(tr('Jarak'), fmtKm(dist), 'km'),
        cell(tr(paceLabel(r.type)), paceOrSpeed(r.type, dist, moving), paceUnit(r.type)),
      ]),
    );
  }
}

class _GpsPill extends StatelessWidget {
  const _GpsPill({required this.ok, required this.has});
  final bool ok, has;
  @override
  Widget build(BuildContext context) {
    final c = ok ? const Color(0xFF10B981) : (has ? const Color(0xFFF59E0B) : const Color(0xFF9AA0BC));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(ok ? 'Sinyal GPS siap' : (has ? 'GPS belum akurat' : 'Mencari GPS…'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.ink)),
      ]),
    );
  }
}
