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
import '../../../providers/settings_provider.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';
import 'track_widgets.dart';

void openActivity(BuildContext context, Activity a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackDetailScreen(id: a.id)));

const _medals = ['🥇', '🥈', '🥉'];

/// Detail aktivitas gaya Strava: peta, profil + judul, kisi angka, split, grafik pace & elevasi,
/// upaya terbaik bermedali, lap, bagikan, GPX.
class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(trackProvider);
    final set = ref.watch(settingsProvider);
    final a = s.activities.where((x) => x.id == id).firstOrNull;
    if (a == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Aktivitas tidak ditemukan.')));
    final st = a.stats;
    final name = set.name.trim().isEmpty ? tr('Kamu') : set.name.trim();
    final efforts = [
      for (final (m, label) in bestDistances)
        if (st.bestEffort(m) case final secs?) (label: label, m: m, secs: secs, rank: s.ranking(a.type, m).indexWhere((r) => r.activity.id == a.id)),
    ];
    final laps = lapsFrom(a.laps, st);
    final hasAlt = a.points.any((p) => p.alt != null);
    Widget cell(String label, String value, [String unit = '']) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: StatBox(label: label, value: value, unit: unit),
        );
    return Scaffold(
      appBar: AppBar(title: Text('${a.type.emoji} ${tr(a.type.label)}', translate: false), centerTitle: false, actions: [
        IconButton(tooltip: tr('Bagikan'), icon: const Icon(Icons.ios_share_rounded), onPressed: () => shareCardSheet(context, a)),
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
            PopupMenuItem(value: 'edit', child: Text(tr('Ubah aktivitas'), translate: false)),
            PopupMenuItem(value: 'gpx', child: Text(tr('Ekspor GPX'), translate: false)),
            PopupMenuItem(value: 'del', child: Text(tr('Hapus'), translate: false)),
          ],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        SizedBox(height: 290, child: RouteMap(segments: a.segments, interactive: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              UserAvatar(name: name, path: set.avatarPath, size: 42, radius: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.ink)),
                  Text('${fmtDateLong(a.start)} · ${fmtTime(a.start)}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Text(a.title, translate: false, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.ink, height: 1.2, letterSpacing: -.3)),
            if (a.note.isNotEmpty) ...[const SizedBox(height: 8), Text(a.note, translate: false, style: TextStyle(color: context.ink, height: 1.45))],
            const SizedBox(height: 14),
            Divider(height: 1, color: context.line),
            Row(children: [
              Expanded(child: cell(tr('Jarak'), fmtKm(st.distance), 'km')),
              Expanded(child: cell(tr(paceLabel(a.type)), paceOrSpeed(a.type, st.distance, st.moving), paceUnit(a.type))),
              Expanded(child: cell(tr('Waktu bergerak'), fmtDur(st.moving))),
            ]),
            Divider(height: 1, color: context.line),
            Row(children: [
              Expanded(child: cell(tr('Elevasi naik'), '${st.elevGain.round()}', 'm')),
              Expanded(child: cell(tr('Waktu total'), fmtDur(math.max(a.elapsed, st.moving)))),
              Expanded(child: cell(tr('Kalori'), '${a.kcal.round()}', tr('kkal'))),
            ]),
            Divider(height: 1, color: context.line),
            if (a.rpe > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Text('Usaha', style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: a.rpe / 10, minHeight: 8, color: kTrack, backgroundColor: kTrack.withValues(alpha: .15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${a.rpe}/10 · ${tr(rpeLabel(a.rpe))}', translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
                ]),
              ),
              Divider(height: 1, color: context.line),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kTrack, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => shareCardSheet(context, a),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: context.ink, minimumSize: const Size.fromHeight(50), side: BorderSide(color: context.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _gpx(context, a),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('GPX', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            if (st.splits.isNotEmpty) ...[
              const SectionHeader('Split'),
              _Splits(a),
            ],
            if (st.cumDist.length >= 10 && st.distance >= 200) ...[
              SectionHeader(a.type.usesSpeed ? 'Kecepatan' : 'Pace'),
              SoftCard(padding: const EdgeInsets.fromLTRB(6, 16, 14, 6), child: SizedBox(height: 150, child: _PaceChart(a))),
            ],
            if (hasAlt && st.cumDist.length >= 2 && st.distance >= 100) ...[
              const SectionHeader('Elevasi'),
              SoftCard(padding: const EdgeInsets.fromLTRB(6, 16, 14, 6), child: SizedBox(height: 150, child: _ElevChart(st))),
            ],
            if (efforts.isNotEmpty) ...[
              const SectionHeader('Upaya terbaik'),
              ListGroup(children: [
                for (final e in efforts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text(e.rank >= 0 && e.rank < 3 ? _medals[e.rank] : '·', translate: false, style: TextStyle(fontSize: e.rank >= 0 && e.rank < 3 ? 22 : 18, color: context.faint))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(e.label), translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink)),
                          Text(
                            e.rank == 0 ? tr('Rekor pribadi!') : e.rank == 1 ? tr('Tercepat ke-2') : e.rank == 2 ? tr('Tercepat ke-3') : '${fmtPace(e.secs / (e.m / 1000))} /km',
                            translate: false,
                            style: TextStyle(fontSize: 12.5, color: e.rank >= 0 && e.rank < 3 ? kTrack : context.muted, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      Text(fmtDur(e.secs), translate: false, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.ink)),
                    ]),
                  ),
              ]),
            ],
            if (laps.length >= 2) ...[
              const SectionHeader('Lap'),
              ListGroup(children: [
                for (final l in laps)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 56, child: Text('${tr('Lap')} ${l.index}', translate: false, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
                      Expanded(child: Text('${fmtKm(l.meters)} km', translate: false, style: TextStyle(color: context.muted))),
                      Text(fmtDur(l.secs), translate: false, style: TextStyle(color: context.muted)),
                      SizedBox(width: 92, child: Text('${paceOrSpeed(a.type, l.meters, l.secs)} ${paceUnit(a.type)}', translate: false, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
                    ]),
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
    var rpe = a.rpe.toDouble();
    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ubah aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: t, decoration: InputDecoration(labelText: tr('Judul'))),
          const SizedBox(height: 12),
          TextField(controller: n, maxLines: 3, decoration: InputDecoration(labelText: tr('Catatan (opsional)'))),
          const SizedBox(height: 12),
          Text(rpe.round() == 0 ? tr('Usaha: belum diisi') : '${tr('Usaha')}: ${rpe.round()}/10 · ${tr(rpeLabel(rpe.round()))}', translate: false, style: TextStyle(fontWeight: FontWeight.w600, color: ctx.ink)),
          SliderTheme(
            data: SliderTheme.of(ctx).copyWith(activeTrackColor: kTrack, thumbColor: kTrack, inactiveTrackColor: kTrack.withValues(alpha: .18)),
            child: Slider(value: rpe, min: 0, max: 10, divisions: 10, onChanged: (v) => setS(() => rpe = v)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTrack, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () async {
              await ref.read(trackProvider.notifier).update(a.copyWith(title: t.text.trim().isEmpty ? a.title : t.text.trim(), note: n.text.trim(), rpe: rpe.round()));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      )),
    );
  }
}

/// Grafik pace (atau kecepatan sepeda) sepanjang jarak, dihaluskan per ±150 m.
class _PaceChart extends StatelessWidget {
  const _PaceChart(this.a);
  final Activity a;
  @override
  Widget build(BuildContext context) {
    final st = a.stats, speed = a.type.usesSpeed;
    final n = st.cumDist.length;
    final spots = <FlSpot>[];
    var j = 0, k = 0;
    const win = 150.0;
    for (var i = 0; i < n; i += math.max(1, n ~/ 120)) {
      final d = st.cumDist[i];
      while (j < n - 1 && st.cumDist[j] < d - win) {
        j++;
      }
      while (k < n - 1 && st.cumDist[k] < d + win) {
        k++;
      }
      final dd = st.cumDist[k] - st.cumDist[j], tt = st.cumTime[k] - st.cumTime[j];
      if (dd < 50 || tt <= 0) continue;
      final kmh = dd / tt * 3.6;
      // pace dibalik (makin cepat makin tinggi) seperti Strava
      spots.add(FlSpot(d / 1000, speed ? kmh : -math.min(1200.0, 3600 / kmh)));
    }
    if (spots.length < 2) return const SizedBox.shrink();
    final ys = spots.map((s) => s.y);
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    final pad = math.max(speed ? 1.0 : 15.0, (hi - lo) * .15);
    final avg = speed ? st.avgKmh : -st.avgPace;
    String lab(double v) => speed ? v.toStringAsFixed(0) : fmtPace(-v);
    return LineChart(LineChartData(
      minY: lo - pad,
      maxY: hi + pad,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: avg, color: context.muted.withValues(alpha: .6), strokeWidth: 1, dashArray: [4, 4])]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => v == m.min || v == m.max ? const SizedBox.shrink() : Text(lab(v), translate: false, style: TextStyle(fontSize: 11, color: context.muted)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) => v == m.min || v == m.max ? const SizedBox.shrink() : Text('${v.toStringAsFixed(1).replaceAll('.', ',')} km', translate: false, style: TextStyle(fontSize: 10.5, color: context.muted)))),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: const Color(0xFF2563EB),
          barWidth: 2.2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withValues(alpha: .12), applyCutOffY: true, cutOffY: lo - pad),
        ),
      ],
    ));
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

