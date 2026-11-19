import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Waktu langit di beranda: pagi, siang, sore, malam.
enum SkyPhase {
  pagi,
  siang,
  sore,
  malam;

  static SkyPhase of(DateTime d) {
    final h = d.hour;
    if (h >= 4 && h < 10) return SkyPhase.pagi;
    if (h >= 10 && h < 15) return SkyPhase.siang;
    if (h >= 15 && h < 18) return SkyPhase.sore;
    return SkyPhase.malam;
  }

  List<Color> get sky => switch (this) {
        SkyPhase.pagi => const [Color(0xFF2F6FD0), Color(0xFF5E9BE3), Color(0xFFF2B880)],
        SkyPhase.siang => const [Color(0xFF1B66D6), Color(0xFF3A8CE8), Color(0xFF4DA2F2)],
        SkyPhase.sore => const [Color(0xFF2A2F7A), Color(0xFF8B3F86), Color(0xFFF08A4B)],
        SkyPhase.malam => const [Color(0xFF0E1A4A), Color(0xFF1E3A8A), Color(0xFF3B5BC4)],
      };

  List<Color> get hills => switch (this) {
        SkyPhase.pagi => const [Color(0xFF4C86D2), Color(0xFF3F79C6)],
        SkyPhase.siang => const [Color(0xFF2A78DD), Color(0xFF2169CF)],
        SkyPhase.sore => const [Color(0xFF3A2D6E), Color(0xFF2F2560)],
        SkyPhase.malam => const [Color(0xFF2C4BA8), Color(0xFF24409A)],
      };

  /// Warna teks tombol putih di atas langit.
  Color get ink => switch (this) {
        SkyPhase.sore => const Color(0xFF2A2F7A),
        _ => const Color(0xFF1E3A8A),
      };
}

/// Kepala beranda bergambar langit yang berganti sesuai waktu, dengan bukit di bawahnya.
/// Isi ([child]) berwarna putih; sisakan ruang di kanan atas untuk matahari/bulan.
class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key, required this.phase, required this.child, this.bottom = 64});
  final SkyPhase phase;
  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: CustomPaint(
        painter: _SkyPainter(phase, top),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, bottom),
          child: child,
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.phase, this.top);
  final SkyPhase phase;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: phase.sky).createShader(rect),
    );

    // bintang (malam) — hanya di sisi kanan & bawah supaya tidak menimpa tulisan
    if (phase == SkyPhase.malam) {
      const pts = [
        [.53, .36], [.64, .21], [.90, .76], [.31, .70], [.77, .68], [.15, .82], [.49, .79], [.95, .12], [.41, .61], [.08, .73]
      ];
      for (var i = 0; i < pts.length; i++) {
        canvas.drawCircle(
          Offset(size.width * pts[i][0], size.height * pts[i][1]),
          i % 3 == 0 ? 1.8 : 1.2,
          Paint()..color = Colors.white.withValues(alpha: i.isEven ? .85 : .5),
        );
      }
    }

    // matahari / bulan + awan di pojok kanan
    final box = Rect.fromLTWH(size.width - 128, top + 84, 110, 82);
    Offset at(double x, double y) => Offset(box.left + x * box.width / 120, box.top + y * box.height / 90);
    final k = box.width / 120;
    switch (phase) {
      case SkyPhase.malam:
        canvas.saveLayer(box.inflate(30), Paint());
        canvas.drawCircle(at(72, 42), 26 * k, Paint()..color = const Color(0xFFFDE68A));
        canvas.drawCircle(at(86, 32), 26 * k, Paint()..blendMode = BlendMode.clear);
        canvas.restore();
      case SkyPhase.pagi:
        canvas.drawCircle(at(80, 46), 24 * k, Paint()..color = const Color(0xFFFFE7A3));
        _cloud(canvas, at(2, 50), .85 * k);
      case SkyPhase.siang:
        canvas.drawCircle(at(82, 34), 24 * k, Paint()..color = const Color(0xFFFFD66B));
        _cloud(canvas, at(8, 44), .95 * k);
      case SkyPhase.sore:
        canvas.drawCircle(at(74, 52), 27 * k, Paint()..color = const Color(0xFFFFC46B));
        _cloud(canvas, at(0, 14), .6 * k);
    }

    // dua bukit di bawah
    final hb = size.height;
    final w = size.width;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .23, hb + 10), width: w * 1.18, height: 124), Paint()..color = phase.hills[0]);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .85, hb + 18), width: w * 1.13, height: 112), Paint()..color = phase.hills[1]);
  }

  void _cloud(Canvas canvas, Offset o, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .9);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy + 10 * s, 64 * s, 16 * s), Radius.circular(8 * s)), p);
    canvas.drawCircle(Offset(o.dx + 22 * s, o.dy + 12 * s), 11 * s, p);
    canvas.drawCircle(Offset(o.dx + 40 * s, o.dy + 9 * s), 13 * s, p);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.phase != phase || old.top != top;
}

/// Hiasan bukit lembut di bagian bawah kartu utama fitur (senada dengan langit beranda).
class HillsPainter extends CustomPainter {
  const HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .23, h + 16), width: w * 1.18, height: 100), Paint()..color = Colors.black.withValues(alpha: .10));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .85, h + 22), width: w * 1.13, height: 92), Paint()..color = Colors.black.withValues(alpha: .14));
  }

  @override
  bool shouldRepaint(HillsPainter old) => false;
}
