import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/vital_provider.dart';
import '../../services/vital_logic.dart';
import '../widgets/common.dart';

const kVital = FeatureColors.vital;
const _dia = Color(0xFF7C3AED); // garis diastolik di grafik

String gluStr(GluKind k, double v) => k == GluKind.hba1c ? '${v.toStringAsFixed(1).replaceAll('.', ',')}%' : '${v.round()}';
String _when(DateTime d) => '${tr(dayLabel(d))} ${fmtTime(d)}';

/// Tensi & gula darah: catat, lihat golongannya (acuan Kemenkes), dan pantau grafiknya.
class VitalScreen extends ConsumerStatefulWidget {
  const VitalScreen({super.key, this.glucose = false});
  final bool glucose;
  @override
  ConsumerState<VitalScreen> createState() => _VitalScreenState();
}

class _VitalScreenState extends ConsumerState<VitalScreen> {
  late bool _glu = widget.glucose;
  GluKind _kind = GluKind.puasa;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(vitalProvider);
    final lb = s.lastBp, lg = s.lastGlu;
    return Scaffold(
      appBar: AppBar(title: const Text('Tensi & Gula Darah'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        FeatureHero(
          color: kVital,
          label: 'Acuan Kemenkes RI',
          title: 'Pantau tensi & gula darah',
          icon: Icons.monitor_heart_outlined,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _HeroStat(title: 'Tensi terakhir', value: lb == null ? '–' : '${lb.sys}/${lb.dia}', unit: 'mmHg', level: lb?.level, when: lb?.at)),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  title: lg == null ? 'Gula darah terakhir' : tr(lg.kind.label),
                  value: lg == null ? '–' : gluStr(lg.kind, lg.value),
                  unit: lg == null || lg.kind == GluKind.hba1c ? '' : 'mg/dL',
                  level: lg?.level,
                  when: lg?.at,
                ),
              ),
            ]),
          ),
          actions: [
            HeroButton(label: 'Catat tensi', icon: Icons.add_rounded, color: kVital, onTap: () => logBpSheet(context, ref)),
            HeroButton(label: 'Catat gula', icon: Icons.add_rounded, secondary: true, onTap: () => logGluSheet(context, ref, kind: _kind)),
          ],
        ),
        const SizedBox(height: 18),
        _Tabs(glucose: _glu, onChanged: (v) => setState(() => _glu = v)),
        if (!_glu) ..._bpSection(context, s) else ..._gluSection(context, s),
        const SizedBox(height: 22),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kVital,
              title: const Text('Saya penyandang diabetes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text('Tampilkan target kendali gula darah dari dokter', style: TextStyle(color: context.muted, fontSize: 12.5)),
              value: s.diabetic,
              onChanged: (v) => ref.read(vitalProvider.notifier).setDiabetic(v),
            ),
            Divider(height: 1, color: context.line),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleIcon(icon: Icons.alarm_rounded, color: kVital, size: 38),
              title: const Text('Ingatkan cek setiap hari', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text('Pengingat harian jam 07.00, bisa diubah', style: TextStyle(color: context.muted, fontSize: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: context.faint),
              onTap: () => _addReminder(context),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          '${tr('Fitur ini untuk memantau, bukan untuk diagnosis. Diagnosis hipertensi dan diabetes ditegakkan dokter dari beberapa kali pemeriksaan.')} ${tr(kVitalSource)}',
          translate: false,
          style: TextStyle(color: context.muted, fontSize: 12, height: 1.45),
        ),
      ]),
    );
  }

  Future<void> _addReminder(BuildContext context) async {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, 7);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await ref.read(remindersProvider.notifier).upsert(Reminder.create(
          title: tr('Cek tensi & gula darah'),
          scheduledAt: at,
          repeat: RepeatType.daily,
          category: ReminderCategory.kesehatan,
        ));
    if (context.mounted) showToast(context, tr('Pengingat harian jam 07.00 dibuat ⏰'));
  }

  List<Widget> _bpSection(BuildContext context, VitalState s) {
    final list = s.bp.reversed.toList();
    return [
      if (s.bp.length >= 2) ...[
        const SectionHeader('Grafik tensi'),
        SoftCard(padding: const EdgeInsets.fromLTRB(8, 16, 16, 8), child: SizedBox(height: 200, child: _BpChart(s.bp.length > 30 ? s.bp.sublist(s.bp.length - 30) : s.bp))),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Wrap(spacing: 14, children: [
            _Legend(color: kVital, label: tr('Sistolik (atas)')),
            const _Legend(color: _dia, label: 'Diastolik (bawah)'),
          ]),
        ),
      ],
      SectionHeader('Riwayat tensi', action: 'Catat', onAction: () => logBpSheet(context, ref)),
      if (list.isEmpty)
        const EmptyState(title: 'Belum ada catatan tensi.', subtitle: 'Ukur dalam posisi duduk setelah istirahat 5 menit, lalu catat di sini.', icon: Icons.monitor_heart_outlined)
      else
        ListGroup(children: [
          for (final e in list.take(30))
            _Row(
              color: e.level.color,
              title: '${e.sys}/${e.dia} mmHg${e.pulse != null ? ' · ${tr('nadi')} ${e.pulse}' : ''}',
              sub: '${_when(e.at)} · ${tr(e.level.label)}${isIsolatedSystolic(e.sys, e.dia) ? ' (${tr('sistolik terisolasi')})' : ''}',
              onTap: () => _detailBp(context, e),
            ),
        ]),
      const SectionHeader('Golongan tekanan darah'),
      _GuideBp(),
    ];
  }

  List<Widget> _gluSection(BuildContext context, VitalState s) {
    final ofKind = s.glu.where((e) => e.kind == _kind).toList();
    final list = s.glu.reversed.toList();
    return [
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final k in GluKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(k.short),
                selected: _kind == k,
                selectedColor: kVital.withValues(alpha: .14),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _kind == k ? kVital : context.ink),
                onSelected: (_) => setState(() => _kind = k),
              ),
            ),
        ]),
      ),
      if (ofKind.length >= 2) ...[
        SectionHeader('Grafik ${tr(_kind.short).toLowerCase()}'),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: SizedBox(height: 190, child: _GluChart(ofKind.length > 30 ? ofKind.sublist(ofKind.length - 30) : ofKind, kind: _kind, diabetic: s.diabetic)),
        ),
      ],
      SectionHeader('Riwayat gula darah', action: 'Catat', onAction: () => logGluSheet(context, ref, kind: _kind)),
      if (list.isEmpty)
        const EmptyState(title: 'Belum ada catatan gula darah.', subtitle: 'Pilih jenis pemeriksaan (puasa, 2 jam setelah makan, sewaktu, atau HbA1c), lalu catat hasilnya.', icon: Icons.bloodtype_outlined)
      else
        ListGroup(children: [
          for (final e in list.take(30))
            _Row(
              color: e.level.color,
              title: '${gluStr(e.kind, e.value)}${e.kind == GluKind.hba1c ? '' : ' mg/dL'} · ${tr(e.kind.short)}',
              sub: '${_when(e.at)} · ${tr(e.level.label)}${s.diabetic ? _targetSuffix(e) : ''}',
              onTap: () => _detailGlu(context, e),
            ),
        ]),
      const SectionHeader('Golongan gula darah (mg/dL)'),
      _GuideGlu(diabetic: s.diabetic),
    ];
  }

  String _targetSuffix(GluEntry e) {
    final t = diabetesTarget(e.kind, e.value);
    if (t == null) return '';
    return ' · ${tr(t.status == 0 ? 'sesuai target' : t.status > 0 ? 'di atas target' : 'di bawah target')}';
  }

  Future<void> _detailBp(BuildContext context, BpEntry e) => _detail(
        context,
        value: '${e.sys}/${e.dia}',
        unit: 'mmHg',
        when: e.at,
        level: e.level,
        extra: [
          if (e.pulse != null) '${tr('Nadi')} ${e.pulse} ${tr('kali/menit')}',
          if (isIsolatedSystolic(e.sys, e.dia)) tr('Hipertensi sistolik terisolasi: sistolik ≥ 140 dengan diastolik < 90.'),
        ],
        onDelete: () => ref.read(vitalProvider.notifier).removeBp(e.id),
      );

  Future<void> _detailGlu(BuildContext context, GluEntry e) {
    final t = diabetesTarget(e.kind, e.value);
    final s = ref.read(vitalProvider);
    return _detail(
      context,
      value: gluStr(e.kind, e.value),
      unit: e.kind == GluKind.hba1c ? '' : 'mg/dL',
      when: e.at,
      level: e.level,
      kind: e.kind.label,
      extra: [
        if (s.diabetic && t != null) '${tr(t.text)} · ${tr(t.status == 0 ? 'sesuai target' : t.status > 0 ? 'di atas target' : 'di bawah target')}',
        if (e.kind == GluKind.pp2) tr('Batas 140/200 berasal dari tes TTGO (minum 75 g glukosa). Setelah makan biasa, angkanya hanya perkiraan.'),
      ],
      onDelete: () => ref.read(vitalProvider.notifier).removeGlu(e.id),
    );
  }

  Future<void> _detail(BuildContext context,
      {required String value, required String unit, required DateTime when, required VitalLevel level, String? kind, List<String> extra = const [], required Future<void> Function() onDelete}) {
    return showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (kind != null) Text(kind, style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, translate: false, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: ctx.ink, letterSpacing: -1)),
            if (unit.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 9, left: 6), child: Text(unit, translate: false, style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w600))),
          ]),
          Text('${fmtDateLong(when)} · ${fmtTime(when)}', translate: false, style: TextStyle(color: ctx.muted, fontSize: 13)),
          const SizedBox(height: 14),
          LevelCard(level: level),
          for (final x in extra) ...[const SizedBox(height: 8), Text(x, translate: false, style: TextStyle(color: ctx.muted, fontSize: 13, height: 1.45))],
          const SizedBox(height: 14),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              if (await confirmDialog(ctx, title: 'Hapus catatan ini?', message: '$value $unit', ok: 'Hapus', danger: true)) {
                await onDelete();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Hapus catatan'),
          ),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.title, required this.value, required this.unit, required this.level, required this.when});
  final String title, value, unit;
  final VitalLevel? level;
  final DateTime? when;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, translate: false, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
              if (unit.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, bottom: 3), child: Text(unit, translate: false, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 4),
          Text(level == null ? tr('Belum ada catatan') : tr(level!.label),
              translate: false, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (when != null) Text(_when(when!), translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5)),
        ]),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.glucose, required this.onChanged});
  final bool glucose;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget tab(String l, bool v) => Expanded(
          child: Material(
            color: glucose == v ? kVital : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(v),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(l, style: TextStyle(fontWeight: FontWeight.w600, color: glucose == v ? Colors.white : context.ink)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [tab('Tensi', false), tab('Gula darah', true)]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.color, required this.title, required this.sub, required this.onTap});
  final Color color;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, translate: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.ink)),
                const SizedBox(height: 2),
                Text(sub, translate: false, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.35)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.faint),
          ]),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.muted)),
      ]);
}

