import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/settings_provider.dart';
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

/// Kartu aktivitas gaya feed Strava: profil + waktu, judul, angka utama, pratinjau rute lebar.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.a, required this.onTap});
  final Activity a;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = a.stats;
    final set = ref.watch(settingsProvider);
    final name = set.name.trim().isEmpty ? tr('Kamu') : set.name.trim();
    return Container(
      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.line)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(children: [
                UserAvatar(name: name, path: set.avatarPath, size: 38, radius: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.ink)),
                    Text('${a.type.emoji} ${tr(dayLabel(a.start))} · ${fmtTime(a.start)}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(a.title, translate: false, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink, height: 1.25)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                Expanded(child: _Mini(tr('Jarak'), fmtKm(st.distance), 'km')),
                _VLine(),
                Expanded(child: _Mini(tr(paceLabel(a.type)), paceOrSpeed(a.type, st.distance, st.moving), paceUnit(a.type))),
                _VLine(),
                Expanded(child: _Mini(tr('Waktu'), fmtDur(st.moving), '')),
              ]),
            ),
            Container(
              height: 150,
              color: kTrack.withValues(alpha: context.isDark ? .10 : .06),
              child: CustomPaint(painter: _GridPainter(context.line.withValues(alpha: .7)), child: CustomPaint(painter: RoutePainter(a.segments, width: 3.4), child: const SizedBox.expand())),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.unit);
  final String label, value, unit;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, right: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, translate: false, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
              if (unit.isNotEmpty) Text(' $unit', translate: false, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.muted)),
            ]),
          ),
        ]),
      );
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 8), color: context.line);
}

/// Garis kisi tipis di belakang pratinjau rute (kesan peta).
class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 20.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
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

/// Tombol bulat dengan label di bawahnya (kontrol rekam gaya Strava).
class RoundBtn extends StatelessWidget {
  const RoundBtn({super.key, required this.icon, required this.label, required this.onTap, this.size = 56, this.bg, this.fg, this.big = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? bg, fg;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final b = bg ?? context.card2;
    return Semantics(
      button: true,
      label: tr(label),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: b,
          shape: CircleBorder(side: bg == null ? BorderSide(color: context.line) : BorderSide.none),
          elevation: big ? 3 : 0,
          shadowColor: b.withValues(alpha: .5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * (big ? .44 : .42), color: fg ?? context.ink)),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: math.max(size + 16, 74),
          child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.muted)),
        ),
      ]),
    );
  }
}

/// Lembar pilih jenis aktivitas (daftar dengan centang).
Future<ActivityType?> pickActivityType(BuildContext context, ActivityType current) => showAppSheet<ActivityType>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('Pilih jenis aktivitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          for (final t in ActivityType.values)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kTrack.withValues(alpha: ctx.isDark ? .2 : .1), shape: BoxShape.circle),
                child: Text(t.emoji, translate: false, style: const TextStyle(fontSize: 20)),
              ),
              title: Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, color: ctx.ink)),
              subtitle: Text(t.usesSpeed ? 'Kecepatan km/jam' : 'Pace menit/km', style: TextStyle(fontSize: 12.5, color: ctx.muted)),
              trailing: t == current ? const Icon(Icons.check_circle_rounded, color: kTrack) : Icon(Icons.circle_outlined, color: ctx.faint),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    );

/// Pengaturan rekam: target mingguan, aba-aba suara, jeda otomatis.
Future<void> showTrackSettings(BuildContext context) => showAppSheet(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final s = ref.watch(trackProvider);
        final n = ref.read(trackProvider.notifier);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Pengaturan rekam', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kTrack,
              title: const Text('Jeda otomatis', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Waktu berhenti sendiri saat kamu diam (lampu merah, istirahat)', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
              value: s.autoPause,
              onChanged: n.setAutoPause,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kTrack,
              title: const Text('Aba-aba suara tiap 1 km', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Jarak, waktu, dan pace dibacakan', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
              value: s.voice,
              onChanged: n.setVoice,
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Expanded(child: Text('Target jarak per minggu', style: TextStyle(fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => n.setGoal(s.weeklyGoalKm - 5), icon: const Icon(Icons.remove_circle_outline_rounded)),
              Text('${s.weeklyGoalKm} km', translate: false, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(onPressed: () => n.setGoal(s.weeklyGoalKm + 5), icon: const Icon(Icons.add_circle_outline_rounded)),
            ]),
          ]),
        );
      }),
    );
