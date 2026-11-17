import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../services/workout_data.dart';

/// Ilustrasi animasi gerakan olahraga (figur digambar dengan kode, tanpa gambar dari luar).
/// Logika sama dengan figSVG di website/index.html.
const _lTorso = 46.0, _lNeck = 7.0, _rHead = 9.5, _lUa = 25.0, _lFa = 23.0, _lTh = 31.0, _lSh = 30.0, _lFoot = 9.0;
const figW = 200.0, figH = 150.0, _ground = 140.0;

const _rad = <String, double>{
  'hip': 7.5, 'shoulder': 7.5, 'sh1': 4, 'sh2': 4, 'hp1': 5, 'hp2': 5, 'neck': 3, 'head': 9.5, 'el1': 4, 'el2': 4,
  'hand1': 3.6, 'hand2': 3.6, 'knee1': 5, 'knee2': 5, 'ankle1': 4.2, 'ankle2': 4.2, 'toe1': 2.8, 'toe2': 2.8,
};

Offset _dir(double a) {
  final r = a * math.pi / 180;
  return Offset(math.sin(r), -math.cos(r));
}

Map<String, Offset> _joints(List<double?> p, bool front) {
  final t = p[0]!, h = p[1]!;
  final j = <String, Offset>{};
  const hip = Offset.zero;
  final sh = hip + _dir(t) * _lTorso;
  j['hip'] = hip;
  j['shoulder'] = sh;
  Offset off(Offset pt, double w, double sign) => pt + _dir(t + 90) * (w * sign);
  final sh1 = front ? off(sh, 11, 1) : sh, sh2 = front ? off(sh, 11, -1) : sh;
  final hp1 = front ? off(hip, 6.5, 1) : hip, hp2 = front ? off(hip, 6.5, -1) : hip;
  j['sh1'] = sh1;
  j['sh2'] = sh2;
  j['hp1'] = hp1;
  j['hp2'] = hp2;
  j['neck'] = sh + _dir(h) * _lNeck;
  j['head'] = sh + _dir(h) * (_lNeck + _rHead);
  j['el1'] = sh1 + _dir(p[2]!) * _lUa;
  j['hand1'] = j['el1']! + _dir(p[3]!) * _lFa;
  j['el2'] = sh2 + _dir(p[4]!) * _lUa;
  j['hand2'] = j['el2']! + _dir(p[5]!) * _lFa;
  j['knee1'] = hp1 + _dir(p[6]!) * _lTh;
  j['ankle1'] = j['knee1']! + _dir(p[7]!) * _lSh;
  j['knee2'] = hp2 + _dir(p[8]!) * _lTh;
  j['ankle2'] = j['knee2']! + _dir(p[9]!) * _lSh;
  final fa1 = p[10] ?? (front ? 180 : p[7]! - 90), fa2 = p[11] ?? (front ? 180 : p[9]! - 90);
  j['toe1'] = j['ankle1']! + _dir(fa1) * (front ? 3 : _lFoot);
  j['toe2'] = j['ankle2']! + _dir(fa2) * (front ? 3 : _lFoot);
  return j;
}

double _lowest(Map<String, Offset> j) {
  var m = -1e9;
  j.forEach((k, v) => m = math.max(m, v.dy + (_rad[k] ?? 3)));
  return m;
}

class FigurePrep {
  FigurePrep._(this.front, this.keys, this.off, this.s, this.tx, this.minX, this.maxX, this.props, this.dur);
  final bool front;
  final List<List<double?>> keys;
  final List<Offset> off;
  final double s, tx, minX, maxX, dur;
  final List<String> props;

