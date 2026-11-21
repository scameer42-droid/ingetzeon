import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'sky.dart';
export 'sky.dart';
import '../../core/i18n/tr_text.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/reminder.dart';

/// Kartu permukaan dengan garis tepi lembut.
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
        decoration: BoxDecoration(color: context.iconBox, borderRadius: BorderRadius.circular(size * .3), border: Border.all(color: context.line)),
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
      padding: const EdgeInsets.fromLTRB(2, 28, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.2, color: context.ink)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.accent,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Kartu berisi baris-baris yang dipisah garis tipis.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.line),
        boxShadow: context.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 68, color: context.line),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// Baris standar: ikon berlatar lembut, judul, keterangan satu baris, dan aksi di kanan.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    this.progress,
    this.onTap,
    this.chevron = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final double? progress;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accent;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            CircleIcon(icon: icon, color: c, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.ink, height: 1.3)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.muted, height: 1.4)),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: progress!.clamp(0, 1).toDouble(), minHeight: 6, color: c, backgroundColor: context.card2),
                  ),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!]
            else if (chevron && onTap != null) ...[const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, color: context.faint, size: 22)],
          ]),
        ),
      ),
    );
  }
}

/// Tombol utama: warna utama polos, tinggi 50.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 50});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: onPressed == null ? null : AppColors.primary, borderRadius: BorderRadius.circular(12)),
        child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: context.card2,
          disabledForegroundColor: context.faint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          ],
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: context.accentSoft, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: context.accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 13.5)),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            SoftButton(label: actionLabel!, icon: Icons.add_rounded, onPressed: onAction, height: 48),
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
          TextField(controller: ctrl, autofocus: true, obscureText: obscure, decoration: InputDecoration(hintText: tr(hint))),
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
/// false = pakai font bawaan (untuk uji otomatis tanpa internet).
bool useGoogleFonts = true;

TextStyle accentFont({double size = 24, Color? color, FontWeight weight = FontWeight.w800}) => useGoogleFonts
    ? GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, height: 1.2, letterSpacing: -.5)
    : TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.2, letterSpacing: -.5);

/// Latar halaman polos.
class AestheticBackground extends StatelessWidget {
  const AestheticBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.bg, child: child);
}

/// Kartu utama bergradasi biru laut dengan hiasan cincin halus.
class MeshCard extends StatelessWidget {
  const MeshCard({super.key, required this.child, this.radius = 20, this.padding = const EdgeInsets.all(20), this.color});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Warna aksen fitur (lihat [FeatureColors]); null = gradasi biru utama.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final g = color == null ? AppColors.gradient : FeatureColors.hero(color!);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(radius)),
      child: CustomPaint(painter: const HillsPainter(), child: Padding(padding: padding, child: child)),
    );
  }
}

/// Satu warna aksen per fitur — dipakai untuk kartu utama, ikon, dan tombol utama fitur itu.
class FeatureColors {
  FeatureColors._();
  static const reminder = Color(0xFF2563EB);
  static const parking = Color(0xFF0E8BD8);
  static const items = Color(0xFFD97706);
  static const notes = Color(0xFF7C3AED);
  static const muslim = Color(0xFF059669);
  static const calorie = Color(0xFFEA580C);
  static const workout = Color(0xFFE11D48);
  static const calm = Color(0xFF0D9488);
  static const cycle = Color(0xFFDB2777);
  static const english = Color(0xFF4F46E5);
  static const translate = Color(0xFF0284C7);
  static const vital = Color(0xFFDC2626);
  static const track = Color(0xFFF4511E);

  /// Gradasi lembut satu warna untuk kartu utama fitur.
  static LinearGradient hero(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.black, .28)!, c],
      );
}

/// Kartu utama di atas tiap layar fitur: judul, keterangan, angka besar, dan tombol.
class FeatureHero extends StatelessWidget {
  const FeatureHero({
    super.key,
    required this.color,
    required this.title,
    this.label,
    this.subtitle,
    this.big,
    this.bigCaption,
    this.icon,
    this.actions = const [],
    this.child,
    this.trailing,
  });
  final Color color;
  final String title;
  final String? label, subtitle, big, bigCaption;
  final IconData? icon;
  final List<Widget> actions;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    const w80 = Color(0xCCFFFFFF);
    return MeshCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                  child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
              ],
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.25)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: w80, fontSize: 13, height: 1.4)),
              ],
            ]),
          ),
          if (trailing != null)
            trailing!
          else if (icon != null)
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
        ]),
        if (big != null) ...[
          const SizedBox(height: 12),
          if (bigCaption != null) Text(bigCaption!, style: const TextStyle(color: w80, fontSize: 12.5, fontWeight: FontWeight.w600)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(big!, translate: false, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.15)),
          ),
        ],
        if (child != null) ...[const SizedBox(height: 12), child!],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Flexible(child: actions[i]),
            ],
          ]),
        ],
      ]),
    );
  }
}

/// Tombol di dalam [FeatureHero]: putih (utama) atau garis putih (kedua).
class HeroButton extends StatelessWidget {
  const HeroButton({super.key, required this.label, required this.onTap, this.color, this.icon, this.secondary = false});
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final fg = secondary ? Colors.white : (color ?? AppColors.primary);
    return Material(
      color: secondary ? Colors.white.withValues(alpha: .14) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: secondary ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: .35))) : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13.5))),
          ]),
        ),
      ),
    );
  }
}

/// Ikon garis berwarna di kotak lembut — cara utama memberi warna di IngetZeon.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: context.isDark ? .18 : .10), borderRadius: BorderRadius.circular(size * .32)),
        child: Icon(icon, color: color, size: size * .5),
      );
}

/// Ikon putih di lingkaran berwarna penuh — gaya "Langit" untuk menu & daftar fitur.
class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.icon, required this.color, this.size = 54});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * .46),
      );
}

/// Ubin alat/pintasan: [IconTile] + label di bawah, di kartu putih bergaris.
class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleIcon(icon: icon, color: color, size: 44),
          const SizedBox(height: 8),
          Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.ink, height: 1.25)),
        ]),
      );
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
        color: hasPhoto ? null : (onGradient ? Colors.white.withValues(alpha: .2) : null),
        gradient: hasPhoto || onGradient ? null : AppColors.gradient,
        borderRadius: r,
        border: hasPhoto ? Border.all(color: Colors.white.withValues(alpha: onGradient ? .7 : 1), width: 2) : null,
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
