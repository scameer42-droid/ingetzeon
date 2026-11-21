import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/track_provider.dart';
import '../../../services/track_logic.dart';
import '../../widgets/common.dart';

const kTrack = FeatureColors.track;

/// Tes: matikan ubin peta (tanpa internet).
bool showMapTiles = true;

/// Pace atau kecepatan sesuai jenis aktivitas.
String paceOrSpeed(ActivityType t, double meters, int secs) {
  if (meters < 10 || secs <= 0) return t.usesSpeed ? '0,0' : '–:––';
  return t.usesSpeed ? (meters / secs * 3.6).toStringAsFixed(1).replaceAll('.', ',') : fmtPace(secs / (meters / 1000));
}

String paceUnit(ActivityType t) => t.usesSpeed ? 'km/j' : '/km';
String paceLabel(ActivityType t) => t.usesSpeed ? 'Kecepatan' : 'Pace';

/// Peta OpenStreetMap dengan rute (garis) dan posisi terkini.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.segments, this.here, this.follow = false, this.interactive = true, this.zoom = 16, this.attribution = true, this.fitPadding = const EdgeInsets.all(36)});
  final List<List<TrackPoint>> segments;
  final TrackPoint? here;
  final bool follow, interactive, attribution;
  final EdgeInsets fitPadding;
  final double zoom;
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _ctl = MapController();
  bool _ready = false;

  List<LatLng> get _all => [for (final s in widget.segments) for (final p in s) LatLng(p.lat, p.lon)];

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (_ready && widget.follow && widget.here != null) {
      try {
        _ctl.move(LatLng(widget.here!.lat, widget.here!.lon), _ctl.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final h = widget.here;
    final center = h != null ? LatLng(h.lat, h.lon) : (all.isNotEmpty ? all.last : const LatLng(-6.2088, 106.8456));
    final fit = !widget.follow && all.length >= 2;
    return ClipRect(
      child: FlutterMap(
        mapController: _ctl,
        options: MapOptions(
          initialCenter: center,
          initialZoom: widget.zoom,
          initialCameraFit: fit ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(all), padding: widget.fitPadding) : null,
          interactionOptions: InteractionOptions(flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
          onMapReady: () => _ready = true,
        ),
        children: [
          if (showMapTiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zeon.ingetzeon',
              maxZoom: 19,
            ),
          PolylineLayer(polylines: [
            for (final s in widget.segments)
              if (s.length >= 2) Polyline(points: [for (final p in s) LatLng(p.lat, p.lon)], color: kTrack, strokeWidth: 5, borderColor: Colors.white, borderStrokeWidth: 1.5),
          ]),
          MarkerLayer(markers: [
            if (all.isNotEmpty && !widget.follow) Marker(point: all.first, width: 18, height: 18, child: const _Dot(color: Color(0xFF10B981))),
            if (all.length >= 2 && !widget.follow) Marker(point: all.last, width: 18, height: 18, child: const _Dot(color: Color(0xFFDC2626))),
            if (h != null && widget.follow) Marker(point: LatLng(h.lat, h.lon), width: 26, height: 26, child: const _Dot(color: Color(0xFF2563EB), size: 26)),
          ]),
          if (widget.attribution)
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(6)),
              child: const Text('© OpenStreetMap', translate: false, maxLines: 1, style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 18});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)]),
      );
}

/// Gambar bentuk rute tanpa peta (untuk kartu riwayat & kartu bagikan).
class RoutePainter extends CustomPainter {
  RoutePainter(this.segments, {this.color = kTrack, this.width = 3.5});
  final List<List<TrackPoint>> segments;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final s in segments) ...s];
    if (pts.length < 2) return;
    // proyeksi sederhana (equirectangular) dengan koreksi lintang
    final k = math.cos(pts.first.lat * math.pi / 180);
    double x(TrackPoint p) => p.lon * k;
    double y(TrackPoint p) => -p.lat;
    final minX = pts.map(x).reduce(math.min), maxX = pts.map(x).reduce(math.max);
    final minY = pts.map(y).reduce(math.min), maxY = pts.map(y).reduce(math.max);
    final w = math.max(1e-9, maxX - minX), h = math.max(1e-9, maxY - minY);
    final pad = width * 2;
    final scale = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2;
    Offset o(TrackPoint p) => Offset(ox + (x(p) - minX) * scale, oy + (y(p) - minY) * scale);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in segments) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(o(s.first).dx, o(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(o(p).dx, o(p).dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(o(pts.first), width * 1.3, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(o(pts.last), width * 1.3, Paint()..color = const Color(0xFFDC2626));
  }

  @override
  bool shouldRepaint(RoutePainter old) => old.segments != segments;
}

/// Angka statistik: label kecil di atas, angka besar, satuan.
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.unit = '', this.big = false, this.light = false});
  final String label, value, unit;
  final bool big, light;
  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : context.ink, muted = light ? const Color(0xCCFFFFFF) : context.muted;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, translate: false, style: TextStyle(fontSize: big ? 44 : 24, fontWeight: FontWeight.w700, color: ink, height: 1.1, fontFeatures: const [FontFeature.tabularFigures()])),
          if (unit.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 3, bottom: 3), child: Text(unit, style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600))),
        ]),
      ),
    ]);
  }
}

/// Kartu riwayat aktivitas: bentuk rute + judul + angka utama.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.a, required this.onTap});
  final Activity a;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final st = a.stats;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: kTrack.withValues(alpha: context.isDark ? .16 : .08), borderRadius: BorderRadius.circular(14)),
          child: CustomPaint(painter: RoutePainter(a.segments, width: 2.6)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.type.emoji} ${a.title}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 2),
            Text('${tr(dayLabel(a.start))} · ${fmtTime(a.start)}', translate: false, style: TextStyle(fontSize: 12.5, color: context.muted)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Mini('${fmtKm(st.distance)} km', tr('Jarak'))),
              Expanded(child: _Mini('${paceOrSpeed(a.type, st.distance, st.moving)}${paceUnit(a.type)}', tr(paceLabel(a.type)))),
              Expanded(child: _Mini(fmtDur(st.moving), tr('Waktu'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, translate: false, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.ink))),
        Text(label, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.muted)),
      ]);
}

/// Pilihan jenis aktivitas.
class TypeChips extends StatelessWidget {
  const TypeChips({super.key, required this.value, required this.onChanged});
  final ActivityType value;
  final ValueChanged<ActivityType> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in ActivityType.values)
          ChoiceChip(
            label: Text('${t.emoji} ${tr(t.label)}', translate: false),
            selected: value == t,
            selectedColor: kTrack.withValues(alpha: .16),
            labelStyle: TextStyle(fontWeight: FontWeight.w600, color: value == t ? kTrack : context.ink),
            onSelected: (_) => onChanged(t),
          ),
      ]);
}
