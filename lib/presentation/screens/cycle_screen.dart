import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/cycle_provider.dart';
import '../widgets/common.dart';

const kHaid = Color(0xFFE11D74);
const kSubur = Color(0xFF0EA5A4);
const kHaidGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF43F8E), Color(0xFFBE185D)]);

Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 2),
    lastDate: now,
    helpText: 'Hari pertama haid',
  );
}

/// Tombol "Haid mulai"/"Haid selesai" — dipakai di kartu beranda & layar siklus.
Future<void> togglePeriod(BuildContext context, WidgetRef ref) async {
  final n = ref.read(cycleProvider.notifier);
  final info = n.info;
  if (info != null && info.ongoing) {
    await n.logEnd();
    if (context.mounted) showToast(context, 'Haid selesai dicatat 🌿');
  } else {
    await n.logStart();
    if (context.mounted) showToast(context, 'Hari pertama haid dicatat 🌸');
  }
}

/// Kartu siklus di beranda (hanya tampil bila fitur aktif).
class CycleHomeCard extends ConsumerWidget {
  const CycleHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(cycleProvider);
    final info = CycleInfo.from(c);
    if (!c.enabled || info == null) return const SizedBox.shrink();
    final st = info.status();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: BoxDecoration(
          gradient: kHaidGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: kHaid.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -14)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CycleScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(st.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => togglePeriod(context, ref),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kHaid,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(info.ongoing ? 'Haid selesai' : 'Haid mulai', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class CycleScreen extends ConsumerWidget {
  const CycleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(cycleProvider);
    final info = CycleInfo.from(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat haid'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: info == null || !c.enabled ? const _Setup() : _Overview(info: info, data: c),
      ),
    );
  }
}

class _Setup extends ConsumerStatefulWidget {
  const _Setup();
  @override
  ConsumerState<_Setup> createState() => _SetupState();
}

class _SetupState extends ConsumerState<_Setup> {
  DateTime? _last;
  double _cycle = 28;
  double _period = 5;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: kHaidGradient, borderRadius: BorderRadius.circular(22)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.water_drop_rounded, color: Colors.white, size: 34),
          SizedBox(height: 10),
          Text('Pantau siklusmu', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('IngetZeon memperkirakan haid berikutnya & masa subur, lalu mengingatkanmu 2 hari sebelumnya.',
              style: TextStyle(color: Colors.white, height: 1.4)),
        ]),
      ),
      const SectionHeader('Hari pertama haid terakhir'),
      SoftCard(
        onTap: () async {
          final d = await _pickDate(context, initial: _last);
          if (d != null) setState(() => _last = d);
        },
        child: Row(children: [
          const Icon(Icons.event_rounded, color: kHaid),
          const SizedBox(width: 12),
          Expanded(child: Text(_last == null ? 'Pilih tanggal' : fmtDateLong(_last!), style: TextStyle(fontWeight: FontWeight.w600, color: context.ink))),
          Icon(Icons.chevron_right_rounded, color: context.faint),
        ]),
      ),
      const SectionHeader('Panjang siklus'),
      _SliderCard(value: _cycle, min: 21, max: 40, unit: 'hari', note: 'Rata-rata 28 hari. Tidak tahu? Biarkan saja.', onChanged: (v) => setState(() => _cycle = v)),
      const SectionHeader('Lama haid'),
      _SliderCard(value: _period, min: 2, max: 10, unit: 'hari', note: 'Biasanya 3–7 hari.', onChanged: (v) => setState(() => _period = v)),
      const SizedBox(height: 24),
      GradientButton(
        label: 'Mulai pantau',
        icon: Icons.check_rounded,
        onPressed: _last == null
            ? null
            : () => ref.read(cycleProvider.notifier).setup(_last!, _cycle.round(), _period.round()),
      ),
      const SizedBox(height: 16),
      const _Disclaimer(),
    ]);
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({required this.value, required this.min, required this.max, required this.unit, required this.onChanged, this.note});
  final double value, min, max;
  final String unit;
  final String? note;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${value.round()} $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kHaid)),
        Slider(value: value, min: min, max: max, divisions: (max - min).round(), activeColor: kHaid, onChanged: onChanged),
        if (note != null) Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(note!, style: TextStyle(fontSize: 12, color: context.muted))),
      ]),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.info, required this.data});
  final CycleInfo info;
  final CycleData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(cycleProvider.notifier);
    final st = info.status();
    final now = DateTime.now();
    final daysToNext = daysBetween(now, info.next);
    final history = info.periods.reversed.toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
      Center(
        child: SizedBox(
          width: 210,
          height: 210,
          child: CustomPaint(
            painter: _RingPainter(
              progress: (info.day / info.cycleLen).clamp(0, 1).toDouble(),
              periodFrac: info.periodLen / info.cycleLen,
              fertileFrom: (info.cycleLen - 19) / info.cycleLen,
              fertileTo: (info.cycleLen - 13) / info.cycleLen,
              track: context.line,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('HARI KE', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: context.muted)),
                Text('${info.day}', style: accentFont(size: 52, color: kHaid)),
                Text('dari ±${info.cycleLen} hari', style: TextStyle(fontSize: 12, color: context.muted)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Center(child: Text(st.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.ink))),
      const SizedBox(height: 2),
      Center(child: Text(st.sub, textAlign: TextAlign.center, style: TextStyle(color: context.muted))),
      const SizedBox(height: 16),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: () => togglePeriod(context, ref),
          style: FilledButton.styleFrom(backgroundColor: kHaid, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: Icon(info.ongoing ? Icons.check_circle_outline_rounded : Icons.water_drop_rounded),
          label: Text(info.ongoing ? 'Haid selesai hari ini' : 'Haid mulai hari ini', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      const SectionHeader('Perkiraan'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: [
          _Pred(icon: Icons.water_drop_rounded, color: kHaid, label: 'Haid berikutnya', value: fmtDateShort(info.next),
              sub: info.lateDays > 0 ? 'terlambat ${info.lateDays} hari' : (daysToNext == 0 ? 'hari ini' : '$daysToNext hari lagi')),
          _Pred(icon: Icons.spa_rounded, color: kSubur, label: 'Masa subur', value: '${info.fertileStart.day}–${fmtDateShort(info.fertileEnd)}', sub: 'perkiraan'),
          _Pred(icon: Icons.egg_alt_rounded, color: const Color(0xFF7C3AED), label: 'Ovulasi', value: fmtDateShort(info.ovulation), sub: 'perkiraan'),
          _Pred(icon: Icons.loop_rounded, color: AppColors.primary, label: 'Siklus rata-rata', value: '${info.cycleLen} hari', sub: 'haid ±${info.periodLen} hari'),
        ],
      ),
      const SectionHeader('Pengaturan'),
      SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(children: [
          SwitchListTile(
            value: data.remind,
            activeTrackColor: kHaid,
            onChanged: n.setRemind,
            title: const Text('Ingatkan sebelum haid', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('2 hari sebelum & pada hari perkiraan, jam 08.00'),
          ),
          ListTile(
            title: const Text('Panjang siklus default', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Dipakai bila riwayat belum cukup'),
            trailing: _Stepper(value: data.cycleLen, onChanged: n.setCycleLen),
          ),
          ListTile(
            title: const Text('Lama haid default', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: _Stepper(value: data.periodLen, onChanged: n.setPeriodLen),
          ),
        ]),
      ),
      SectionHeader('Riwayat', action: '+ Tambah', onAction: () async {
        final d = await _pickDate(context);
        if (d != null) await n.addPast(d);
      }),
      SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var i = 0; i < history.length && i < 12; i++)
            ListTile(
              dense: true,
              leading: const Icon(Icons.water_drop_outlined, color: kHaid),
              title: Text(fmtDateLong(history[i].start), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(history[i].end == null
                  ? 'sedang berlangsung'
                  : '${daysBetween(history[i].start, history[i].end!) + 1} hari'
                      '${i + 1 < history.length ? ' · siklus ${daysBetween(history[i + 1].start, history[i].start)} hari' : ''}'),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      TextButton.icon(
        onPressed: () async {
          final ok = await confirmDialog(context, title: 'Hapus data siklus?', message: 'Semua riwayat haid akan dihapus dari HP ini.', ok: 'Hapus', danger: true);
          if (ok) await n.reset();
        },
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Hapus semua data siklus'),
      ),
      const SizedBox(height: 8),
      const _Disclaimer(),
    ]);
  }
}

class _Pred extends StatelessWidget {
  const _Pred({required this.icon, required this.color, required this.label, required this.value, required this.sub});
  final IconData icon;
  final Color color;
  final String label, value, sub;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600))),
        ]),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
        Text(sub, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(visualDensity: VisualDensity.compact, onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline_rounded)),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      IconButton(visualDensity: VisualDensity.compact, onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline_rounded)),
    ]);
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 16, color: context.faint),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Perkiraan hanya estimasi dan tidak bisa dipakai sebagai alat kontrasepsi. Data siklus tersimpan di HP ini saja. '
          'Bila siklus sangat tidak teratur atau ada keluhan, konsultasikan ke dokter.',
          style: TextStyle(fontSize: 12, height: 1.4, color: context.faint),
        ),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.periodFrac, required this.fertileFrom, required this.fertileTo, required this.track});
  final double progress, periodFrac, fertileFrom, fertileTo;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = -math.pi / 2;
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p(track));
    canvas.drawArc(rect, start, math.pi * 2 * periodFrac, false, p(kHaid.withValues(alpha: .35)));
    canvas.drawArc(rect, start + math.pi * 2 * fertileFrom, math.pi * 2 * (fertileTo - fertileFrom), false, p(kSubur.withValues(alpha: .35)));
    if (progress > 0) canvas.drawArc(rect, start, math.pi * 2 * progress, false, p(kHaid));
    final a = start + math.pi * 2 * progress;
    final c = rect.center + Offset(math.cos(a), math.sin(a)) * (rect.width / 2);
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 7, Paint()..color = kHaid);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress || o.periodFrac != periodFrac || o.track != track;
}
