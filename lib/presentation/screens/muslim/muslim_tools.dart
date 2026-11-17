import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/muslim_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/islam_logic.dart';
import '../../widgets/common.dart';
import 'muslim_screen.dart';

TextStyle arabicStyle(double size, {Color? color}) => GoogleFonts.amiri(fontSize: size, height: 2.0, color: color, fontWeight: FontWeight.w600);

/// ---------- Arah kiblat ----------
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});
  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<MagnetometerEvent>? _mag;
  List<double>? _g, _m;
  double? _heading; // derajat dari utara magnetik
  bool _noSensor = false;
  bool _wasAligned = false;
  Timer? _check;

  @override
  void initState() {
    super.initState();
    try {
      _acc = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _g = _lp(_g, [e.x, e.y, e.z]);
        _update();
      }, onError: (_) => setState(() => _noSensor = true));
      _mag = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _m = _lp(_m, [e.x, e.y, e.z]);
        _update();
      }, onError: (_) => setState(() => _noSensor = true));
    } catch (_) {
      _noSensor = true;
    }
    _check = Timer(const Duration(seconds: 3), () {
      if (mounted && _heading == null) setState(() => _noSensor = true);
    });
  }

  List<double> _lp(List<double>? prev, List<double> v) => prev == null ? v : [for (var i = 0; i < 3; i++) prev[i] + .15 * (v[i] - prev[i])];

  void _update() {
    final g = _g, m = _m;
    if (g == null || m == null) return;
    // rumus SensorManager.getRotationMatrix → azimuth
    final ax = g[0], ay = g[1], az = g[2], ex = m[0], ey = m[1], ez = m[2];
    var hx = ey * az - ez * ay, hy = ez * ax - ex * az, hz = ex * ay - ey * ax;
    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < .1) return;
    hx /= normH;
    hy /= normH;
    hz /= normH;
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    final nax = ax / normA, naz = az / normA;
    final my = naz * hx - nax * hz;
    final az2 = math.atan2(hy, my) * 180 / math.pi;
    final h = (az2 + 360) % 360;
    if (!mounted) return;
    setState(() {
      _heading = h;
      _noSensor = false;
    });
  }

  @override
  void dispose() {
    _acc?.cancel();
    _mag?.cancel();
    _check?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(muslimProvider);
    final qibla = PrayerCalc.qibla(s.lat, s.lng);
    final dist = PrayerCalc.distanceKm(s.lat, s.lng, 21.4225, 39.8262);
    final h = _heading;
    final diff = h == null ? null : ((qibla - h + 540) % 360) - 180; // −180..180
    final aligned = diff != null && diff.abs() < 4;
    if (aligned && !_wasAligned) HapticFeedback.heavyImpact();
    _wasAligned = aligned;
    final size = MediaQuery.of(context).size.width * .8;
    return Scaffold(
      appBar: AppBar(title: const Text('Arah kiblat'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        Text('📍 ${s.city} · Ka\'bah ${dist.round()} km', textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          h == null
              ? (_noSensor ? 'Kiblat ${qibla.toStringAsFixed(0)}° dari utara' : 'Menyiapkan kompas…')
              : aligned
                  ? '✅ Sudah menghadap kiblat'
                  : (diff! > 0 ? 'Putar ke kanan ${diff.abs().round()}°' : 'Putar ke kiri ${diff.abs().round()}°'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: aligned ? kGreen : context.ink),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedRotation(
                turns: -(h ?? 0) / 360,
                duration: const Duration(milliseconds: 250),
                child: CustomPaint(size: Size(size, size), painter: _DialPainter(qibla: qibla, ink: context.ink, line: context.line, aligned: aligned)),
              ),
              // penanda arah HP (atas)
              Positioned(top: 0, child: Icon(Icons.arrow_drop_down_rounded, size: 48, color: aligned ? kGreen : kGold)),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, color: aligned ? kGreen : context.card, boxShadow: context.softShadow),
                alignment: Alignment.center,
                child: const Text('🕋', style: TextStyle(fontSize: 34)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Arah kiblat: ${qibla.toStringAsFixed(1)}° dari utara', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              _noSensor
                  ? 'HP ini tidak mengirim data kompas. Gunakan angka derajat di atas dengan kompas lain, atau patokan: kiblat dari Indonesia kira-kira ke arah barat laut.'
                  : 'Letakkan HP mendatar, jauhkan dari benda logam/magnet. Kalau arah terasa melenceng, kalibrasi dengan menggerakkan HP membentuk angka 8 beberapa kali.',
              style: TextStyle(color: context.muted, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.qibla, required this.ink, required this.line, required this.aligned});
  final double qibla;
  final Color ink, line;
  final bool aligned;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = kGreen.withValues(alpha: .06));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = line);
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final long = i % 18 == 0;
      final p1 = c + Offset(math.sin(a), -math.cos(a)) * r;
      final p2 = c + Offset(math.sin(a), -math.cos(a)) * (r - (long ? 16 : 8));
      canvas.drawLine(p1, p2, Paint()
        ..color = long ? ink : line
        ..strokeWidth = long ? 3 : 1.5);
    }
    const labels = {'U': 0.0, 'T': 90.0, 'S': 180.0, 'B': 270.0};
    labels.forEach((t, deg) {
      final a = deg * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(color: t == 'U' ? const Color(0xFFE11D48) : ink, fontWeight: FontWeight.w800, fontSize: 18)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(math.sin(a), -math.cos(a)) * (r - 34) - Offset(tp.width / 2, tp.height / 2));
    });
    // jarum kiblat
    final qa = qibla * math.pi / 180;
    final dir = Offset(math.sin(qa), -math.cos(qa));
    final paint = Paint()
      ..color = aligned ? kGreen : kGold
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + dir * (r - 50), paint);
    final tp = TextPainter(text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 26)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, c + dir * (r - 30) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DialPainter o) => o.qibla != qibla || o.aligned != aligned || o.ink != ink;
}