  static final _cache = <String, FigurePrep>{};
  static FigurePrep? of(String id) {
    final c = _cache[id];
    if (c != null) return c;
    final f = exerciseFigures[id];
    if (f == null) return null;
    final (view, anchor, free, dur, props, keys) = f;
    final front = view == 'f';
    final off = <Offset>[];
    Offset a0 = Offset.zero;
    for (var i = 0; i < keys.length; i++) {
      final j = _joints(keys[i], front);
      final lift = keys[i][13] ?? 0;
      if (i == 0) {
        final oy = -_lowest(j) - lift;
        off.add(Offset(0, oy));
        a0 = j[anchor]! + Offset(0, oy);
        continue;
      }
      final ox = a0.dx - j[anchor]!.dx;
      final oy = free ? -_lowest(j) - lift : a0.dy - j[anchor]!.dy;
      off.add(Offset(ox, oy));
    }
    var minX = 1e9, maxX = -1e9, minY = 1e9;
    for (var i = 0; i < keys.length; i++) {
      _joints(keys[i], front).forEach((k, v) {
        final r = _rad[k] ?? 3, x = v.dx + off[i].dx, y = v.dy + off[i].dy;
        minX = math.min(minX, x - r);
        maxX = math.max(maxX, x + r);
        minY = math.min(minY, y - r);
      });
    }
    if (props.contains('chair')) minX -= 34;
    if (props.contains('wall')) minX -= 14;
    if (props.contains('wallR')) maxX += 14;
    if (props.contains('bench')) maxX += 22;
    if (props.contains('seat')) minX -= 6;
    final s = [1.25, (_ground - 8) / -minY, (figW - 20) / (maxX - minX)].reduce(math.min);
    final tx = figW / 2 - (minX + maxX) / 2 * s;
    return _cache[id] = FigurePrep._(front, keys, off, s, tx, minX, maxX, props, dur);
  }

  double _la(double? a, double? b, double u) {
    if (a == null || b == null) return (u < .5 ? a : b) ?? 0;
    final d = ((b - a + 540) % 360) - 180;
    return a + d * u;
  }

  /// Pose & geser pada fase 0..1.
  (List<double?>, Offset) at(double phase) {
    final n = keys.length;
    if (n == 1) return (keys[0], off[0]);
    final x = ((phase % 1) + 1) % 1 * n;
    final i = x.floor() % n, jn = (i + 1) % n;
    final u = (1 - math.cos((x - x.floor()) * math.pi)) / 2;
    final a = keys[i], b = keys[jn];
    final p = <double?>[];
    for (var k = 0; k < a.length; k++) {
      if (k >= 12) {
        p.add((a[k] ?? 0) + ((b[k] ?? 0) - (a[k] ?? 0)) * u);
      } else if (k == 10 || k == 11) {
        p.add(a[k] == null && b[k] == null ? null : _la(a[k] ?? (front ? 180 : a[k - 3]! - 90), b[k] ?? (front ? 180 : b[k - 3]! - 90), u));
      } else {
        p.add(_la(a[k], b[k], u));
      }
    }
    return (p, Offset.lerp(off[i], off[jn], u)!);
  }

  /// Fase gambar diam yang paling mewakili gerakan.
  double get stillPhase => keys.length > 1 ? 1 / keys.length : 0;
}

const _skin = Color(0xFFF2C29B), _skin2 = Color(0xFFD9A27A), _shirt = Color(0xFF2563EB), _shirt2 = Color(0xFF1D4ED8);
const _shorts = Color(0xFF1E293B), _shorts2 = Color(0xFF3B4A63), _shoe = Color(0xFFF97316), _shoe2 = Color(0xFFC2410C);
const _hair = Color(0xFF1F2937), _mat = Color(0xFFC7D7F5), _prop = Color(0xFF94A3B8);

