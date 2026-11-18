import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/reminder.dart';
import '../../../providers/english_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../services/english_data.dart';
import '../../../services/voice_service.dart';
import '../../widgets/common.dart';
import 'zeo.dart';

const _green = Color(0xFF16B364);
const _red = Color(0xFFF04438);
const _blue = Color(0xFF1570EF);
const _amber = Color(0xFFF79009);
const _engReminderTitle = 'Belajar bahasa Inggris 5 menit';

void _say(String text) => VoiceService.instance.speakIn(text, 'en');

void openEnglish(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnglishScreen()));

void openEnglishCards(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashcardsScreen()));

/// Kartu kecil di beranda.
class EnglishHomeCard extends ConsumerWidget {
  const EnglishHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(engProvider).normalized(DateTime.now());
    final sub = p.dayXp >= engGoal
        ? 'Target hari ini tercapai 🎉'
        : p.xp > 0
            ? 'Lanjut: ${p.nextTopic.title} ${p.nextTopic.emoji}'
            : '5 menit sehari bersama Zeo';
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      onTap: () => openEnglish(context),
      child: Row(children: [
        const Zeo(size: 46, bob: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Belajar Inggris', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.muted)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: (p.dayXp / engGoal).clamp(0, 1).toDouble(), minHeight: 5, color: _amber, backgroundColor: context.card2),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🔥 ${p.streak}', translate: false, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.muted)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: context.iconBox, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.line)),
            child: Text(p.xp > 0 ? 'Lanjut' : 'Mulai', style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      ]),
    );
  }
}

/// Halaman utama Belajar Inggris: jalur topik.
class EnglishScreen extends ConsumerWidget {
  const EnglishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(engProvider).normalized(DateTime.now());
    final hasReminder = ref.watch(remindersProvider).any((r) => r.title == _engReminderTitle && r.repeat == RepeatType.daily);
    final done = p.stars.values.where((s) => s > 0).length;
    const offs = [0.0, 56.0, 84.0, 56.0, 0.0, -56.0, -84.0, -56.0];
    final bubble = p.dayXp >= engGoal
        ? 'Target hari ini tercapai! Mau latihan lagi?'
        : done > 0
            ? 'Ayo lanjut ke ${p.nextTopic.title}. 5 menit saja!'
            : 'Halo! Aku Zeo. Yuk belajar bahasa Inggris 5 menit sehari.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belajar Inggris'),
        actions: [
          _StatChip(text: '🔥 ${p.streak}', color: _red, tooltip: 'Runtutan hari'),
          const SizedBox(width: 6),
          _StatChip(text: '⭐ ${p.xp}', color: const Color(0xFFDC6803), tooltip: 'Total XP'),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Zeo(size: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.line),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(6)),
                ),
                child: Text(bubble, style: const TextStyle(fontSize: 14.5, height: 1.5)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Target harian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                Text('${p.dayXp}/$engGoal XP', translate: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.muted)),
              ]),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (p.dayXp / engGoal).clamp(0, 1).toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: v, minHeight: 10, color: _amber, backgroundColor: context.card2),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < engTopics.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Transform.translate(
                offset: Offset(offs[i % offs.length], 0),
                child: _PathNode(
                  topic: engTopics[i],
                  stars: p.stars[engTopics[i].id] ?? 0,
                  open: p.unlocked(i),
                  current: p.unlocked(i) && (p.stars[engTopics[i].id] ?? 0) == 0 && engTopics[i].id == p.nextTopic.id,
                  onTap: () {
                    if (!p.unlocked(i)) {
                      showToast(context, tr('Selesaikan "{}" dulu untuk membuka topik ini').replaceFirst('{}', engTopics[i - 1].title));
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(topic: engTopics[i])));
                  },
                ),
              ),
            ),
          const SizedBox(height: 8),
          _Tile(emoji: '🃏', bg: const Color(0xFFFEF0C7), title: 'Kartu kosakata', sub: 'Hafalkan kata dari topik yang sudah dibuka', onTap: () => openEnglishCards(context)),
          const SizedBox(height: 8),
          _Tile(
            emoji: '⏰',
            bg: const Color(0xFFE0F2FE),
            title: 'Ingatkan belajar tiap hari',
            sub: hasReminder ? 'Sudah aktif jam 19.00' : 'Pengingat jam 19.00 setiap hari',
            onTap: () async {
              if (hasReminder) {
                showToast(context, tr('Pengingat belajar sudah aktif'));
                return;
              }
              final now = DateTime.now();
              var at = DateTime(now.year, now.month, now.day, 19);
              if (at.isBefore(now)) at = addDays(at, 1);
              await ref.read(remindersProvider.notifier).upsert(Reminder.create(
                    title: _engReminderTitle,
                    scheduledAt: at,
                    repeat: RepeatType.daily,
                    category: ReminderCategory.edukasi,
                  ));
              if (context.mounted) showToast(context, tr('Pengingat dibuat: tiap hari jam 19.00'));
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.text, required this.color, required this.tooltip});
  final String text, tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tr(tooltip),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: context.line)),
          child: Text(text, translate: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.emoji, required this.bg, required this.title, required this.sub, required this.onTap});
  final String emoji, title, sub;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.isDark ? context.card2 : bg, borderRadius: BorderRadius.circular(12)),
            child: Text(emoji, translate: false, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(fontSize: 13, color: context.muted)),
            ]),
          ),
        ]),
      );
}