/// ---------- Al-Qur'an (alquran.cloud, disimpan setelah dibuka) ----------
const _api = 'https://api.alquran.cloud/v1';

Future<dynamic> _cachedJson(WidgetRef ref, String key, String url) async {
  final repo = ref.read(settingsRepositoryProvider);
  final cached = repo.get<String>(key, '');
  if (cached.isNotEmpty) return jsonDecode(cached);
  final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  final body = utf8.decode(res.bodyBytes);
  final data = jsonDecode(body)['data'];
  await repo.set(key, jsonEncode(data));
  return data;
}

class QuranListScreen extends ConsumerStatefulWidget {
  const QuranListScreen({super.key});
  @override
  ConsumerState<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends ConsumerState<QuranListScreen> {
  List<Map>? _list;
  String? _err;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final d = await _cachedJson(ref, 'quran_list', '$_api/surah');
      if (mounted) setState(() => _list = (d as List).whereType<Map>().toList());
    } catch (e) {
      if (mounted) setState(() => _err = 'Daftar surah belum bisa dimuat. Pastikan internet aktif, lalu coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(muslimProvider);
    final list = (_list ?? const <Map>[])
        .where((m) => _q.isEmpty || '${m['englishName']} ${m['number']}'.toLowerCase().replaceAll("'", '').replaceAll('-', ' ').contains(_q.toLowerCase().replaceAll('-', ' ')))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Al-Qur'an"), centerTitle: false),
      body: _err != null
          ? EmptyState(title: 'Belum tersambung', subtitle: _err!, icon: Icons.wifi_off_rounded, actionLabel: 'Coba lagi', onAction: _load)
          : _list == null
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  if (s.lastSurah != null && _list!.length >= s.lastSurah!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(_list![s.lastSurah! - 1], ayah: s.lastAyah),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(gradient: kMuslimGradient),
                            child: Row(children: [
                              const Text('🔖', style: TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Lanjutkan membaca', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                  Text('${_list![s.lastSurah! - 1]['englishName']} · ayat ${s.lastAyah ?? 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                                ]),
                              ),
                              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Cari surah (mis. Yasin, 36)…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                  const SizedBox(height: 10),
                  for (final m in list)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: kGreen.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text('${m['number']}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800)),
                      ),
                      title: Text('${m['englishName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${m['revelationType'] == 'Meccan' ? 'Makkiyah' : 'Madaniyah'} · ${m['numberOfAyahs']} ayat'),
                      trailing: Text('${m['name']}', style: arabicStyle(20, color: kGreen)),
                      onTap: () => _open(m),
                    ),
                ]),
    );
  }

  void _open(Map m, {int? ayah}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahScreen(meta: m, startAyah: ayah)));
}

