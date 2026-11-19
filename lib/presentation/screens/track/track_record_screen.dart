import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_detail_screen.dart';
import 'track_widgets.dart';

/// Layar rekam: peta langsung, angka besar, tombol mulai/jeda/lanjut/selesai.
class TrackRecordScreen extends ConsumerStatefulWidget {
  const TrackRecordScreen({super.key});
  @override
  ConsumerState<TrackRecordScreen> createState() => _TrackRecordScreenState();
}

class _TrackRecordScreenState extends ConsumerState<TrackRecordScreen> {
  String? _err;

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
    final st = r.stats;
    final dist = st?.distance ?? 0, moving = st?.moving ?? 0;
    final lastSplit = st != null && st.splits.isNotEmpty ? st.splits.last : null;
    return Scaffold(
      appBar: AppBar(title: Text(r.active ? '${r.type.emoji} ${tr(r.type.label)}' : tr('Rekam aktivitas'), translate: false), centerTitle: false),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: RouteMap(segments: r.segments, here: r.here, follow: true, zoom: 17)),
            Positioned(
              left: 12,
              top: 12,
              child: _GpsBadge(ok: r.gpsOk, has: r.here != null),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: context.card, border: Border(top: BorderSide(color: context.line))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: SafeArea(
            top: false,
            child: !r.active
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_err != null || r.error != null) ...[
                      Text(_err ?? r.error!, translate: false, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                    ],
                    TypeChips(value: r.type, onChanged: ref.read(recorderProvider.notifier).setType),
                    const SizedBox(height: 14),
                    _BigButton(
                      label: r.gpsOk ? 'Mulai' : 'Mulai (GPS belum akurat)',
                      color: kTrack,
                      icon: Icons.play_arrow_rounded,
                      onTap: _err != null && r.here == null
                          ? () async {
                              final e = await ref.read(recorderProvider.notifier).warmUp();
                              setState(() => _err = e);
                            }
                          : () => ref.read(recorderProvider.notifier).start(),
                    ),
                    const SizedBox(height: 8),
                    Text('Tips: tunggu sampai GPS hijau, dan biarkan HP di saku. Rekaman tetap berjalan saat layar mati.',
                        textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(child: StatBox(label: tr('Waktu'), value: fmtDur((r.elapsedMs / 1000).round()), big: true)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(dist), unit: 'km')),
                      Expanded(child: StatBox(label: '${tr(paceLabel(r.type))} ${tr('rata-rata')}', value: paceOrSpeed(r.type, dist, moving), unit: paceUnit(r.type))),
                      Expanded(
                        child: StatBox(
                          label: lastSplit == null ? tr('Elevasi') : '${tr('Km')} ${lastSplit.index}',
                          value: lastSplit == null ? '${(st?.elevGain ?? 0).round()}' : paceOrSpeed(r.type, lastSplit.meters, lastSplit.secs),
                          unit: lastSplit == null ? 'm' : paceUnit(r.type),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (r.status == RecStatus.recording)
                      _BigButton(label: 'Jeda', color: const Color(0xFF111633), icon: Icons.pause_rounded, onTap: ref.read(recorderProvider.notifier).pause)
                    else
                      Row(children: [
                        Expanded(child: _BigButton(label: 'Lanjutkan', color: kTrack, icon: Icons.play_arrow_rounded, onTap: ref.read(recorderProvider.notifier).resume)),
                        const SizedBox(width: 10),
                        Expanded(child: _BigButton(label: 'Selesai', color: const Color(0xFFDC2626), icon: Icons.stop_rounded, onTap: _finish)),
                      ]),
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
    final saved = await saveActivitySheet(context, ref, a);
    if (!mounted) return;
    if (saved != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackDetailScreen(id: saved.id)));
    } else {
      Navigator.pop(context);
    }
  }
}

class _GpsBadge extends StatelessWidget {
  const _GpsBadge({required this.ok, required this.has});
  final bool ok, has;
  @override
  Widget build(BuildContext context) {
    final c = ok ? const Color(0xFF10B981) : (has ? const Color(0xFFF59E0B) : const Color(0xFF9AA0BC));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.gps_fixed_rounded, size: 16, color: c),
        const SizedBox(width: 6),
        Text(ok ? 'GPS siap' : (has ? 'GPS belum akurat' : 'Mencari GPS…'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: context.ink)),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.color, required this.icon, required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}
