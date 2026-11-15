import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../providers/wellbeing_provider.dart';
import '../../../services/wellbeing_logic.dart';
import '../../widgets/common.dart';
import 'calm_tools.dart';

LinearGradient _grad(PsyTest t, {double a = 1}) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(t.colors[0]).withValues(alpha: a), Color(t.colors[1]).withValues(alpha: a)],
    );

/// Emoji yang melompat-lompat pelan.
class Bouncy extends StatefulWidget {
  const Bouncy(this.child, {super.key, this.delay = 0, this.height = 6});
  final Widget child;
  final int delay;
  final double height;
  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -widget.height * Curves.easeInOut.transform(_c.value)),
          child: Transform.rotate(angle: (Curves.easeInOut.transform(_c.value) - .5) * .12, child: child),
        ),
        child: widget.child,
      );
}

/// Muncul dengan efek naik + memudar (berurutan).
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 450 + index * 90),
        curve: Curves.easeOutBack,
        builder: (_, v, c) => Opacity(opacity: v.clamp(0, 1).toDouble(), child: Transform.translate(offset: Offset(0, (1 - v) * 40), child: c)),
        child: child,
      );
}

class TestsScreen extends ConsumerStatefulWidget {
  const TestsScreen({super.key});
  @override
  ConsumerState<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends ConsumerState<TestsScreen> with SingleTickerProviderStateMixin {
  late final _bg = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  int _q = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _q = (_q + 1) % PsyTest.quotes.length);
    });
  }

  @override
  void dispose() {
    _bg.dispose();
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(testsProvider);
    final tests = PsyTest.all;
    return Scaffold(
      appBar: AppBar(title: const Text('Tes psikologi'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        // header warna-warni yang bergerak
        AnimatedBuilder(
          animation: _bg,
          builder: (_, child) {
            final a = _bg.value * 2 * math.pi;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment(math.cos(a), math.sin(a)),
                  end: Alignment(-math.cos(a), -math.sin(a)),
                  colors: const [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
              ),
              child: child,
            );
          },
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned(right: 0, top: -6, child: Bouncy(Text('🚀', style: TextStyle(fontSize: 34)), height: 10)),
            const Positioned(right: 46, top: 40, child: Bouncy(Text('✨', style: TextStyle(fontSize: 20)), delay: 400)),
            const Positioned(right: 8, top: 64, child: Bouncy(Text('💪', style: TextStyle(fontSize: 24)), delay: 800)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(right: 70),
                child: Text('Kenali dirimu,\njadi makin kuat!', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, height: 1.15)),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (c, an) => FadeTransition(opacity: an, child: SlideTransition(position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(an), child: c)),
                child: Text(PsyTest.quotes[_q], key: ValueKey(_q), style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(99)),
                child: Text('${tests.length} tes · ${records.length} kali dikerjakan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // kartu unggulan
        Entrance(index: 0, child: _TestCard(test: tests.first, records: records, wide: true)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tests.length - 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .86),
          itemBuilder: (_, i) => Entrance(index: i + 1, child: _TestCard(test: tests[i + 1], records: records, delay: i * 250)),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: context.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tes ini skrining singkat, BUKAN diagnosis. Diagnosis hanya bisa dilakukan psikolog klinis, psikiater, atau dokter. Hasil tersimpan di HP ini saja.',
              style: TextStyle(fontSize: 12, height: 1.45, color: context.faint),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({required this.test, required this.records, this.wide = false, this.delay = 0});
  final PsyTest test;
  final List<TestRecord> records;
  final bool wide;
  final int delay;

  @override
  Widget build(BuildContext context) {
    TestRecord? last;
    for (final r in records) {
      if (r.test == test.id) {
        last = r;
        break;
      }
    }
    final info = '${test.items.length} soal · ±${test.minutes} mnt';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, __, ___) => TestRunScreen(test: test),
            transitionsBuilder: (_, an, __, c) => FadeTransition(
              opacity: an,
              child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: an, curve: Curves.easeOutBack)), child: c),
            ),
          ));
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: _grad(test),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Color(test.colors[1]).withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -10)],
          ),
          child: Stack(children: [
            Positioned(right: -18, top: -18, child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .13)))),
            Positioned(left: -24, bottom: -30, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08)))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(children: [
                      Bouncy(Text(test.emoji, style: const TextStyle(fontSize: 44)), delay: delay),
                      const SizedBox(width: 14),
                      Expanded(child: _texts(info, last)),
                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Bouncy(Text(test.emoji, style: const TextStyle(fontSize: 38)), delay: delay),
                      _texts(info, last),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _texts(String info, TestRecord? last) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (wide)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)),
            child: const Text('⭐ Mulai dari sini', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        Text(test.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 3),
        Text(test.short, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 12, height: 1.3)),
        const SizedBox(height: 6),
        Text(last == null ? info : 'Terakhir: ${last.level}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]);
}

