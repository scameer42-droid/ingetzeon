import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common.dart';

/// Layar sambutan saat aplikasi pertama kali dibuka: pilih bahasa & isi nama.
/// Tanpa akun dan tanpa kata sandi — semua tersimpan di HP.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// Tetap terisi walau layar dibangun ulang karena ganti bahasa.
  static String _draft = '';
  late final TextEditingController _name = TextEditingController(text: _draft);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      _draft = _name.text;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final n = _name.text.trim();
    if (n.isEmpty || _busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    await ref.read(settingsProvider.notifier).finishWelcome(n);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final ready = _name.text.trim().isNotEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF4338CA),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.aurora),
          child: Stack(children: [
            const Positioned(right: -80, top: -60, child: _Ring(size: 260)),
            const Positioned(left: -70, top: 260, child: _Blob(size: 200, color: Color(0xFF38BDF8))),
            const Positioned(right: -40, top: 360, child: _Blob(size: 140, color: Color(0xFFFDE68A))),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(children: [
                            const Spacer(),
                            _LangToggle(lang: lang, onChanged: (l) => ref.read(settingsProvider.notifier).setLang(l)),
                          ]),
                        ),
                        const Spacer(),
                        _hero(context),
                        const Spacer(),
                        _card(context, ready),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
          ),
          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -8)],
          ),
          child: ShaderMask(
            shaderCallback: (r) => AppColors.aurora.createShader(r),
            child: const Icon(Icons.notifications_active_rounded, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text('IngetZeon', translate: false, style: accentFont(size: 34, color: Colors.white)),
        const SizedBox(height: 6),
        const Text(
          'Asisten pribadi untuk jadwal, ibadah, kesehatan & banyak lagi',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 18),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          chip('⏰ Pengingat pintar'),
          chip('🕌 Muslim harian'),
          chip('🥗 Kalori & olahraga'),
          chip('🌐 Terjemah'),
        ]),
      ]),
    );
  }

  Widget _card(BuildContext context, bool ready) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Selamat datang 👋', style: accentFont(size: 24, color: context.ink)),
        const SizedBox(height: 4),
        Text('Siapa nama kamu? Biar aku bisa menyapamu.', style: TextStyle(fontSize: 14, color: context.muted)),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          autofocus: false,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 30,
          onSubmitted: (_) => _start(),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('Nama panggilan'),
            counterText: '',
            prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
            filled: true,
            fillColor: context.card2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            label: _busy ? 'Menyiapkan…' : 'Mulai',
            icon: Icons.arrow_forward_rounded,
            height: 56,
            onPressed: ready && !_busy ? _start : null,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: context.faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Tanpa akun & tanpa kata sandi — semua data tersimpan di HP kamu sendiri.',
                style: TextStyle(fontSize: 12, color: context.faint, height: 1.35)),
          ),
        ]),
      ]),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.lang, required this.onChanged});
  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opt(String id, String label) {
      final on = lang == id;
      return GestureDetector(
        onTap: on ? null : () => onChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(99)),
          child: Text(label, translate: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? AppColors.primary : Colors.white)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [opt('id', '🇮🇩 ID'), opt('en', '🇬🇧 EN')]),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .1), width: 40)),
      );
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: .35), color.withValues(alpha: 0)])),
      );
}