/// Kartu golongan hasil: warna, nama golongan, dan saran.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.level});
  final VitalLevel level;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: level.color.withValues(alpha: context.isDark ? .18 : .09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: level.color.withValues(alpha: .35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(level.urgent ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: level.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(level.label, style: TextStyle(color: level.color, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text(level.advice, style: TextStyle(color: context.ink, fontSize: 13, height: 1.45)),
            ]),
          ),
        ]),
      );
}

class _GuideBp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = [...bpLevels.map((l) => l.color), const Color(0xFFEA580C)];
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        for (var i = 0; i < bpGuide.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(bpGuide[i].$1, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: context.ink))),
              Text(bpGuide[i].$2, style: TextStyle(fontSize: 13, color: context.muted)),
            ]),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Text('Angka dalam mmHg (sistolik/diastolik). Bila sistolik dan diastolik masuk golongan berbeda, dipakai golongan yang lebih tinggi.',
              style: TextStyle(fontSize: 12, color: context.muted, height: 1.4)),
        ),
      ]),
    );
  }
}

class _GuideGlu extends StatelessWidget {
  const _GuideGlu({required this.diabetic});
  final bool diabetic;
  @override
  Widget build(BuildContext context) {
    TextStyle h = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.muted);
    TextStyle c = TextStyle(fontSize: 12.5, color: context.ink);
    Widget cell(String t, TextStyle st, {bool tl = true}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(t, translate: tl, style: st));
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.1), 3: FlexColumnWidth(1.2)},
          border: TableBorder(horizontalInside: BorderSide(color: context.line)),
          children: [
            TableRow(children: [cell('Pemeriksaan', h), cell('Normal', h.copyWith(color: const Color(0xFF10B981))), cell('Prediabetes', h.copyWith(color: const Color(0xFFF59E0B))), cell('Diabetes', h.copyWith(color: const Color(0xFFDC2626)))]),
            for (final r in gluGuide) TableRow(children: [cell(r.$1, c.copyWith(fontWeight: FontWeight.w600)), cell(r.$2, c, tl: false), cell(r.$3, c, tl: false), cell(r.$4, c)]),
          ],
        ),
        const SizedBox(height: 6),
        Text('Di bawah 70 = hipoglikemia (derajat 1), di bawah 54 = derajat 2. *TTGO = tes setelah minum 75 g glukosa.',
            style: TextStyle(fontSize: 12, color: context.muted, height: 1.4)),
        if (diabetic) ...[
          const SizedBox(height: 6),
          Text('Target kendali penyandang diabetes: sebelum makan 80–130, 1–2 jam setelah makan < 180, HbA1c < 7% (atau sesuai anjuran dokter).',
              style: TextStyle(fontSize: 12, color: context.ink, height: 1.4, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

// ---------------- grafik ----------------

Widget _bottomDate(DateTime d0, double v, BuildContext context) {
  final d = d0.add(Duration(minutes: v.round()));
  return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day} ${bulanShort[d.month - 1]}', translate: false, style: TextStyle(fontSize: 11, color: context.muted)));
}

LineChartBarData _line(List<FlSpot> spots, Color c) => LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: c,
      barWidth: 3,
      dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) => FlDotCirclePainter(radius: 3.5, color: Colors.white, strokeWidth: 2.5, strokeColor: c)),
    );