/// Satu lingkaran topik di jalur belajar.
class _PathNode extends StatefulWidget {
  const _PathNode({required this.topic, required this.stars, required this.open, required this.current, required this.onTap});
  final EngTopic topic;
  final int stars;
  final bool open, current;
  final VoidCallback onTap;

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.current) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _PathNode old) {
    super.didUpdateWidget(old);
    if (widget.current && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.current && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.open ? widget.topic.color : context.card2;
    final shade = widget.open ? Color.lerp(widget.topic.color, Colors.black, .3)! : context.line;
    return Column(children: [
      if (widget.current)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.line)),
          child: Text('Mulai', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: widget.topic.color)),
        ),
      Semantics(
        button: true,
        label: widget.topic.title,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final ring = widget.current ? 12 * _pulse.value : 0.0;
              return Container(
                width: 76,
                height: 72,
                margin: EdgeInsets.only(top: _down ? 5 : 0, bottom: _down ? 1 : 6),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: shade, offset: Offset(0, _down ? 1 : 6)),
                    if (widget.current) BoxShadow(color: widget.topic.color.withValues(alpha: .35 * (1 - _pulse.value)), spreadRadius: ring),
                  ],
                ),
                alignment: Alignment.center,
                child: child,
              );
            },
            child: Opacity(
              opacity: widget.open ? 1 : .6,
              child: Text(widget.open ? widget.topic.emoji : '🔒', translate: false, style: TextStyle(fontSize: widget.open ? 32 : 24)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(widget.topic.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.open ? context.ink : context.faint)),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var n = 1; n <= 3; n++) Icon(Icons.star_rounded, size: 15, color: n <= widget.stars ? const Color(0xFFFDB022) : context.line),
      ]),
    ]);
  }
}

/* ======================= PELAJARAN ======================= */

enum _K { mean, word, listen, match, build }

class _Q {
  _Q(this.k, {this.en = '', this.id = '', this.ans = '', this.opts = const [], this.pairs = const [], this.answer = const [], this.tiles = const []});
  final _K k;
  final String en, id, ans;
  final List<String> opts;
  final List<(String, String)> pairs;
  final List<String> answer;
  final List<String> tiles;
  List<String> left = [], right = [];
}

List<String> _tok(String s) => s.replaceAll(RegExp(r'[.,!?]'), '').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();

