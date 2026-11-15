import 'package:flutter/material.dart';

/// Palet warna IngetZeon.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF6C63FF);
  static const primaryDeep = Color(0xFF5148E0);
  static const violetMid = Color(0xFF8E6BFF);
  static const pink = Color(0xFFFF6584);

  static const bgLight = Color(0xFFF6F5FF);
  static const bgDark = Color(0xFF0E0D1A);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF191730);
  static const card2Light = Color(0xFFF1F0FB);
  static const card2Dark = Color(0xFF221F3D);
  static const lineLight = Color(0xFFECEAF7);
  static const lineDark = Color(0xFF2A2748);
  static const inkLight = Color(0xFF1E1B3A);
  static const inkDark = Color(0xFFF2F1FF);
  static const mutedLight = Color(0xFF6E6A8A);
  static const mutedDark = Color(0xFFA9A5CC);
  static const faintLight = Color(0xFFA9A5C4);
  static const faintDark = Color(0xFF6F6B94);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, violetMid, pink],
    stops: [0, .45, 1],
  );
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

  List<BoxShadow> get softShadow => isDark
      ? [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -12)]
      : [
          BoxShadow(color: const Color(0xFF281E78).withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: const Color(0xFF3C30B4).withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -14),
        ];

  List<BoxShadow> get glowShadow => [
        BoxShadow(color: AppColors.primary.withValues(alpha: .45), blurRadius: 28, offset: const Offset(0, 14), spreadRadius: -12),
      ];
}
