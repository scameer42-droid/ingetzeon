import 'package:flutter/material.dart';

/// Palet IngetZeon — "Calm & Smart Daily Companion".
/// Satu warna utama untuk aksi & status aktif; sisanya netral yang tenang.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF3B82F6);
  static const primaryDeep = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFE8F0FF);
  static const primarySoftDark = Color(0xFF1B2550);
  static const primaryOnDark = Color(0xFF60A5FA);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFF43F5E);

  /// Nama lama dipertahankan agar layar lain tetap jalan.
  static const violetMid = primary;
  static const pink = error; // hapus / terlewat
  static const peach = warning;
  static const magenta = primary;
  static const sky = Color(0xFF0E8BD8);

  static const bgLight = Color(0xFFF3F5FB);
  static const bgDark = Color(0xFF0A0C18);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF141730);
  static const card2Light = Color(0xFFEEF1F8);
  static const card2Dark = Color(0xFF1C2042);
  static const lineLight = Color(0xFFE2E6F0);
  static const lineDark = Color(0xFF23284D);
  static const inkLight = Color(0xFF121633);
  static const inkDark = Color(0xFFF1F3FF);
  static const mutedLight = Color(0xFF5D6487);
  static const mutedDark = Color(0xFF9CA3C7);
  static const faintLight = Color(0xFF9AA0BC);
  static const faintDark = Color(0xFF646B92);

  /// Gradasi utama "biru laut": nila → biru → biru langit.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4338CA), Color(0xFF2563EB), Color(0xFF0EA5E9)],
    stops: [0, .48, 1],
  );
  static const aurora = gradient;
  static const meshBase = gradient;

  /// Gradasi nama di sapaan.
  static const nameLight = LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]);
  static const nameDark = LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFFA78BFA)]);

  /// Ikon berkilau: warna yang sama, lebih terang di atas.
  static LinearGradient tint(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.white, .38)!, c],
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
  Color get glass => card;
  Color get glassLine => line;

  /// Warna utama untuk teks/ikon (lebih terang di mode gelap agar terbaca).
  Color get accent => isDark ? AppColors.primaryOnDark : AppColors.primary;

  /// Latar lembut untuk status aktif & ikon.
  Color get accentSoft => isDark ? AppColors.primarySoftDark : AppColors.primarySoft;

  List<BoxShadow> get softShadow => isDark
      ? const []
      : [
          BoxShadow(color: const Color(0xFF121633).withValues(alpha: .05), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: const Color(0xFF121633).withValues(alpha: .10), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -12),
        ];

  /// Bayangan berwarna lembut di bawah ikon/kartu bergradasi.
  List<BoxShadow> colorShadow(Color c, {double strength = .35}) =>
      [BoxShadow(color: c.withValues(alpha: strength + .2), blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -10)];

  List<BoxShadow> get glowShadow =>
      [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? .55 : .45), blurRadius: 36, offset: const Offset(0, 18), spreadRadius: -20)];
}