List<_Q> _build(EngTopic t, math.Random rnd) {
  List<T> sh<T>(List<T> a) => [...a]..shuffle(rnd);
  List<String> opts(String ans, List<String> pool) => sh([ans, ...sh(pool.where((x) => x != ans).toList()).take(3)]);
  final w = sh(t.words);
  final en = t.words.map((x) => x.$1).toList(), idn = t.words.map((x) => x.$2).toList();
  final q = <_Q>[
    for (final x in w.take(4)) _Q(_K.mean, en: x.$1, ans: x.$2, opts: opts(x.$2, idn)),
    for (final x in w.skip(4).take(2)) _Q(_K.word, id: x.$2, ans: x.$1, opts: opts(x.$1, en)),
    _Q(_K.listen, en: w[6].$1, ans: w[6].$1, opts: opts(w[6].$1, en)),
    _Q(_K.match, pairs: sh(t.words).take(4).toList()),
  ];
  for (final s in sh(t.sentences).take(2)) {
    final toks = _tok(s.$1), low = toks.map((x) => x.toLowerCase()).toSet();
    final extra = sh(en.where((x) => !x.contains(' ') && !low.contains(x)).toList()).take(2);
    q.add(_Q(_K.build, en: s.$1, id: s.$2, answer: toks, tiles: sh([...toks, ...extra])));
  }
  return [q[0], q[4], q[1], q[8], q[2], q[6], q[7], q[3], q[5], q[9]];
}