class _BpChart extends StatelessWidget {
  const _BpChart(this.list);
  final List<BpEntry> list;
  @override
  Widget build(BuildContext context) {
    final d0 = list.first.at;
    double x(DateTime d) => d.difference(d0).inMinutes.toDouble();
    final maxX = math.max(1.0, x(list.last.at));
    final lo = math.min(60, list.map((e) => e.dia).reduce(math.min) - 10).toDouble();
    final hi = math.max(150, list.map((e) => e.sys).reduce(math.max) + 10).toDouble();
    return LineChart(LineChartData(
      minX: 0,
      maxX: maxX,
      minY: (lo / 10).floor() * 10,
      maxY: (hi / 10).ceil() * 10,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: 140, color: const Color(0xFFEA580C), strokeWidth: 1.5, dashArray: [6, 4], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Color(0xFFEA580C), fontSize: 10.5, fontWeight: FontWeight.w700), labelResolver: (_) => '140')),
        HorizontalLine(y: 90, color: const Color(0xFFEA580C), strokeWidth: 1.5, dashArray: [6, 4], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Color(0xFFEA580C), fontSize: 10.5, fontWeight: FontWeight.w700), labelResolver: (_) => '90')),
      ]),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => const Color(0xFF111633))),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 20, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), translate: false, style: TextStyle(fontSize: 11, color: context.muted)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: maxX, getTitlesWidget: (v, _) => _bottomDate(d0, v, context))),
      ),
      lineBarsData: [
        _line([for (final e in list) FlSpot(x(e.at), e.sys.toDouble())], kVital),
        _line([for (final e in list) FlSpot(x(e.at), e.dia.toDouble())], _dia),
      ],
    ));
  }
}