/// ---------- Menjalankan tes ----------
class TestRunScreen extends ConsumerStatefulWidget {
  const TestRunScreen({super.key, required this.test});
  final PsyTest test;
  @override
  ConsumerState<TestRunScreen> createState() => _TestRunScreenState();
}

class _TestRunScreenState extends ConsumerState<TestRunScreen> {
  final _answers = <int>[];
  TestResult? _result;
  int? _tapped;

  Future<void> _answer(int optIndex) async {
    if (_tapped != null) return;
    HapticFeedback.selectionClick();
    setState(() => _tapped = optIndex);
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final t = widget.test;
    setState(() {
      _answers.add(t.options[optIndex].$2);
      _tapped = null;
    });
    if (_answers.length == t.items.length || t.stopsAfter(_answers)) await _finish();
  }

  Future<void> _finish() async {
    final r = TestResult.evaluate(widget.test, _answers);
    await ref.read(testsProvider.notifier).add(TestRecord(test: widget.test.id, score: r.score, max: r.max, level: r.level, at: DateTime.now()));
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    return Scaffold(
      backgroundColor: Color.lerp(context.bg, Color(t.colors[0]), .07),
      appBar: AppBar(
        title: Text('${t.emoji}  ${t.title}'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: _result != null ? _ResultView(test: t, result: _result!) : _question(context),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final t = widget.test;
    final n = t.items.length;
    final i = _answers.length.clamp(0, n - 1).toInt();
    final p = _answers.length / n;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      // progres dengan roket
      LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 40,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 22,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(height: 10, color: Color(t.colors[0]).withValues(alpha: .15)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              left: 0,
              top: 22,
              width: math.max(10, w * p),
              child: Container(height: 10, decoration: BoxDecoration(gradient: _grad(t), borderRadius: BorderRadius.circular(8))),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              left: (w * p - 14).clamp(0, w - 30).toDouble(),
              top: 0,
              child: const Text('🚀', style: TextStyle(fontSize: 24)),
            ),
            const Positioned(right: 0, top: 0, child: Text('🏁', style: TextStyle(fontSize: 20))),
          ]),
        );
      }),
      const SizedBox(height: 10),
      Row(children: [
        Text('Pertanyaan ${i + 1} dari $n', style: TextStyle(color: Color(t.colors[1]), fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('${(p * 100).round()}%', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Text(PsyTest.cheer(_answers.length, n), key: ValueKey(PsyTest.cheer(_answers.length, n)), style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        transitionBuilder: (c, an) => FadeTransition(
          opacity: an,
          child: SlideTransition(position: Tween(begin: const Offset(.25, 0), end: Offset.zero).animate(CurvedAnimation(parent: an, curve: Curves.easeOutCubic)), child: c),
        ),
        child: Column(key: ValueKey(i), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Color(t.colors[0]).withValues(alpha: .25), width: 1.5),
              boxShadow: context.softShadow,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (i == 0 || t.id == 'ptsd5' && i == 0) Text(t.intro, style: TextStyle(color: context.muted, height: 1.4)),
              if (i == 0) const SizedBox(height: 10),
              Text(t.items[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35)),
            ]),
          ),
          const SizedBox(height: 16),
          for (var k = 0; k < t.options.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedScale(
                scale: _tapped == k ? 1.04 : 1,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _answer(k),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: _tapped == k ? _grad(t) : _grad(t, a: .06 + .05 * k),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Color(t.colors[k.isEven ? 0 : 1]).withValues(alpha: .35)),
                      ),
                      child: Row(children: [
                        if (k < t.optEmoji.length) Text(t.optEmoji[k], style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(t.options[k].$1,
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _tapped == k ? Colors.white : context.ink)),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: _tapped == k ? Colors.white : Color(t.colors[1])),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      if (_answers.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _answers.removeLast()), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Sebelumnya')),
        ),
      const SizedBox(height: 8),
      Text('Sumber: ${t.source}.${t.clinical ? ' Terjemahan bebas untuk skrining mandiri.' : ''}', style: TextStyle(fontSize: 11.5, color: context.faint)),
    ]);
  }
}

