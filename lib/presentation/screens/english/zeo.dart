import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ZeoMood { happy, sad }

/// Maskot Zeo — jam weker kecil yang mengangguk pelan, berkedip,
/// melompat saat jawaban benar dan bergoyang saat salah.
class Zeo extends StatefulWidget {
  const Zeo({super.key, this.size = 84, this.mood = ZeoMood.happy, this.pulse = 0, this.bob = true});
  final double size;
  final ZeoMood mood;

  /// Ubah angka ini untuk memicu animasi reaksi (lompat/goyang).
  final int pulse;
  final bool bob;

  @override
  State<Zeo> createState() => _ZeoState();
}

class _ZeoState extends State<Zeo> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    _idle.repeat();
  }

  @override
  void didUpdateWidget(covariant Zeo old) {
    super.didUpdateWidget(old);
    if (old.pulse != widget.pulse) _react.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _react]),
        builder: (context, _) {
          final t = _idle.value, r = _react.value;
          var dy = widget.bob && !reduce ? -4 * math.sin(t * 2 * math.pi).abs() : 0.0;
          var dx = 0.0, rot = 0.0, sx = 1.0, sy = 1.0;
          if (_react.isAnimating && !reduce) {
            if (widget.mood == ZeoMood.happy) {
              dy += -16 * math.sin(r * math.pi);
              sx = 1 + .05 * math.sin(r * math.pi);
              sy = 1 - .04 * math.sin(r * math.pi);
            } else {
              dx = 7 * math.sin(r * math.pi * 5) * (1 - r);
              rot = .1 * math.sin(r * math.pi * 5) * (1 - r);
            }
          }
          // kedip singkat di akhir siklus
          final blink = (t > .92 && t < .98) ? .15 : 1.0;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scaleX: sx,
                scaleY: sy,
                child: CustomPaint(size: Size.square(widget.size), painter: _ZeoPainter(mood: widget.mood, blink: blink)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZeoPainter extends CustomPainter {
  _ZeoPainter({required this.mood, required this.blink});
  final ZeoMood mood;
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s);
    final p = Paint()..isAntiAlias = true;
    p.color = const Color(0xFFFDB022);
    canvas.drawCircle(const Offset(30, 27), 13, p);
    canvas.drawCircle(const Offset(90, 27), 13, p);
    p.color = const Color(0xFFF79009);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 9, 12, 10), const Radius.circular(3)), p);
    p.color = const Color(0xFF4748C9);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(34, 100, 12, 12), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(74, 100, 12, 12), const Radius.circular(4)), p);
    p.color = const Color(0xFF5B5CE2);
    canvas.drawCircle(const Offset(60, 64), 44, p);
    p.color = Colors.white;
    canvas.drawCircle(const Offset(60, 64), 35, p);
    p.color = const Color(0xFF182230);
    canvas.drawOval(Rect.fromCenter(center: const Offset(47, 58), width: 10, height: 14 * blink), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(73, 58), width: 10, height: 14 * blink), p);
    if (blink > .5) {
      p.color = Colors.white;
      canvas.drawCircle(const Offset(49, 55), 1.8, p);
      canvas.drawCircle(const Offset(75, 55), 1.8, p);
    }
    p.color = const Color(0xFFFDA29B).withValues(alpha: .7);
    canvas.drawCircle(const Offset(38, 72), 5, p);
    canvas.drawCircle(const Offset(82, 72), 5, p);
    final m = Paint()
      ..color = const Color(0xFF182230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (mood == ZeoMood.happy) {
      path
        ..moveTo(48, 74)
        ..quadraticBezierTo(60, 86, 72, 74);
    } else {
      path
        ..moveTo(48, 80)
        ..quadraticBezierTo(60, 70, 72, 80);
    }
    canvas.drawPath(path, m);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZeoPainter o) => o.mood != mood || o.blink != blink;
}