class _GluChart extends StatelessWidget {
  const _GluChart(this.list, {required this.kind, required this.diabetic});
  final List<GluEntry> list;
  final GluKind kind;
  final bool diabetic;
  @override
  Widget build(BuildContext context) {
    final d0 = list.first.at;
    double x(DateTime d) => d.difference(d0).inMinutes.toDouble();
    final maxX = math.max(1.0, x(list.last.at));
    final a1c = kind == GluKind.hba1c;
    final limits = switch (kind) {
      GluKind.puasa => [100.0, 126.0],
      GluKind.pp2 => [140.0, 200.0],
      GluKind.sewaktu => [200.0],
      GluKind.hba1c => [5.7, 6.5],
    };
    final vals = [...list.map((e) => e.value), ...limits];
    final lo = a1c ? (vals.reduce(math.min) - .5).floorToDouble() : math.max(0.0, ((vals.reduce(math.min) - 20) / 20).floor() * 20.0);
    final hi = a1c ? (vals.reduce(math.max) + .5).ceilToDouble() : ((vals.reduce(math.max) + 20) / 20).ceil() * 20.0;
    return LineChart(LineChartData(
      minX: 0,
      maxX: maxX,
      minY: lo,
      maxY: hi,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.faint.withValues(alpha: .18), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        for (final l in limits)
          HorizontalLine(
            y: l,
            color: l == limits.last ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: TextStyle(color: l == limits.last ? const Color(0xFFDC2626) : const Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.w700), labelResolver: (_) => a1c ? '$l'.replaceAll('.', ',') : l.toStringAsFixed(0)),
          ),
      ]),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => const Color(0xFF111633))),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, m) => v == m.min || v == m.max ? const SizedBox.shrink() : Text(a1c ? v.toStringAsFixed(1) : v.toStringAsFixed(0), translate: false, style: TextStyle(fontSize: 11, color: context.muted)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: maxX, getTitlesWidget: (v, _) => _bottomDate(d0, v, context))),
      ),
      lineBarsData: [_line([for (final e in list) FlSpot(x(e.at), e.value)], kVital)],
    ));
  }
}