/// ---------- Hasil ----------
class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.test, required this.result});
  final PsyTest test;
  final TestResult result;
  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> with SingleTickerProviderStateMixin {
  late final _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    final r = widget.result;
    final colors = [const Color(0xFF12A150), const Color(0xFFF59E0B), const Color(0xFFF97316), const Color(0xFFE11D48)];
    final c = colors[r.severity.clamp(0, 3).toInt()];
    final gentle = r.severity >= 2 || r.crisis;
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        if (r.crisis) ...[
          const HelpCard(urgent: true),
          const SizedBox(height: 10),
          Text(
            'Kamu menjawab pernah merasa hidup tidak berarti atau ingin menyakiti diri. Itu hal serius dan kamu layak mendapat dukungan sekarang — '
            'tolong hubungi Healing119 atau orang yang kamu percaya hari ini. Kamu tidak sendirian 💛',
            style: TextStyle(height: 1.45, color: context.ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
        ],
        Entrance(
          index: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(gradient: _grad(t), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Color(t.colors[1]).withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)]),
            child: Column(children: [
              Bouncy(Text(gentle ? '🤗' : '🏅', style: const TextStyle(fontSize: 54)), height: 8),
              const SizedBox(height: 4),
              const Text('Tes selesai!', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: r.score.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text('${v.round()}', style: accentFont(size: 60, color: Colors.white)),
              ),
              Text('dari ${r.max}', style: TextStyle(color: Colors.white.withValues(alpha: .85))),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(r.level, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              Text(r.summary, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.45, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        if (r.parts.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (var k = 0; k < r.parts.length; k++) Entrance(index: k + 1, child: _PartBar(part: r.parts[k], color: colors[r.parts[k].severity.clamp(0, 3).toInt()])),
        ],
        const SizedBox(height: 16),
        Entrance(
          index: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFDF2F8)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDBA74).withValues(alpha: .6)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Bouncy(Text('🔥', style: TextStyle(fontSize: 28)), delay: 300),
              const SizedBox(width: 12),
              Expanded(child: Text(r.cheer, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF7C2D12)))),
            ]),
          ),
        ),
        const SectionHeader('Langkah kecil untukmu'),
        for (var k = 0; k < r.advice.length; k++)
          Entrance(
            index: k + 3,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(gradient: _grad(t), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${k + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(r.advice[k], style: const TextStyle(height: 1.45))),
              ]),
            ),
          ),
        if (!r.crisis && r.severity >= 2) ...[const SizedBox(height: 6), const HelpCard()],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tool in const [Tool.napas, Tool.jurnal, Tool.mood]) ActionChip(label: Text(toolLabel(tool)), onPressed: () => openTool(context, ref, tool)),
        ]),
        const SizedBox(height: 16),
        GradientButton(label: 'Coba tes lainnya', icon: Icons.grid_view_rounded, onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 14),
        Text('Ini hasil skrining, bukan diagnosis. Kondisi bisa berubah — ulangi tes 2–4 minggu lagi untuk memantau. Dikerjakan ${fmtDateShort(DateTime.now())}.',
            style: TextStyle(fontSize: 12, color: context.faint, height: 1.4)),
      ]),
      // konfeti (atau hati melayang bila hasilnya berat)
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _fx,
            builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_fx.value, gentle: gentle, colors: [Color(t.colors[0]), Color(t.colors[1]), const Color(0xFFFACC15), const Color(0xFF22C55E), const Color(0xFFEC4899)])),
          ),
        ),
      ),
    ]);
  }
}

class _PartBar extends StatelessWidget {
  const _PartBar({required this.part, required this.color});
  final TestPart part;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(part.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(part.level, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: part.score / part.max),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withValues(alpha: .12)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, {required this.gentle, required this.colors});
  final double t;
  final bool gentle;
  final List<Color> colors;
  static final _rnd = List.generate(60, (i) => math.Random(i * 7 + 3));
  static final _seed = [for (final r in _rnd) (r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble())];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final n = gentle ? 16 : 60;
    for (var i = 0; i < n; i++) {
      final (a, b, c, d) = _seed[i];
      final fade = t < .75 ? 1.0 : (1 - (t - .75) / .25);
      if (gentle) {
        // hati melayang naik pelan
        final x = size.width * a + math.sin((t * 4 + d) * math.pi) * 18;
        final y = size.height * (1.05 - t * (0.6 + b * .5));
        final tp = TextPainter(text: TextSpan(text: '💛', style: TextStyle(fontSize: 14 + c * 12, color: Colors.white.withValues(alpha: fade))), textDirection: TextDirection.ltr)..layout();
        canvas.save();
        canvas.translate(x, y);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        // konfeti jatuh
        final x = size.width * a + math.sin((t * 6 + d * 6)) * 24;
        final y = -20 + (size.height * .9) * (t * (0.7 + b * .6)) + c * -80;
        final p = Paint()..color = colors[i % colors.length].withValues(alpha: fade.clamp(0, 1).toDouble());
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t * 10 * (d - .5));
        if (i.isEven) {
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(2)), p);
        } else {
          canvas.drawCircle(Offset.zero, 3.5, p);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => o.t != t;
}