class SurahScreen extends ConsumerStatefulWidget {
  const SurahScreen({super.key, required this.meta, this.startAyah});
  final Map meta;
  final int? startAyah;
  @override
  ConsumerState<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends ConsumerState<SurahScreen> {
  List<({int n, String ar, String lat, String id})>? _ayat;
  String? _err;
  bool _latin = true;
  final _scroll = ScrollController();

  int get _no => (widget.meta['number'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final d = await _cachedJson(ref, 'quran_$_no', '$_api/surah/$_no/editions/quran-uthmani,en.transliteration,id.indonesian') as List;
      List ay(int i) => (d[i] as Map)['ayahs'] as List;
      final ar = ay(0), la = ay(1), id = ay(2);
      final out = <({int n, String ar, String lat, String id})>[];
      for (var i = 0; i < ar.length; i++) {
        var text = '${ar[i]['text']}';
        // bismillah sudah ditampilkan di kepala surah
        if (i == 0 && _no != 1 && _no != 9 && text.startsWith('بِسْمِ')) {
          final parts = text.split(' ');
          if (parts.length > 4) text = parts.sublist(4).join(' ');
        }
        out.add((n: (ar[i]['numberInSurah'] as num).toInt(), ar: text, lat: '${la[i]['text']}', id: '${id[i]['text']}'));
      }
      if (!mounted) return;
      setState(() => _ayat = out);
      final start = widget.startAyah;
      if (start != null && start > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(math.min(_scroll.position.maxScrollExtent, (start - 1) * 240.0));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = 'Surah belum bisa dimuat. Pastikan internet aktif, lalu coba lagi. Setelah dibuka sekali, surah bisa dibaca offline.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    final last = ref.watch(muslimProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${m['englishName']}'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: tr(_latin ? 'Sembunyikan latin' : 'Tampilkan latin'),
            onPressed: () => setState(() => _latin = !_latin),
            icon: Icon(_latin ? Icons.text_fields_rounded : Icons.text_format_rounded),
          ),
        ],
      ),
      body: _err != null
          ? EmptyState(title: 'Belum tersambung', subtitle: _err!, icon: Icons.wifi_off_rounded, actionLabel: 'Coba lagi', onAction: _load)
          : _ayat == null
              ? const Center(child: CircularProgressIndicator(color: kGreen))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: _ayat!.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(gradient: kMuslimGradient, borderRadius: BorderRadius.circular(22)),
                        child: Column(children: [
                          Text('${m['name']}', style: arabicStyle(30, color: Colors.white)),
                          Text('${m['englishName']} · ${m['numberOfAyahs']} ayat · ${m['revelationType'] == 'Meccan' ? 'Makkiyah' : 'Madaniyah'}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          if (_no != 1 && _no != 9) ...[
                            const SizedBox(height: 8),
                            Text('بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ', style: arabicStyle(24, color: Colors.white)),
                          ],
                        ]),
                      );
                    }
                    final a = _ayat![i - 1];
                    final marked = last.lastSurah == _no && last.lastAyah == a.n;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.line))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: kGreen.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
                            child: Text('${_no}:${a.n}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('Tandai terakhir dibaca'),
                            onPressed: () {
                              ref.read(muslimProvider.notifier).setLastRead(_no, a.n);
                              showToast(context, 'Ditandai: ${m['englishName']} ayat ${a.n} 🔖');
                            },
                            icon: Icon(marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: kGreen),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('Salin'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: '${a.ar}\n\n${a.id}\n(QS ${m['englishName']}: ${a.n})'));
                              showToast(context, 'Ayat disalin');
                            },
                            icon: Icon(Icons.copy_rounded, size: 20, color: context.muted),
                          ),
                        ]),
                        Text(a.ar, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: arabicStyle(26, color: context.ink)),
                        if (_latin) ...[
                          const SizedBox(height: 4),
                          Text(a.lat, style: const TextStyle(color: kGreen, fontStyle: FontStyle.italic, height: 1.4)),
                        ],
                        const SizedBox(height: 6),
                        Text(a.id, style: TextStyle(color: context.ink, height: 1.5)),
                      ]),
                    );
                  },
                ),
    );
  }
}

/// ---------- Doa harian ----------
class DoaScreen extends StatefulWidget {
  const DoaScreen({super.key, this.focus});
  final String? focus;
  @override
  State<DoaScreen> createState() => _DoaScreenState();
}

class _DoaScreenState extends State<DoaScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = doaHarian.where((d) => _q.isEmpty || '${d.judul} ${d.arti}'.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Doa harian'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Cari doa (mis. tidur, makan)…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 12),
        for (final d in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: DoaCard(d, initiallyExpanded: d.judul == widget.focus)),
      ]),
    );
  }
}

class DoaCard extends StatelessWidget {
  const DoaCard(this.d, {super.key, this.initiallyExpanded = false});
  final Doa d;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Text(d.emoji, style: const TextStyle(fontSize: 26)),
          title: Text('Doa ${d.judul.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Text(d.arab, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: arabicStyle(24, color: context.ink)),
            const SizedBox(height: 6),
            Text(d.latin, style: const TextStyle(color: kGreen, fontStyle: FontStyle.italic, height: 1.4)),
            const SizedBox(height: 6),
            Text('"${d.arti}"', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(d.sumber, style: TextStyle(fontSize: 12, color: context.faint))),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'Doa ${d.judul.toLowerCase()}\n${d.arab}\n${d.latin}\nArtinya: ${d.arti}'));
                  showToast(context, 'Doa disalin');
                },
                icon: Icon(Icons.copy_rounded, size: 20, color: context.muted),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// ---------- Asmaul Husna ----------
