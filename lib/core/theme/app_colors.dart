import 'package:flutter/material.dart';

/// Palet warna IngetZeon — netral & profesional dengan satu warna aksen.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF4F46E5);
  static const primaryDeep = Color(0xFF4338CA);
  static const violetMid = Color(0xFF7C3AED);
  static const pink = Color(0xFFE5484D); // merah untuk hapus / terlewat
  static const peach = Color(0xFFD97706);

  static const bgLight = Color(0xFFF4F5FA);
  static const bgDark = Color(0xFF0E0F1C);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF181A2E);
  static const card2Light = Color(0xFFF1F2F8);
  static const card2Dark = Color(0xFF22243A);
  static const lineLight = Color(0xFFE8E9F2);
  static const lineDark = Color(0xFF2B2D45);
  static const inkLight = Color(0xFF14142B);
  static const inkDark = Color(0xFFF1F1FA);
  static const mutedLight = Color(0xFF6E6F86);
  static const mutedDark = Color(0xFFA4A6C0);
  static const faintLight = Color(0xFFA3A4B8);
  static const faintDark = Color(0xFF686A86);

  /// Gradasi nila → ungu untuk elemen utama.
  static const gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, violetMid]);
  static const meshBase = gradient;
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
  Color get glassLine => isDark ? line : Colors.transparent;

  List<BoxShadow> get softShadow => isDark
      ? const []
      : [
          BoxShadow(color: const Color(0xFF14143C).withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: const Color(0xFF28286E).withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -10),
        ];

  List<BoxShadow> get glowShadow =>
      [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -8)];
}