/// Gaya kartu bagikan: langit malam, peta OSM, atau stiker transparan.
enum CardStyle { langit, peta, stiker }

/// Pratinjau kartu (3 gaya) lalu bagikan sebagai gambar 1080×1350.
Future<void> shareCardSheet(BuildContext context, Activity a) async {
  final key = GlobalKey();
  var style = CardStyle.langit;
  await showAppSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      final note = switch (style) {
        CardStyle.langit => 'Gaya langit malam IngetZeon.',
        CardStyle.peta => 'Peta © OpenStreetMap. Butuh internet untuk memuat peta.',
        CardStyle.stiker => 'Latar transparan — tempel di atas foto Story Instagram/WhatsApp.',
      };
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Bagikan aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (s, label) in const [(CardStyle.langit, '🌙 Langit'), (CardStyle.peta, '🗺️ Peta'), (CardStyle.stiker, '✨ Stiker')])
              ChoiceChip(
                label: Text(label),
                selected: style == s,
                showCheckmark: false,
                selectedColor: kTrack.withValues(alpha: dark ? .3 : .14),
                side: BorderSide(color: style == s ? kTrack : context.line),
                onSelected: (_) => setS(() => style = s),
              ),
          ]),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: style == CardStyle.stiker ? const _CheckerPainter() : null,
                child: FittedBox(child: RepaintBoundary(key: key, child: ShareCard(a: a, style: style))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(note, style: TextStyle(fontSize: 12.5, color: context.muted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kTrack, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              try {
                final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
                final img = await b.toImage(pixelRatio: 3);
                final data = await img.toByteData(format: ui.ImageByteFormat.png);
                final dir = await getTemporaryDirectory();
                final f = File('${dir.path}/IngetZeon_${a.id}_${style.name}.png');
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
      );
    }),
  );
}