enum _Phase { ask, right, wrong, done, fail }

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.topic});
  final EngTopic topic;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> with SingleTickerProviderStateMixin {
  late List<_Q> _qs;
  int _n = 0, _hearts = 5, _wrong = 0, _pulse = 0;
  int? _sel;
  final List<int> _built = [];
  final Set<String> _matched = {};
  String? _pickL;
  String? _badR;
  _Phase _phase = _Phase.ask;
  ZeoMood _mood = ZeoMood.happy;
  String _praise = 'Benar!';
  int _stars = 0, _xp = 0, _streak = 0;
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  _Q get _q => _qs[_n];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  void _start() {
    _qs = _build(widget.topic, math.Random());
    _n = 0;
    _hearts = 5;
    _wrong = 0;
    _reset();
    _phase = _Phase.ask;
    _autoSay();
  }

  void _reset() {
    _sel = null;
    _built.clear();
    _matched.clear();
    _pickL = null;
    _badR = null;
  }

  void _autoSay() {
    final q = _qs[_n];
    if (q.k == _K.mean || q.k == _K.listen) Future.delayed(const Duration(milliseconds: 300), () => _say(q.en));
  }

  void _good() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    _mood = ZeoMood.happy;
    _pulse++;
    const p = ['Benar! 🎉', 'Hebat! ✨', 'Mantap! 💪', 'Tepat sekali! 🌟', 'Keren! 🙌'];
    _praise = p[math.Random().nextInt(p.length)];
  }

  void _miss() {
    HapticFeedback.heavyImpact();
    _wrong++;
    _hearts--;
    _mood = ZeoMood.sad;
    _pulse++;
    if (_hearts <= 0) _phase = _Phase.fail;
  }

  void _check() {
    final q = _q;
    final ok = q.k == _K.build
        ? _built.map((i) => q.tiles[i].toLowerCase()).join(' ') == q.answer.map((x) => x.toLowerCase()).join(' ')
        : q.opts[_sel!] == q.ans;
    setState(() {
      if (ok) {
        _phase = _Phase.right;
        _good();
        if (q.k == _K.build) _say(q.en);
      } else {
        _phase = _Phase.wrong;
        _miss();
      }
    });
  }

  Future<void> _next() async {
    if (_n + 1 >= _qs.length) {
      _stars = _wrong == 0 ? 3 : (_wrong <= 2 ? 2 : 1);
      _xp = 10 + (_wrong == 0 ? 5 : 0);
      final p = await ref.read(engProvider.notifier).finishLesson(widget.topic.id, stars: _stars, xp: _xp);
      if (!mounted) return;
      setState(() {
        _streak = p.streak;
        _phase = _Phase.done;
        _mood = ZeoMood.happy;
        _pulse++;
      });
      if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) _fx.forward(from: 0);
      return;
    }
    setState(() {
      _n++;
      _reset();
      _phase = _Phase.ask;
    });
    _autoSay();
  }

  Future<void> _quit() async {
    if (_phase == _Phase.done || _phase == _Phase.fail) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await confirmDialog(context, title: 'Keluar dari pelajaran?', message: 'Progres pelajaran ini tidak disimpan.', ok: 'Keluar', danger: true);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        body: Stack(children: [
          SafeArea(
            child: switch (_phase) {
              _Phase.done => _finish(),
              _Phase.fail => _fail(),
              _ => _lesson(),
            },
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _fx,
              builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_fx.value, [widget.topic.color, AppColors.primary, const Color(0xFFFDB022), _green])),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _lesson() {
    final q = _q;
    final canCheck = q.k == _K.build ? _built.isNotEmpty : (q.k == _K.match ? false : _sel != null);
    final fbColor = _phase == _Phase.right ? _green : _red;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
        child: Row(children: [
          IconButton(tooltip: tr('Keluar dari pelajaran'), onPressed: _quit, icon: const Icon(Icons.close_rounded)),
          const SizedBox(width: 4),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _n / _qs.length),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: v, minHeight: 12, color: _green, backgroundColor: context.card2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 1.6, end: 1.0).animate(a), child: c),
            child: Text('❤️ $_hearts', key: ValueKey(_hearts), translate: false, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _red)),
          ),
        ]),
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a), child: c),
          ),
          child: SingleChildScrollView(
            key: ValueKey(_n),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _question(q),
          ),
        ),
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          color: _phase == _Phase.ask ? context.bg : fbColor.withValues(alpha: context.isDark ? .18 : .12),
          border: Border(top: BorderSide(color: _phase == _Phase.ask ? context.line : Colors.transparent)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (_phase != _Phase.ask) ...[
            Row(children: [
              Zeo(size: 44, mood: _mood, pulse: _pulse, bob: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_phase == _Phase.right ? _praise : 'Belum tepat',
                      translate: _phase != _Phase.right,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color.lerp(fbColor, Colors.black, context.isDark ? 0 : .3))),
                  if (_phase == _Phase.wrong)
                    Text('${tr('Jawaban benar:')} ${q.k == _K.build ? q.en : q.ans}', translate: false, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _phase == _Phase.ask ? (canCheck ? _check : null) : _next,
              style: FilledButton.styleFrom(
                backgroundColor: _phase == _Phase.ask ? AppColors.primary : fbColor,
                disabledBackgroundColor: context.card2,
                disabledForegroundColor: context.faint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_phase == _Phase.ask ? (q.k == _K.match ? 'Cocokkan semua pasangan' : 'Periksa') : 'Lanjut'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _title(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(s, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.2)),
      );

  Widget _question(_Q q) {
    switch (q.k) {
      case _K.mean:
      case _K.word:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title(q.k == _K.mean ? 'Apa artinya?' : 'Pilih kata bahasa Inggrisnya'),
          Row(children: [
            if (q.k == _K.mean) ...[_SayButton(text: q.en), const SizedBox(width: 12)],
            Expanded(
              child: Text(q.k == _K.mean ? q.en : q.id,
                  translate: false, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.4)),
            ),
          ]),
          const SizedBox(height: 22),
          ..._options(q),
        ]);
      case _K.listen:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Dengarkan, lalu pilih kata yang kamu dengar'),
          Center(child: _BigSay(text: q.en)),
          const SizedBox(height: 24),
          ..._options(q),
        ]);
      case _K.build:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Terjemahkan kalimat ini'),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Zeo(size: 56, mood: _mood, pulse: _pulse),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.line),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
                ),
                child: Text(q.id, translate: false, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45)),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: context.line, width: 2))),
            child: _built.isEmpty
                ? Padding(padding: const EdgeInsets.only(top: 12), child: Text('Ketuk kata di bawah', style: TextStyle(color: context.faint, fontSize: 14)))
                : Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final i in _built)
                      _WordTile(
                        label: q.tiles[i],
                        onTap: _phase == _Phase.ask ? () => setState(() => _built.remove(i)) : null,
                      ),
                  ]),
          ),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < q.tiles.length; i++)
              _WordTile(
                label: q.tiles[i],
                used: _built.contains(i),
                onTap: _phase == _Phase.ask && !_built.contains(i)
                    ? () {
                        _say(q.tiles[i]);
                        setState(() => _built.add(i));
                      }
                    : null,
              ),
          ]),
        ]);
      case _K.match:
        if (q.left.isEmpty) {
          q.left = q.pairs.map((p) => p.$1).toList()..shuffle();
          q.right = q.pairs.map((p) => p.$2).toList()..shuffle();
        }
        String enOf(String idw) => q.pairs.firstWhere((p) => p.$2 == idw).$1;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Cocokkan pasangannya'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(children: [
                for (final w in q.left)
                  _MatchBtn(
                    label: w,
                    state: _matched.contains(w) ? _MS.ok : (_pickL == w ? _MS.sel : _MS.idle),
                    onTap: () {
                      if (_matched.contains(w) || _phase != _Phase.ask) return;
                      _say(w);
                      setState(() => _pickL = w);
                    },
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(children: [
                for (final w in q.right)
                  _MatchBtn(
                    label: w,
                    state: _matched.contains(enOf(w)) ? _MS.ok : (_badR == w ? _MS.bad : _MS.idle),
                    onTap: () {
                      if (_phase != _Phase.ask || _matched.contains(enOf(w))) return;
                      if (_pickL == null) {
                        showToast(context, tr('Pilih kata bahasa Inggris di kiri dulu'));
                        return;
                      }
                      setState(() {
                        if (enOf(w) == _pickL) {
                          _matched.add(_pickL!);
                          _pickL = null;
                          _badR = null;
                          HapticFeedback.selectionClick();
                          if (_matched.length == q.pairs.length) {
                            _phase = _Phase.right;
                            _good();
                          }
                        } else {
                          _badR = w;
                          _miss();
                        }
                      });
                    },
                  ),
              ]),
            ),
          ]),
        ]);
    }
  }

  List<Widget> _options(_Q q) => [
        for (var i = 0; i < q.opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptBtn(
              label: q.opts[i],
              state: _phase == _Phase.ask
                  ? (_sel == i ? _MS.sel : _MS.idle)
                  : (q.opts[i] == q.ans ? _MS.ok : (_sel == i ? _MS.bad : _MS.idle)),
              onTap: _phase == _Phase.ask
                  ? () {
                      if (q.k != _K.mean) _say(q.opts[i]);
                      setState(() => _sel = i);
                    }
                  : null,
            ),
          ),
      ];

  Widget _finish() => ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(child: Zeo(size: 120, pulse: _pulse)),
          const SizedBox(height: 8),
          const Text('Pelajaran selesai!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${widget.topic.title} ${widget.topic.emoji}', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.muted)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var n = 1; n <= 3; n++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 500 + n * 220),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v.clamp(0, 1.4).toDouble(), child: child),
                child: Icon(Icons.star_rounded, size: 52, color: n <= _stars ? const Color(0xFFFDB022) : context.line),
              ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _Stat(label: 'XP didapat', value: '+$_xp', color: const Color(0xFFFDB022)),
            const SizedBox(width: 8),
            _Stat(label: 'Ketepatan', value: '${(((_qs.length - math.min(_qs.length, _wrong)) / _qs.length) * 100).round()}%', color: AppColors.success),
            const SizedBox(width: 8),
            _Stat(label: 'Runtutan', value: '🔥 $_streak', color: _red),
          ]),
          const SizedBox(height: 24),
          GradientButton(label: 'Lanjut', onPressed: () => Navigator.of(context).pop()),
          const SizedBox(height: 8),
          SoftButton(label: 'Ulangi topik ini', onPressed: () => setState(_start)),
        ],
      );

  Widget _fail() => ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        children: [
          Center(child: Zeo(size: 120, mood: ZeoMood.sad, pulse: _pulse)),
          const SizedBox(height: 8),
          const Text('Hatimu habis', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Tidak apa-apa, salah itu bagian dari belajar. Coba lagi, pasti lebih lancar.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.muted, height: 1.5)),
          const SizedBox(height: 24),
          GradientButton(label: 'Coba lagi', onPressed: () => setState(_start)),
          const SizedBox(height: 8),
          SoftButton(label: 'Kembali ke daftar topik', onPressed: () => Navigator.of(context).pop()),
        ],
      );
}

