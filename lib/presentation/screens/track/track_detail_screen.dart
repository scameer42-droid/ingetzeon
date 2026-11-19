import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_widgets.dart';

void openActivity(BuildContext context, Activity a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackDetailScreen(id: a.id)));

/// Lembar simpan setelah selesai merekam: judul, jenis, catatan. null = dibuang.
Future<Activity?> saveActivitySheet(BuildContext context, WidgetRef ref, Activity a) async {
  final title = TextEditingController(text: a.title), note = TextEditingController();
  var type = a.type;
  final res = await showAppSheet<Activity>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final st = a.stats;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Simpan aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(st.distance), unit: 'km')),
            Expanded(child: StatBox(label: tr('Waktu'), value: fmtDur(st.moving))),
            Expanded(child: StatBox(label: tr(paceLabel(type)), value: paceOrSpeed(type, st.distance, st.moving), unit: paceUnit(type))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: InputDecoration(labelText: tr('Judul'))),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: tr('Catatan (opsional)'), hintText: tr('Gimana rasanya hari ini?'))),
          const SizedBox(height: 12),
          TypeChips(value: type, onChanged: (t) => setS(() => type = t)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTrack, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              final t = title.text.trim().isEmpty ? a.title : title.text.trim();
              final saved = await ref.read(trackProvider.notifier).add(a.copyWith(title: t, note: note.text.trim(), type: type));
              if (ctx.mounted) Navigator.pop(ctx, saved);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              if (await confirmDialog(ctx, title: 'Buang aktivitas ini?', message: 'Rute dan waktunya tidak disimpan.', ok: 'Buang', danger: true)) {
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Buang'),
          ),
        ]),
      );
    }),
  );
  return res;
}