/// Kartu 360×450 (diambil ×3 = 1080×1350, rasio 4:5 untuk Story/feed).
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.a, this.style = CardStyle.langit});
  final Activity a;
  final CardStyle style;

  static const _shadow = [Shadow(color: Color(0x73000000), blurRadius: 5, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final st = a.stats;
    final sticker = style == CardStyle.stiker, map = style == CardStyle.peta;
    final mute = sticker ? const Color(0xEBFFFFFF) : const Color(0xB8FFFFFF);
    final sh = sticker ? _shadow : null;
    final extra = [if (st.elevGain >= 1) '↑ ${st.elevGain.round()} m', if (a.kcal >= 1) '${a.kcal.round()} ${tr('kkal')}'].join('   ·   ');
    Widget stat(String label, String value, String unit) => Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 8, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mute, fontSize: 10, fontWeight: FontWeight.w500, shadows: sh)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(value, translate: false, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -.3, shadows: sh)),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(unit, translate: false, style: TextStyle(color: mute, fontSize: 10, fontWeight: FontWeight.w600, shadows: sh)),
                  ],
                ]),
              ),
            ]),
          ),
        );
    Widget divider() => sticker ? const SizedBox() : Container(width: .7, height: 30, color: const Color(0x29FFFFFF));
    return SizedBox(
      width: 360,
      height: 450,
      child: Stack(children: [
        // latar
        if (map && showMapTiles)
          Positioned.fill(child: IgnorePointer(child: RouteMap(segments: a.segments, interactive: false, attribution: false, fitPadding: const EdgeInsets.fromLTRB(60, 120, 60, 170))))
        else if (!sticker)
          const Positioned.fill(child: CustomPaint(painter: _CardSkyPainter())),
        if (map && showMapTiles) ...[
          Positioned(left: 0, right: 0, top: 0, height: 120, child: _fade(const Color(0xEB0A1238), const Color(0x000A1238))),
          Positioned(left: 0, right: 0, bottom: 0, height: 175, child: _fade(const Color(0x000A1238), const Color(0xF20A1238), mid: const Color(0xDB0A1238))),
          const Positioned(right: 24, top: 304, child: Text('© OpenStreetMap', translate: false, style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 7.5, fontWeight: FontWeight.w500))),
        ] else
          Positioned(left: 40, right: 40, top: 107, height: 193, child: CustomPaint(painter: _CardRoutePainter(a.segments, color: sticker ? Colors.white : const Color(0xFFFFE7A8), glow: sticker ? const Color(0x59000000) : const Color(0x590A1238)))),
        // kepala
        Positioned(
          left: 24,
          right: 70,
          top: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Container(
                padding: EdgeInsets.symmetric(horizontal: sticker ? 0 : 9, vertical: 4),
                decoration: BoxDecoration(color: sticker ? null : const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(20)),
                child: Text('${a.type.emoji}  ${tr(a.type.label)}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600, shadows: sh)),
              )),
              const SizedBox(width: 8),
              Flexible(child: Text('${fmtDateShort(a.start)} · ${fmtTime(a.start)}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mute, fontSize: 10.5, fontWeight: FontWeight.w500, shadows: sh))),
            ]),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(a.title, translate: false, maxLines: 1, style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -.3, shadows: sh)),
            ),
          ]),
        ),
        // panel angka
        Positioned(
          left: 20,
          right: 20,
          top: 323,
          height: 70,
          child: Container(
            decoration: sticker ? null : BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0x29FFFFFF), width: .7)),
            child: Row(children: [
              stat(tr('Jarak'), fmtKm(st.distance), 'km'),
              divider(),
              stat(tr(paceLabel(a.type)), paceOrSpeed(a.type, st.distance, st.moving), paceUnit(a.type).trim()),
              divider(),
              stat(tr('Waktu'), fmtDur(st.moving), ''),
            ]),
          ),
        ),
        // kaki
        Positioned(
          left: 24,
          right: 24,
          top: 409,
          height: 21,
          child: Row(children: [
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: sticker ? const [BoxShadow(color: Color(0x59000000), blurRadius: 5)] : null),
              child: const Icon(Icons.notifications_none_rounded, size: 14, color: Color(0xFF5B54E8)),
            ),
            const SizedBox(width: 7),
            Text('IngetZeon', translate: false, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: sh)),
            const SizedBox(width: 10),
            Expanded(child: Text(extra, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: mute, fontSize: 10, fontWeight: FontWeight.w500, shadows: sh))),
          ]),
        ),
      ]),
    );
  }

  static Widget _fade(Color a, Color b, {Color? mid}) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [a, if (mid != null) mid, b], stops: mid != null ? const [0, .45, 1] : null)),
      );
}