enum _MS { idle, sel, ok, bad }

Color _msColor(BuildContext context, _MS s) => switch (s) {
      _MS.sel => _blue,
      _MS.ok => _green,
      _MS.bad => _red,
      _MS.idle => context.line,
    };

/// Tombol pilihan dengan efek "tombol timbul".
class _OptBtn extends StatelessWidget {
  const _OptBtn({required this.label, required this.state, this.onTap});
  final String label;
  final _MS state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = _msColor(context, state);
    final fill = state == _MS.idle ? context.card : Color.alphaBlend(c.withValues(alpha: .1), context.card);
    final fg = state == _MS.idle ? context.ink : (context.isDark ? Color.lerp(c, Colors.white, .3)! : Color.lerp(c, Colors.black, .25)!);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c, width: 2),
        boxShadow: [BoxShadow(color: c, offset: const Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, translate: false, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchBtn extends StatelessWidget {
  const _MatchBtn({required this.label, required this.state, required this.onTap});
  final String label;
  final _MS state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _msColor(context, state);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: state == _MS.ok ? .45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c, width: 2),
            boxShadow: [BoxShadow(color: c, offset: const Offset(0, 3))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54, minWidth: double.infinity),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Text(label,
                        translate: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: state == _MS.idle ? context.ink : c)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.label, this.used = false, this.onTap});
  final String label;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: used ? context.card2 : context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: used ? context.card2 : context.line, width: 2),
        boxShadow: used ? null : [BoxShadow(color: context.line, offset: const Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(label, translate: false, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: used ? Colors.transparent : context.ink)),
          ),
        ),
      ),
    );
  }
}