class FigurePainter extends CustomPainter {
  FigurePainter(this.prep, this.phase, {this.matColor});
  final FigurePrep prep;
  final double phase;
  final Color? matColor;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width / figW, size.height / figH);
    canvas.save();
    canvas.translate((size.width - figW * k) / 2, (size.height - figH * k) / 2);
    canvas.scale(k);
    final P = prep, s = P.s;
    final (p, o) = P.at(phase);
    final j = _joints(p, P.front);
    Offset m(Offset pt) => Offset(P.tx + (pt.dx + o.dx) * s, _ground + (pt.dy + o.dy) * s);
    final paint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    void ln(Offset a, Offset b, double w, Color c) {
      paint
        ..color = c
        ..strokeWidth = w * s;
      canvas.drawLine(m(a), m(b), paint);
    }

    Offset mid(Offset a, Offset b, double u) => Offset.lerp(a, b, u)!;
    final fill = Paint();
    // alas / bayangan
    if (P.props.contains('mat')) {
      final x1 = P.tx + (P.minX - 6) * s, x2 = P.tx + (P.maxX + 6) * s;
      canvas.drawRRect(RRect.fromLTRBR(x1, _ground, x2, _ground + 5, const Radius.circular(2.5)), fill..color = matColor ?? _mat);
    } else {
      canvas.drawOval(Rect.fromCenter(center: const Offset(figW / 2, _ground + 2), width: 68 * s, height: 7), fill..color = const Color(0x1A0F172A));
    }
    if (P.props.contains('chair')) {
      final h0 = _joints(P.keys[0], P.front)['hand1']!;
      final hx = P.tx + (h0.dx + P.off[0].dx) * s, hy = _ground + (h0.dy + P.off[0].dy) * s + 3.6 * s;
      fill.color = _prop;
      canvas.drawRRect(RRect.fromLTRBR(hx - 34 * s, hy, hx + 6 * s, hy + 5 * s, const Radius.circular(2)), fill);
      canvas.drawRect(Rect.fromLTWH(hx - 32 * s, hy, 3.5 * s, _ground - hy), fill);
      canvas.drawRect(Rect.fromLTWH(hx + 1 * s, hy, 3.5 * s, _ground - hy), fill);
      canvas.drawRRect(RRect.fromLTRBR(hx - 34 * s, hy - 34 * s, hx - 30 * s, hy, const Radius.circular(2)), fill);
    }
    final k0 = _joints(P.keys[0], P.front);
    Offset at0(String n) => Offset(P.tx + (k0[n]!.dx + P.off[0].dx) * s, _ground + (k0[n]!.dy + P.off[0].dy) * s);
    void box(double x, double y, double w, double h) => canvas.drawRRect(RRect.fromLTRBR(x, y, x + w, y + math.max(0, h), const Radius.circular(2)), fill..color = _prop);
    if (P.props.contains('seat')) {
      final h = at0('hip'), hy = h.dy + 8.2 * s;
      box(h.dx - 18 * s, hy, 34 * s, 5 * s);
      box(h.dx - 16 * s, hy, 3.5 * s, _ground - hy);
      box(h.dx + 12 * s, hy, 3.5 * s, _ground - hy);
      box(h.dx - 18 * s, hy - 38 * s, 4 * s, 38 * s);
    }
    if (P.props.contains('bench')) {
      final h = at0('hand1'), hy = h.dy + 3.6 * s;
      box(h.dx - 14 * s, hy, 36 * s, 5 * s);
      box(h.dx - 12 * s, hy, 3.5 * s, _ground - hy);
      box(h.dx + 17 * s, hy, 3.5 * s, _ground - hy);
    }
    if (P.props.contains('wallR')) {
      final h = at0('hand1');
      canvas.drawRRect(RRect.fromLTRBR(h.dx + 3.8 * s, 6, h.dx + 3.8 * s + 10, _ground + 5, const Radius.circular(2)), fill..color = _prop.withValues(alpha: .55));
    }
    if (P.props.contains('wall')) {
      final b0 = _joints(P.keys[0], P.front);
      final wx = P.tx + (math.min(b0['hip']!.dx, b0['shoulder']!.dx) + P.off[0].dx - 8.5) * s;
      canvas.drawRRect(RRect.fromLTRBR(wx - 10, 6, wx, _ground + 5, const Radius.circular(2)), fill..color = _prop.withValues(alpha: .55));
    }

    void leg(String n, bool far) {
      final hp = j['hp$n'] ?? j['hip']!, kn = j['knee$n']!, an = j['ankle$n']!, to = j['toe$n']!;
      final so = far ? _shoe2 : _shoe;
      ln(kn, an, 8, far ? _skin2 : _skin);
      ln(hp, kn, 9.5, far ? _skin2 : _skin);
      ln(hp, mid(hp, kn, .62), 11, far ? _shorts2 : _shorts);
      ln(an, to, 5.5, so);
      ln(an, an, 6.5, so);
    }

    void arm(String n, bool far) {
      final sp = j['sh$n']!, el = j['el$n']!, hd = j['hand$n']!, sk = far ? _skin2 : _skin;
      ln(sp, el, 7.5, sk);
      ln(el, hd, 6.5, sk);
      ln(hd, hd, 7.4, sk);
      ln(sp, mid(sp, el, .35), 8.5, far ? _shirt2 : _shirt);
    }

    void torso() {
      final hp = j['hip']!, sh = j['shoulder']!, b = p[12] ?? 0;
      final c = mid(hp, sh, .5) + _dir(p[0]! - 90) * (b * 2);
      final path = Path()
        ..moveTo(m(hp).dx, m(hp).dy)
        ..quadraticBezierTo(m(c).dx, m(c).dy, m(sh).dx, m(sh).dy);
      canvas.drawPath(path, Paint()
        ..color = _shirt
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (P.front ? 21 : 15) * s);
      ln(sh, j['neck']!, 5.5, _skin);
      if (P.front) {
        ln(j['sh1']!, j['sh2']!, 9, _shirt);
        ln(j['hp1']!, j['hp2']!, 12, _shorts);
      } else {
        canvas.drawCircle(m(hp), 8.2 * s, fill..color = _shorts);
      }
    }

    void head() {
      final c = m(j['head']!), r = _rHead * s, hd = p[1]!;
      canvas.drawCircle(c, r, fill..color = _skin);
      final a1 = P.front ? hd - 78 : hd - 150, a2 = P.front ? hd + 78 : hd + 48;
      final rr = r + .6 * s;
      // sudut kanvas: 0 = kanan, searah jarum jam. Sudut kita: 0 = atas.
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), (a1 - 90) * math.pi / 180, (a2 - a1) * math.pi / 180, false, fill..color = _hair);
      if (!P.front) {
        final e = _dir(hd + 70);
        canvas.drawCircle(c + e * (r * .55), 1.3 * s, fill..color = _hair);
      }
    }

    if (P.front) {
      leg('1', false);
      leg('2', false);
      torso();
      arm('1', false);
      arm('2', false);
      head();
    } else {
      arm('2', true);
      leg('2', true);
      torso();
      leg('1', false);
      head();
      arm('1', false);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FigurePainter old) => old.phase != phase || old.prep != prep;
}

/// Figur gerakan. [animate] = bergerak terus; [paused] = berhenti di tempat.
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure(this.id, {super.key, this.animate = true, this.paused = false, this.speed = 1, this.matColor});
  final String id;
  final bool animate, paused;
  final double speed;
  final Color? matColor;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _t = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ExerciseFigure old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _t = 0;
    _sync();
  }

  void _sync() {
    final run = widget.animate && !widget.paused;
    if (run) {
      _ticker ??= createTicker((d) {
        final dt = (d - _last).inMicroseconds / 1e6;
        _last = d;
        final P = FigurePrep.of(widget.id);
        if (P == null) return;
        setState(() => _t += dt * widget.speed / P.dur);
      });
      if (!_ticker!.isActive) {
        _last = Duration.zero;
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final P = FigurePrep.of(widget.id);
    if (P == null) return const SizedBox();
    final phase = widget.animate ? _t : P.stillPhase;
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: figW / figH,
        child: CustomPaint(painter: FigurePainter(P, phase, matColor: widget.matColor)),
      ),
    );
  }
}