/// Langit malam: gradasi, bintang (tetap), bulan sabit, dua bukit.
class _CardSkyPainter extends CustomPainter {
  const _CardSkyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, s = w / 360;
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A1238), Color(0xFF1A2F7A), Color(0xFF2D4FB8)], stops: [0, .55, 1]).createShader(Offset.zero & size));
    var seed = 7;
    double rnd() => (seed = (seed * 9301 + 49297) % 233280) / 233280;
    for (var i = 0; i < 46; i++) {
      final x = rnd() * w, y = rnd() * h * .62, r = (1.2 + rnd() * 2.2) / 3 * s;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: .25 + rnd() * .6));
    }
    // bulan sabit
    canvas.saveLayer(Rect.fromLTWH(290 * s, 20 * s, 50 * s, 50 * s), Paint());
    canvas.drawCircle(Offset(313.3 * s, 43.3 * s), 14 * s, Paint()..color = const Color(0xFFFDE68A));
    canvas.drawCircle(Offset(320 * s, 38 * s), 12.7 * s, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawOval(Rect.fromCenter(center: Offset(83 * s, h + 23 * s), width: 520 * s, height: 220 * s), Paint()..color = const Color(0xFF1C2F74));
    canvas.drawOval(Rect.fromCenter(center: Offset(300 * s, h + 37 * s), width: 480 * s, height: 200 * s), Paint()..color = const Color(0xFF16265E));
  }

  @override
  bool shouldRepaint(_CardSkyPainter old) => false;
}

