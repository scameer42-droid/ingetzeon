import 'package:flutter/material.dart';

/// Palet warna IngetZeon — netral & profesional dengan satu warna aksen.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B54E8);
  static const primaryDeep = Color(0xFF4A43D4);
  static const violetMid = Color(0xFF5B54E8);
  static const pink = Color(0xFFE5484D); // merah untuk hapus / terlewat
  static const peach = Color(0xFFD97706);

  static const bgLight = Color(0xFFF6F6F8);
  static const bgDark = Color(0xFF0B0B0F);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF16161C);
  static const card2Light = Color(0xFFF2F2F5);
  static const card2Dark = Color(0xFF1E1E26);
  static const lineLight = Color(0xFFE6E6EB);
  static const lineDark = Color(0xFF2A2A33);
  static const inkLight = Color(0xFF111118);
  static const inkDark = Color(0xFFEDEDF0);
  static const mutedLight = Color(0xFF6B6B76);
  static const mutedDark = Color(0xFF9A9AA6);
  static const faintLight = Color(0xFFA1A1AA);
  static const faintDark = Color(0xFF62626E);

  /// Dipertahankan agar kode lama tetap jalan — kini warna aksen polos.
  static const gradient = LinearGradient(colors: [primary, primary]);
  static const meshBase = LinearGradient(colors: [primary, primary]);
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

  List<BoxShadow> get softShadow =>
      isDark ? const [] : [BoxShadow(color: const Color(0xFF101018).withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1))];

  List<BoxShadow> get glowShadow =>
      [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -8)];
}
