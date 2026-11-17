import 'package:flutter/material.dart';

/// Palet warna IngetZeon — netral & profesional dengan satu warna aksen.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF4F46E5);
  static const primaryDeep = Color(0xFF4338CA);
  static const violetMid = Color(0xFF7C3AED);
  static const pink = Color(0xFFE5484D); // merah untuk hapus / terlewat
  static const peach = Color(0xFFD97706);

  static const bgLight = Color(0xFFF7F7F8);
  static const bgDark = Color(0xFF0F0F11);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF18181B);
  static const card2Light = Color(0xFFF2F2F4);
  static const card2Dark = Color(0xFF222226);
  static const lineLight = Color(0xFFE7E7EB);
  static const lineDark = Color(0xFF2A2A2F);
  static const inkLight = Color(0xFF111114);
  static const inkDark = Color(0xFFF4F4F5);
  static const mutedLight = Color(0xFF6B6B76);
  static const mutedDark = Color(0xFFA1A1AA);
  static const faintLight = Color(0xFFA1A1AA);
  static const faintDark = Color(0xFF6B6B74);

  static const magenta = Color(0xFFC026D3);
  static const sky = Color(0xFF0EA5E9);

  /// Gaya minimalis: warna aksen polos (tanpa gradasi mencolok).
  static const gradient = LinearGradient(colors: [primary, primary]);

  /// Kartu utama: gelap polos yang tenang.
  static const aurora = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF18181B), Color(0xFF27272A)]);
  static const meshBase = aurora;

  /// Latar ikon: warna sangat lembut.
  static LinearGradient tint(Color c) => LinearGradient(colors: [c.withValues(alpha: .1), c.withValues(alpha: .1)]);
}

/// Akses cepat warna sesuai tema terang/gelap.
extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => isDark ? AppColors.inkDark : AppColors.inkLight;
  Color get muted => isDark ? AppColors.mutedDark : AppColors.mutedLight;
  Color get faint => isDark ? AppColors.faintDark : AppColors.faintLight;
  Color get card => isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get card2 => isDark ? AppColors.card2Dark : AppColors.card2Light;
  Color get line => isDark ? AppColors.lineDark : AppColors.lineLight;
  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get glass => card;
  Color get glassLine => line;

  List<BoxShadow> get softShadow => isDark
      ? const []
      : [BoxShadow(color: const Color(0xFF111114).withValues(alpha: .04), blurRadius: 10, offset: const Offset(0, 2))];

  /// Bayangan berwarna dimatikan di gaya minimalis.
  List<BoxShadow> colorShadow(Color c, {double strength = .35}) => const [];

  List<BoxShadow> get glowShadow =>
      [BoxShadow(color: AppColors.primary.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -6)];
}