/// Rute untuk kartu: garis tebal + bayangan lembut, titik awal/akhir bercincin putih.
class _CardRoutePainter extends CustomPainter {
  _CardRoutePainter(this.segments, {required this.color, required this.glow});
  final List<List<TrackPoint>> segments;
  final Color color, glow;
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final s in segments) ...s];
    if (pts.length < 2) return;
    final k = math.cos(pts.first.lat * math.pi / 180);
    double x(TrackPoint p) => p.lon * k;
    double y(TrackPoint p) => -p.lat;
    final minX = pts.map(x).reduce(math.min), maxX = pts.map(x).reduce(math.max);
    final minY = pts.map(y).reduce(math.min), maxY = pts.map(y).reduce(math.max);
    final w = math.max(1e-9, maxX - minX), h = math.max(1e-9, maxY - minY);
    const pad = 8.0;
    final scale = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2;
    Offset o(TrackPoint p) => Offset(ox + (x(p) - minX) * scale, oy + (y(p) - minY) * scale);
    final paths = <Path>[];
    for (final s in segments) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(o(s.first).dx, o(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(o(p).dx, o(p).dy);
      }
      paths.add(path);
    }
    Paint line(Color c, double wd) => Paint()
      ..color = c
      ..strokeWidth = wd
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final g = line(glow, 8.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final l = line(color, 4.3);
    for (final p in paths) {
      canvas.drawPath(p, g);
    }
    for (final p in paths) {
      canvas.drawPath(p, l);
    }
    for (final (p, c) in [(pts.first, const Color(0xFF10B981)), (pts.last, const Color(0xFFEF4444))]) {
      canvas.drawCircle(o(p), 6.6, Paint()..color = Colors.white);
      canvas.drawCircle(o(p), 4.3, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_CardRoutePainter old) => old.segments != segments || old.color != color;
}

/// Kotak-kotak abu tipis (penanda latar transparan) di pratinjau stiker.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F5F8));
    final p = Paint()..color = const Color(0xFFD9DCE6);
    const c = 12.0;
    for (var y = 0.0; y < size.height; y += c) {
      for (var x = ((y / c).round().isOdd ? c : 0.0); x < size.width; x += c * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, c, c), p);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}
