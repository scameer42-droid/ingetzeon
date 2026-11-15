import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/reminder.dart';

/// Kartu putih membulat dengan bayangan tipis.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20, this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? context.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.glassLine),
        boxShadow: context.softShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Kotak ikon kategori berwarna lembut.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 42, this.faded = false});
  final ReminderCategory category;
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? .5 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: category.soft, borderRadius: BorderRadius.circular(size * .33)),
        child: Icon(category.icon, color: category.color, size: size * .48),
      ),
    );
  }
}

/// Judul bagian dengan tautan aksi di kanan.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -.2))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

/// Tombol bergradasi ungu–pink.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 52});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(16), boxShadow: context.glowShadow),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol lembut (latar warna muda).
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed, this.icon, this.color = AppColors.primary, this.height = 50});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: context.isDark ? .18 : .1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle, this.actionLabel, this.onAction, this.icon = Icons.event_available_rounded});
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 13.5)),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            SoftButton(label: actionLabel!, icon: Icons.add_rounded, onPressed: onAction, height: 40),
          ],
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2400)));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String ok = 'OK', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Text(message, style: TextStyle(color: c.muted, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.pink : AppColors.primary),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<String?> inputDialog(BuildContext context, {required String title, String? message, String initial = '', String hint = '', bool obscure = false}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message, style: TextStyle(color: c.muted, fontSize: 13.5)), const SizedBox(height: 14)],
          TextField(controller: ctrl, autofocus: true, obscureText: obscure, decoration: InputDecoration(hintText: hint)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Simpan')),
      ],
    ),
  );
}

/// Huruf serif miring untuk aksen estetik (nama, judul kartu).
TextStyle accentFont({double size = 24, Color? color, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.fraunces(fontSize: size, fontStyle: FontStyle.italic, fontWeight: weight, color: color, height: 1.15);

/// Latar pastel dengan gumpalan warna lembut.
class AestheticBackground extends StatelessWidget {
  const AestheticBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = context.isDark ? .22 : 1.0;
    Widget blob(double size, Color c) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: c.a * a)),
        );
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: context.bg)),
      Positioned.fill(
        child: RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Stack(children: [
              Positioned(left: -80, top: -60, child: blob(280, const Color(0xBFB8AAFF))),
              Positioned(right: -90, top: 40, child: blob(260, const Color(0xB3FFB6CE))),
              Positioned(right: -60, bottom: 120, child: blob(240, const Color(0x8CFFD6BA))),
              Positioned(left: -70, bottom: -40, child: blob(260, const Color(0x8CBAF0E2))),
            ]),
          ),
        ),
      ),
      child,
    ]);
  }
}

/// Kartu bergradasi "mesh" (ungu–pink–peach).
class MeshCard extends StatelessWidget {
  const MeshCard({super.key, required this.child, this.radius = 28, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.meshBase,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: const Color(0xFF8C5AF0).withValues(alpha: .55), blurRadius: 40, offset: const Offset(0, 22), spreadRadius: -18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(1.1, -1.1), radius: 1.0, colors: [AppColors.peach.withValues(alpha: .95), AppColors.peach.withValues(alpha: 0)]),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(-1.1, 1.2), radius: 1.1, colors: [const Color(0xFF7B6CFF), const Color(0xFF7B6CFF).withValues(alpha: 0)]),
            ),
          ),
        ),
        Positioned(right: -50, top: -70, child: _circle(180, .16)),
        Positioned(right: 40, bottom: -70, child: _circle(120, .10)),
        Padding(padding: padding, child: child),
      ]),
    );
  }

  Widget _circle(double s, double a) =>
      Container(width: s, height: s, decoration: BoxDecoration(color: Colors.white.withValues(alpha: a), shape: BoxShape.circle));
}
