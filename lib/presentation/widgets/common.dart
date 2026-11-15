import 'package:flutter/material.dart';

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
        color: color ?? context.card,
        borderRadius: BorderRadius.circular(radius),
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
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
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
