import 'package:flutter/material.dart';

/// Palet IngetZeon — "Calm & Smart Daily Companion".
/// Satu warna utama untuk aksi & status aktif; sisanya netral yang tenang.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B5CE2);
  static const primaryDeep = Color(0xFF4748C9);
  static const primarySoft = Color(0xFFEEEDFF);
  static const primarySoftDark = Color(0xFF262650);
  static const primaryOnDark = Color(0xFF9A9BF7);

  static const success = Color(0xFF16856B);
  static const warning = Color(0xFFB76A09);
  static const error = Color(0xFFD92D20);

  /// Nama lama dipertahankan agar layar lain tetap jalan.
  static const violetMid = primary;
  static const pink = error; // hapus / terlewat
  static const peach = warning;
  static const magenta = primary;
  static const sky = Color(0xFF0E8BD8);

  static const bgLight = Color(0xFFF7F8FC);
  static const bgDark = Color(0xFF0F1117);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF181B24);
  static const card2Light = Color(0xFFF2F4F8);
  static const card2Dark = Color(0xFF20242F);
  static const lineLight = Color(0xFFE8ECF2);
  static const lineDark = Color(0xFF2A2F3B);
  static const inkLight = Color(0xFF182230);
  static const inkDark = Color(0xFFF2F4F7);
  static const mutedLight = Color(0xFF667085);
  static const mutedDark = Color(0xFF98A2B3);
  static const faintLight = Color(0xFF98A2B3);
  static const faintDark = Color(0xFF667085);

  /// Dulu gradasi; kini warna polos supaya tampilan tenang dan konsisten.
  static const gradient = LinearGradient(colors: [primary, primary]);
  static const aurora = gradient;
  static const meshBase = gradient;

  /// Isi polos satu warna (nama lama dipertahankan).
  static LinearGradient tint(Color c) => LinearGradient(colors: [c, c]);
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
      : [BoxShadow(color: const Color(0xFF101828).withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1))];

  /// Bayangan berwarna tidak dipakai lagi (dibiarkan agar pemanggil lama tetap jalan).
  List<BoxShadow> colorShadow(Color c, {double strength = .35}) => const [];

  List<BoxShadow> get glowShadow => const [];
}