class AsmaScreen extends StatefulWidget {
  const AsmaScreen({super.key});
  @override
  State<AsmaScreen> createState() => _AsmaScreenState();
}

class _AsmaScreenState extends State<AsmaScreen> {
  String _q = '';
  static const _colors = [Color(0xFF8B5CF6), Color(0xFF059669), Color(0xFF0EA5E9), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF6366F1)];
  @override
  Widget build(BuildContext context) {
    final idx = [
      for (var i = 0; i < asmaulHusna.length; i++)
        if (_q.isEmpty || '${asmaulHusna[i].latin} ${asmaulHusna[i].arti} ${i + 1}'.toLowerCase().contains(_q.toLowerCase())) i,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Asmaul Husna'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Cari nama atau arti…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: idx.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95),
          itemBuilder: (_, k) {
            final i = idx[k];
            final a = asmaulHusna[i];
            final c = _colors[i % _colors.length];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.withValues(alpha: .14), c.withValues(alpha: .04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.withValues(alpha: .25)),
              ),
              child: Column(children: [
                Align(alignment: Alignment.topLeft, child: Text('${i + 1}', style: TextStyle(color: c, fontWeight: FontWeight.w800))),
                Expanded(child: Center(child: FittedBox(child: Text(a.arab, style: arabicStyle(28, color: c))))),
                Text(a.latin, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(a.arti, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted)),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

/// ---------- Tasbih digital ----------
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});
  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> {
  int _sel = 0;
  int _count = 0;
  bool _seq = true; // urutan 33-33-34 setelah sholat
  int _session = 0;

  Dzikir get _d => dzikirList[_sel];

  void _tap() {
    HapticFeedback.lightImpact();
    setState(() {
      _count++;
      _session++;
    });
    final target = _d.target;
    if (target > 0 && _count >= target) {
      HapticFeedback.heavyImpact();
      if (_seq && _sel < 2) {
        showToast(context, '${_d.nama} ${target}x selesai ✨ Lanjut ${dzikirList[_sel + 1].nama}');
        setState(() {
          _sel++;
          _count = 0;
        });
      } else {
        showToast(context, 'MasyaAllah, ${_d.nama} ${target}x selesai 🤲');
        setState(() => _count = 0);
      }
    }
  }

  @override
  void dispose() {
    if (_session > 0) ref.read(muslimProvider.notifier).addTasbih(_session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(muslimProvider).tasbih + _session;
    final d = _d;
    final progress = d.target == 0 ? 0.0 : _count / d.target;
    return Scaffold(
      appBar: AppBar(title: const Text('Tasbih'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: Column(children: [
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (var i = 0; i < dzikirList.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(dzikirList[i].target > 0 ? '${dzikirList[i].nama} ${dzikirList[i].target}x' : dzikirList[i].nama),
                    selected: _sel == i,
                    onSelected: (_) => setState(() {
                      _sel = i;
                      _count = 0;
                    }),
                  ),
                ),
            ]),
          ),
          SwitchListTile(
            dense: true,
            value: _seq,
            activeTrackColor: kGreen,
            onChanged: (v) => setState(() => _seq = v),
            title: const Text('Dzikir setelah sholat (33·33·34 berurutan)', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (d.arab.isNotEmpty) Text(d.arab, style: arabicStyle(30, color: kGreen)),
          Text(d.arti, style: TextStyle(color: context.muted)),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _tap,
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(value: progress.clamp(0, 1).toDouble(), strokeWidth: 12, color: kGold, backgroundColor: kGreen.withValues(alpha: .1), strokeCap: StrokeCap.round),
                    ),
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: kMuslimGradient,
                        boxShadow: [BoxShadow(color: kGreen.withValues(alpha: .4), blurRadius: 30, spreadRadius: -6)],
                      ),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$_count', style: accentFont(size: 64, color: Colors.white)),
                        Text(d.target > 0 ? 'dari ${d.target}' : 'ketuk untuk menghitung', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Text('Total semua dzikir: $total', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: SoftButton(label: 'Ulang hitungan', icon: Icons.restart_alt_rounded, onPressed: () => setState(() => _count = 0)),
          ),
        ]),
      ),
    );
  }
}