class _SayButton extends StatelessWidget {
  const _SayButton({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Material(
        color: context.isDark ? const Color(0xFF0B3A53) : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _say(text),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Semantics(label: tr('Dengarkan'), child: const Icon(Icons.volume_up_rounded, color: _blue)),
          ),
        ),
      );
}

class _BigSay extends StatelessWidget {
  const _BigSay({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0xFF0E4FAA), offset: Offset(0, 6))]),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _say(text),
            child: const SizedBox(
              width: 120,
              height: 120,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.volume_up_rounded, color: Colors.white, size: 48),
                SizedBox(height: 4),
                Text('Putar lagi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: .08), context.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(children: [
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(value, translate: false, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;
  static final _seed = [
    for (var i = 0; i < 60; i++)
      (() {
        final r = math.Random(i * 7 + 3);
        return (r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble());
      })(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (var i = 0; i < _seed.length; i++) {
      final (a, b, c, d) = _seed[i];
      final fade = t < .75 ? 1.0 : (1 - (t - .75) / .25);
      final x = size.width * a + math.sin(t * 6 + d * 6) * 24;
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

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => o.t != t;
}

/* ======================= KARTU KOSAKATA ======================= */

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  late List<(String, String, EngTopic)> _list;
  int _n = 0, _known = 0;
  bool _flip = false;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final p = ref.read(engProvider);
    final words = <(String, String, EngTopic)>[
      for (var i = 0; i < engTopics.length; i++)
        if (p.unlocked(i))
          for (final w in engTopics[i].words) (w.$1, w.$2, engTopics[i]),
    ]..shuffle();
    _list = words.take(15).toList();
    _n = 0;
    _known = 0;
    _flip = false;
    if (_list.isNotEmpty) Future.delayed(const Duration(milliseconds: 300), () => _say(_list.first.$1));
  }

  void _answer(bool known) {
    final w = _list[_n];
    setState(() {
      if (known) {
        _known++;
        HapticFeedback.lightImpact();
      } else if (_list.length < 25) {
        _list.add(w);
      }
      _n++;
      _flip = false;
    });
    if (_n < _list.length) Future.delayed(const Duration(milliseconds: 200), () => _say(_list[_n].$1));
  }

  @override
  Widget build(BuildContext context) {
    final finished = _n >= _list.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Kartu kosakata')),
      body: SafeArea(
        child: finished
            ? ListView(padding: const EdgeInsets.all(24), children: [
                const Center(child: Zeo(size: 120, pulse: 1)),
                const SizedBox(height: 8),
                const Text('Sesi kartu selesai', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Kamu sudah hafal $_known dari ${_list.length} kata.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.muted)),
                const SizedBox(height: 24),
                GradientButton(label: 'Ulangi dengan kata lain', onPressed: () => setState(_deal)),
                const SizedBox(height: 8),
                SoftButton(label: 'Kembali', onPressed: () => Navigator.of(context).pop()),
              ])
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(value: _n / _list.length, minHeight: 12, color: _green, backgroundColor: context.card2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${_n + 1}/${_list.length}', translate: false, style: const TextStyle(fontWeight: FontWeight.w700, color: _red)),
                  ]),
                  const SizedBox(height: 20),
                  Expanded(child: _card(_list[_n])),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: () => _answer(false),
                          style: FilledButton.styleFrom(backgroundColor: _red.withValues(alpha: .12), foregroundColor: context.isDark ? const Color(0xFFFDA29B) : const Color(0xFFB42318)),
                          child: const Text('Belum hafal'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(onPressed: () => _answer(true), style: FilledButton.styleFrom(backgroundColor: _green), child: const Text('Sudah hafal')),
                      ),
                    ),
                  ]),
                ]),
              ),
      ),
    );
  }

  Widget _card((String, String, EngTopic) w) {
    final c = w.$3.color;
    return GestureDetector(
      onTap: () => setState(() => _flip = !_flip),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _flip ? 1 : 0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        builder: (context, v, _) {
          final back = v > .5;
          final face = back
              ? Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c, width: 2),
                    boxShadow: [BoxShadow(color: Color.alphaBlend(c.withValues(alpha: .4), context.line), offset: const Offset(0, 8))],
                  ),
                  child: _cardText('Artinya', w.$2, w.$1, context.ink),
                )
              : Container(
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Color.lerp(c, Colors.black, .3)!, offset: const Offset(0, 8))]),
                  child: _cardText('${w.$3.emoji} ${w.$3.title}', w.$1, tr('Ketuk untuk melihat arti'), Colors.white),
                );
          return Stack(children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .001)
                  ..rotateY(math.pi * v + (back ? math.pi : 0)),
                child: face,
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _say(w.$1),
                  child: SizedBox(width: 48, height: 48, child: Semantics(label: tr('Dengarkan'), child: const Icon(Icons.volume_up_rounded, color: _blue))),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _cardText(String top, String big, String bottom, Color fg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(top, translate: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg.withValues(alpha: .85))),
            const SizedBox(height: 10),
            Text(big, translate: false, textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: fg, letterSpacing: -.4)),
            const SizedBox(height: 10),
            Text(bottom, translate: false, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: .8))),
          ]),
        ),
      );
}
