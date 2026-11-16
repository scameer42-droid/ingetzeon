import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/reminder.dart';

/// Kartu putih membulat dengan bayangan tipis.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 16, this.onTap, this.color});

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
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.2, color: context.ink)),
          ),
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
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .4), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -12)]),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// Lembar bawah standar: selalu bisa digulir, tidak lebih tinggi dari 92% layar,
/// dan isinya tidak tertutup garis navigasi HP.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scroll = true,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: showDragHandle,
    builder: (c) {
      final child = SafeArea(top: false, child: builder(c));
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .92),
        child: scroll ? SingleChildScrollView(child: child) : child,
      );
    },
  );
}

/// Judul lembar bawah yang seragam.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.2)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: TextStyle(fontSize: 13, color: context.muted)),
          ],
        ]),
      );
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

/// Gaya judul tegas.
TextStyle accentFont({double size = 24, Color? color, FontWeight weight = FontWeight.w800}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, height: 1.2, letterSpacing: -.5);

/// Latar polos netral.
class AestheticBackground extends StatelessWidget {
  const AestheticBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.bg, child: child);
}

/// Kartu utama bergradasi nila → ungu dengan ornamen lingkaran halus.
class MeshCard extends StatelessWidget {
  const MeshCard({super.key, required this.child, this.radius = 24, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 16), spreadRadius: -14)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: -70,
          top: -90,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 34)),
          ),
        ),
        Positioned(
          right: 30,
          bottom: -60,
          child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07))),
        ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}


/// Foto profil pengguna; bila belum ada foto, tampil inisial nama di atas gradasi.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, required this.path, this.size = 42, this.radius, this.onGradient = false});
  final String name;
  final String path;
  final double size;
  final double? radius;

  /// true bila diletakkan di atas kartu gradasi (latar inisial jadi transparan putih).
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? size * .36);
    final hasPhoto = path.isNotEmpty && File(path).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: hasPhoto || onGradient ? null : AppColors.gradient,
        color: onGradient && !hasPhoto ? Colors.white.withValues(alpha: .2) : null,
        borderRadius: r,
        border: hasPhoto ? Border.all(color: Colors.white.withValues(alpha: onGradient ? .7 : 1), width: 2) : null,
        boxShadow: onGradient ? null : context.glowShadow,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? Image.file(File(path), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _initial())
          : _initial(),
    );
  }

  Widget _initial() => Text((name.trim().isEmpty ? 'I' : name.trim()[0]).toUpperCase(),
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .4));
}