/// Detail satu aktivitas: peta, angka, split per km, grafik elevasi, rekor, bagikan, GPX.
class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(trackProvider);
    final a = s.activities.where((x) => x.id == id).firstOrNull;
    if (a == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Aktivitas tidak ditemukan.')));
    final st = a.stats;
    final prs = {for (final p in s.bestEfforts(type: a.type)) p.label: p};
    final efforts = [
      for (final (m, label) in bestDistances)
        if (st.bestEffort(m) != null) (label: label, m: m, secs: st.bestEffort(m)!),
    ];
    final hasAlt = a.points.any((p) => p.alt != null);
    return Scaffold(
      appBar: AppBar(title: Text('${a.type.emoji} ${tr(a.type.label)}', translate: false), centerTitle: false, actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') await _edit(context, ref, a);
            if (v == 'gpx' && context.mounted) await _gpx(context, a);
            if (v == 'del' && context.mounted && await confirmDialog(context, title: 'Hapus aktivitas ini?', message: a.title, ok: 'Hapus', danger: true)) {
              await ref.read(trackProvider.notifier).remove(a.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(tr('Ubah judul & catatan'), translate: false)),
            PopupMenuItem(value: 'gpx', child: Text(tr('Ekspor GPX'), translate: false)),
            PopupMenuItem(value: 'del', child: Text(tr('Hapus'), translate: false)),
          ],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        SizedBox(height: 280, child: RouteMap(segments: a.segments, interactive: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(a.title, translate: false, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 2),
            Text('${fmtDateLong(a.start)} · ${fmtTime(a.start)}', translate: false, style: TextStyle(color: context.muted, fontSize: 13)),
            if (a.note.isNotEmpty) ...[const SizedBox(height: 8), Text(a.note, translate: false, style: TextStyle(color: context.ink, height: 1.45))],
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(st.distance), unit: 'km')),
                  Expanded(child: StatBox(label: tr(paceLabel(a.type)), value: paceOrSpeed(a.type, st.distance, st.moving), unit: paceUnit(a.type))),
                  Expanded(child: StatBox(label: tr('Waktu bergerak'), value: fmtDur(st.moving))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: StatBox(label: tr('Elevasi naik'), value: '${st.elevGain.round()}', unit: 'm')),
                  Expanded(child: StatBox(label: tr('Kalori'), value: '${a.kcal.round()}', unit: 'kkal')),
                  Expanded(child: StatBox(label: tr('Waktu total'), value: fmtDur(math.max(a.elapsed, st.moving)))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kTrack, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => shareCardSheet(context, a),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: kTrack, minimumSize: const Size.fromHeight(48), side: BorderSide(color: kTrack.withValues(alpha: .4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _gpx(context, a),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('GPX', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            if (st.splits.isNotEmpty) ...[
              const SectionHeader('Split per km'),
              _Splits(a),
            ],
            if (hasAlt && st.cumDist.length >= 2 && st.distance >= 100) ...[
              const SectionHeader('Profil elevasi'),
              SoftCard(padding: const EdgeInsets.fromLTRB(6, 16, 14, 6), child: SizedBox(height: 150, child: _ElevChart(st))),
            ],
            if (efforts.isNotEmpty) ...[
              const SectionHeader('Upaya terbaik'),
              ListGroup(children: [
                for (final e in efforts)
                  AppListRow(
                    icon: Icons.emoji_events_outlined,
                    color: prs[e.label]?.activity.id == a.id ? const Color(0xFFF59E0B) : kTrack,
                    title: e.label,
                    subtitle: '${fmtDur(e.secs)} · ${fmtPace(e.secs / (e.m / 1000))}/km${prs[e.label]?.activity.id == a.id ? ' · ${tr('Rekor pribadi!')}' : ''}',
                    chevron: false,
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Activity a) async {
    final t = TextEditingController(text: a.title), n = TextEditingController(text: a.note);
    await showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ubah aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: t, decoration: InputDecoration(labelText: tr('Judul'))),
          const SizedBox(height: 12),
          TextField(controller: n, maxLines: 3, decoration: InputDecoration(labelText: tr('Catatan (opsional)'))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTrack, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () async {
              await ref.read(trackProvider.notifier).update(a.copyWith(title: t.text.trim().isEmpty ? a.title : t.text.trim(), note: n.text.trim()));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

Future<void> _gpx(BuildContext context, Activity a) async {
  try {
    final dir = await getTemporaryDirectory();
    final name = a.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim().replaceAll(' ', '_');
    final f = File('${dir.path}/IngetZeon_${name.isEmpty ? 'aktivitas' : name}_${dayKey(a.start)}.gpx');
    await f.writeAsString(toGpx(name: a.title, type: a.type, segments: a.segments));
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/gpx+xml')], subject: a.title));
  } catch (_) {
    if (context.mounted) showToast(context, tr('GPX belum bisa dibuat. Coba lagi.'));
  }
}

class _Splits extends StatelessWidget {
  const _Splits(this.a);
  final Activity a;
  @override
  Widget build(BuildContext context) {
    final sp = a.stats.splits;
    final paces = sp.map((s) => s.pace).where((p) => p > 0).toList();
    final fastest = paces.isEmpty ? 0.0 : paces.reduce(math.min), slowest = paces.isEmpty ? 1.0 : paces.reduce(math.max);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 44, child: Text('Km', style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w700))),
            SizedBox(width: 62, child: Text(paceLabel(a.type), style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w700))),
            const Expanded(child: SizedBox()),
            SizedBox(width: 48, child: Text('Elev', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w700))),
          ]),
        ),
        for (final s in sp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 44, child: Text(s.meters < 999 ? fmtKm(s.meters, 1) : '${s.index}', translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
              SizedBox(width: 62, child: Text(paceOrSpeed(a.type, s.meters, s.secs), translate: false, style: TextStyle(fontWeight: FontWeight.w600, color: context.ink))),
              Expanded(
                child: LayoutBuilder(builder: (_, c) {
                  // batang lebih panjang = lebih cepat
                  final f = slowest == fastest ? 1.0 : 1 - (s.pace - fastest) / (slowest - fastest) * .7;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(height: 12, width: c.maxWidth * f.clamp(.2, 1), decoration: BoxDecoration(color: s.pace == fastest ? kTrack : kTrack.withValues(alpha: .45), borderRadius: BorderRadius.circular(6))),
                  );
                }),
              ),
              SizedBox(width: 48, child: Text('${s.elev >= 0 ? '+' : ''}${s.elev.round()}', translate: false, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: context.muted))),
            ]),
          ),
      ]),
    );
  }
}