// ---------------- lembar catat ----------------

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.label, required this.suffix, this.decimal = false, this.onChanged, this.autofocus = false});
  final TextEditingController controller;
  final String label, suffix;
  final bool decimal, autofocus;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')), LengthLimitingTextInputFormatter(decimal ? 4 : 3)],
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: tr(label), suffixText: suffix, floatingLabelAlignment: FloatingLabelAlignment.center),
      );
}

Widget _saveBtn(VoidCallback? onTap) => FilledButton(
      style: FilledButton.styleFrom(backgroundColor: kVital, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: onTap,
      child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
    );

Future<void> logBpSheet(BuildContext context, WidgetRef ref) async {
  final sysC = TextEditingController(), diaC = TextEditingController(), pulC = TextEditingController();
  await showAppSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final sys = int.tryParse(sysC.text), dia = int.tryParse(diaC.text), pul = int.tryParse(pulC.text);
      final ok = sys != null && dia != null && sys >= 50 && sys <= 300 && dia >= 30 && dia <= 200 && sys > dia;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Catat tensi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Ukur duduk tenang setelah istirahat 5 menit, lengan setinggi jantung.', style: TextStyle(color: ctx.muted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _NumField(controller: sysC, label: 'Sistolik (atas)', suffix: '', autofocus: true, onChanged: (_) => setS(() {}))),
            const Padding(padding: EdgeInsets.fromLTRB(8, 18, 8, 0), child: Text('/', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300))),
            Expanded(child: _NumField(controller: diaC, label: 'Diastolik (bawah)', suffix: '', onChanged: (_) => setS(() {}))),
          ]),
          const SizedBox(height: 12),
          _NumField(controller: pulC, label: 'Nadi (opsional)', suffix: 'kali/menit', onChanged: (_) => setS(() {})),
          const SizedBox(height: 14),
          if (ok) LevelCard(level: classifyBp(sys, dia)) else if (sys != null && dia != null) Text('Periksa lagi angkanya: sistolik harus lebih besar dari diastolik.', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          _saveBtn(!ok
              ? null
              : () async {
                  await ref.read(vitalProvider.notifier).addBp(sys, dia, pulse: pul != null && pul >= 30 && pul <= 220 ? pul : null);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) showToast(context, '${tr('Tensi')} $sys/$dia ${tr('dicatat')} ✅');
                }),
        ]),
      );
    }),
  );
}

Future<void> logGluSheet(BuildContext context, WidgetRef ref, {GluKind kind = GluKind.puasa}) async {
  final c = TextEditingController();
  var k = kind;
  await showAppSheet(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final v = double.tryParse(c.text.replaceAll(',', '.'));
      final ok = v != null && (k == GluKind.hba1c ? v >= 3 && v <= 20 : v >= 20 && v <= 700);
      final t = ok && ref.read(vitalProvider).diabetic ? diabetesTarget(k, v) : null;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Catat gula darah', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in GluKind.values)
              ChoiceChip(
                label: Text(x.short),
                selected: k == x,
                selectedColor: kVital.withValues(alpha: .14),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: k == x ? kVital : ctx.ink),
                onSelected: (_) => setS(() => k = x),
              ),
          ]),
          const SizedBox(height: 14),
          _NumField(controller: c, label: k.label, suffix: k.unit, decimal: k == GluKind.hba1c, autofocus: true, onChanged: (_) => setS(() {})),
          const SizedBox(height: 14),
          if (ok) LevelCard(level: classifyGlu(k, v)),
          if (t != null) ...[
            const SizedBox(height: 8),
            Text('${tr(t.text)} · ${tr(t.status == 0 ? 'sesuai target' : t.status > 0 ? 'di atas target' : 'di bawah target')}',
                translate: false, style: TextStyle(color: ctx.ink, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          if (k == GluKind.pp2) ...[
            const SizedBox(height: 8),
            Text('Batas 140/200 berasal dari tes TTGO (minum 75 g glukosa). Setelah makan biasa, angkanya hanya perkiraan.', style: TextStyle(color: ctx.muted, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 14),
          _saveBtn(!ok
              ? null
              : () async {
                  await ref.read(vitalProvider.notifier).addGlu(k, v);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) showToast(context, '${tr('Gula darah')} ${gluStr(k, v)} ${tr('dicatat')} ✅');
                }),
        ]),
      );
    }),
  );
}
