import 'package:flutter/material.dart';

/// Palet IngetZeon — "Calm & Smart Daily Companion".
/// Satu warna utama untuk aksi & status aktif; sisanya netral yang tenang.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryDeep = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFEAF0FF);
  static const primarySoftDark = Color(0xFF1A2250);
  static const primaryOnDark = Color(0xFF7FB2FF);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFF43F5E);

  /// Nama lama dipertahankan agar layar lain tetap jalan.
  static const violetMid = primary;
  static const pink = error; // hapus / terlewat
  static const peach = warning;
  static const magenta = primary;
  static const sky = Color(0xFF0E8BD8);

  static const bgLight = Color(0xFFF4F6FB);
  static const bgDark = Color(0xFF0B0D19);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF141831);
  static const card2Light = Color(0xFFEEF1F8);
  static const card2Dark = Color(0xFF1B2040);
  static const lineLight = Color(0xFFE1E5EF);
  static const lineDark = Color(0xFF20254A);
  static const inkLight = Color(0xFF111633);
  static const inkDark = Color(0xFFEEF1FF);
  static const mutedLight = Color(0xFF5E6487);
  static const mutedDark = Color(0xFF8C93B8);
  static const faintLight = Color(0xFF9AA0BC);
  static const faintDark = Color(0xFF5F668C);

  /// Gradasi utama "biru laut": nila → biru → biru langit.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3730A3), Color(0xFF2563EB), Color(0xFF0EA5E9)],
    stops: [0, .55, 1],
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

  List<BoxShadow> get softShadow =>
      isDark ? const [] : [BoxShadow(color: const Color(0xFF111633).withValues(alpha: .05), blurRadius: 2, offset: const Offset(0, 1))];

  /// Latar kotak ikon (ikon garis berwarna di atasnya).
  Color get iconBox => isDark ? const Color(0xFF161A33) : const Color(0xFFEEF2FF);

  /// Tidak ada bayangan berwarna/berpendar — tampilan kalem.
  List<BoxShadow> colorShadow(Color c, {double strength = .35}) => const [];

  List<BoxShadow> get glowShadow => const [];
}