class _ElevChart extends StatelessWidget {
  const _ElevChart(this.st);
  final TrackStats st;
  @override
  Widget build(BuildContext context) {
    final step = math.max(1, st.cumDist.length ~/ 200);
    final spots = [for (var i = 0; i < st.cumDist.length; i += step) FlSpot(st.cumDist[i] / 1000, st.cumAlt[i])];
    final lo = st.cumAlt.reduce(math.min), hi = st.cumAlt.reduce(math.max);
    final pad = math.max(5.0, (hi - lo) * .15);
    return LineChart(LineChartData(
      minY: (lo - pad).floorToDouble(),
      maxY: (hi + pad).ceilToDouble(),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, m) => v == m.min || v == m.max ? const SizedBox.shrink() : Text('${v.round()}', translate: false, style: TextStyle(fontSize: 11, color: context.muted)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) => v == m.min || v == m.max ? const SizedBox.shrink() : Text('${v.toStringAsFixed(1).replaceAll('.', ',')} km', translate: false, style: TextStyle(fontSize: 10.5, color: context.muted)))),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: const Color(0xFF7C3AED),
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: const Color(0xFF7C3AED).withValues(alpha: .15)),
        ),
      ],
    ));
  }
}

// ---------------------------------------------------------------- kartu bagikan

/// Pratinjau kartu bergaya langit malam lalu bagikan sebagai gambar.
Future<void> shareCardSheet(BuildContext context, Activity a) async {
  final key = GlobalKey();
  await showAppSheet(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Bagikan aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Center(child: RepaintBoundary(key: key, child: ShareCard(a: a))),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kTrack, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () async {
            try {
              final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
              final img = await b.toImage(pixelRatio: 3);
              final data = await img.toByteData(format: ui.ImageByteFormat.png);
              final dir = await getTemporaryDirectory();
              final f = File('${dir.path}/IngetZeon_${a.id}.png');
              await f.writeAsBytes(data!.buffer.asUint8List());
              await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')], text: '${a.title} · ${fmtKm(a.distance)} km #IngetZeon'));
            } catch (_) {
              if (ctx.mounted) showToast(ctx, tr('Gambar belum bisa dibagikan. Coba lagi.'));
            }
          },
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Bagikan gambar', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );
}

class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.a});
  final Activity a;
  @override
  Widget build(BuildContext context) {
    final st = a.stats;
    return Container(
      width: 300,
      height: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E1A4A), Color(0xFF1E3A8A), Color(0xFF3B5BC4)]),
      ),
      child: CustomPaint(
        painter: const HillsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.type.emoji} ${a.title}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${fmtDateShort(a.start)} · ${fmtTime(a.start)}', translate: false, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
            Expanded(child: CustomPaint(painter: RoutePainter(a.segments, color: const Color(0xFFFDE68A), width: 4), child: const SizedBox.expand())),
            Row(children: [
              Expanded(child: StatBox(label: tr('Jarak'), value: fmtKm(st.distance), unit: 'km', light: true)),
              Expanded(child: StatBox(label: tr(paceLabel(a.type)), value: paceOrSpeed(a.type, st.distance, st.moving), unit: paceUnit(a.type), light: true)),
              Expanded(child: StatBox(label: tr('Waktu'), value: fmtDur(st.moving), light: true)),
            ]),
            const SizedBox(height: 10),
            const Text('IngetZeon', translate: false, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .3)),
          ]),
        ),
      ),
    );
  }
}
