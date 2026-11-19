import 'package:flutter/material.dart' hide Text;
import '../../../core/i18n/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/muslim_provider.dart';
import '../../../services/notification_service.dart';
import '../../../providers/reminder_provider.dart';
import '../../../services/islam_logic.dart';
import '../../widgets/common.dart';
import 'muslim_tools.dart';

const kGreen = Color(0xFF059669);
const kGreen2 = Color(0xFF10B981);
const kGold = Color(0xFFF59E0B);
const kMuslimGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF046C4C), Color(0xFF059669)]);

String countdownText(Duration d) {
  if (d.isNegative) return 'sekarang';
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0 && m == 0) return 'kurang dari 1 menit lagi';
  return '${h > 0 ? '$h jam ' : ''}$m menit lagi';
}

/// Ambil lokasi GPS → simpan kota terdekat. Mengembalikan pesan untuk ditampilkan.
Future<String> useGpsLocation(WidgetRef ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Aktifkan GPS/lokasi di HP dulu ya';
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return 'Izin lokasi ditolak — pilih kota secara manual';
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)));
    final near = PrayerCalc.nearestCity(pos.latitude, pos.longitude);
    final dist = PrayerCalc.distanceKm(pos.latitude, pos.longitude, near.lat, near.lng);
    final name = dist < 60 ? near.name : 'Lokasi saya';
    await ref.read(muslimProvider.notifier).setLocation(
          city: name,
          lat: pos.latitude,
          lng: pos.longitude,
          tz: DateTime.now().timeZoneOffset.inMinutes / 60,
          auto: true,
        );
    return 'Lokasi diatur: $name 📍';
  } catch (e) {
    return 'Lokasi belum bisa diambil — coba lagi atau pilih kota';
  }
}

Future<void> pickCity(BuildContext context, WidgetRef ref) async {
  var q = '';
  await showAppSheet(
    context: context,
    scroll: false,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final list = cities.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).toList();
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * .78,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Lokasi jadwal sholat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () async {
                      final msg = await useGpsLocation(ref);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) showToast(context, msg);
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Pakai lokasi saya sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setS(() => q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Cari kota…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ]),
            ),
            Expanded(
              child: ListView(children: [
                for (final c in list)
                  ListTile(
                    leading: const Icon(Icons.location_city_rounded, color: kGreen),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(c.tz == 7 ? 'WIB' : c.tz == 8 ? 'WITA' : 'WIT', style: TextStyle(color: ctx.muted, fontWeight: FontWeight.w700)),
                    onTap: () async {
                      await ref.read(muslimProvider.notifier).setLocation(city: c.name, lat: c.lat, lng: c.lng, tz: c.tz.toDouble());
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ]),
            ),
          ]),
        );
      },
    ),
  );
}

class MuslimScreen extends ConsumerWidget {
  const MuslimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final s = ref.watch(muslimProvider);
    final n = ref.read(muslimProvider.notifier);
    final t = s.timesOn(now);
    final next = s.next(now);
    final hijri = Hijri.fromDate(now);
    final done = s.doneOn(now);
    final streak = n.streak;
    final events = Hijri.upcoming(now, count: 4);
    return Scaffold(
      appBar: AppBar(title: const Text('Muslim Harian'), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        // ---- header
        FeatureHero(
          color: FeatureColors.muslim,
          icon: Icons.mosque_rounded,
          title: '${hijri.d} ${hijri.monthName} ${hijri.y} H',
          subtitle: fmtDateLong(now),
          bigCaption: 'Menuju ${prayerNames[next.key]}',
          big: fmtTime(next.at),
          trailing: GestureDetector(
            onTap: () => pickCity(context, ref),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.auto ? Icons.my_location_rounded : Icons.location_on_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(s.city, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
                const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white),
              ]),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(countdownText(next.at.difference(now)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // ---- alat
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            ToolTile(icon: Icons.explore_outlined, color: FeatureColors.muslim, label: 'Arah kiblat', onTap: () => _push(context, const QiblaScreen())),
            ToolTile(icon: Icons.menu_book_outlined, color: FeatureColors.muslim, label: "Al-Qur'an", onTap: () => _push(context, const QuranListScreen())),
            ToolTile(icon: Icons.volunteer_activism_outlined, color: FeatureColors.muslim, label: 'Doa harian', onTap: () => _push(context, const DoaScreen())),
            ToolTile(icon: Icons.auto_awesome_outlined, color: FeatureColors.muslim, label: 'Asmaul Husna', onTap: () => _push(context, const AsmaScreen())),
            ToolTile(icon: Icons.radio_button_checked_rounded, color: FeatureColors.muslim, label: 'Tasbih', onTap: () => _push(context, const TasbihScreen())),
            ToolTile(icon: Icons.event_outlined, color: FeatureColors.muslim, label: 'Hari besar', onTap: () => showIslamicDays(context)),
          ],
        ),
        // ---- jadwal
        SectionHeader('Jadwal sholat hari ini', action: s.adzan ? '🔔 Adzan aktif' : '🔕 Adzan mati', onAction: () => n.setAdzan(!s.adzan)),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final k in const ['imsak', 'subuh', 'terbit', 'dzuhur', 'ashar', 'maghrib', 'isya'])
              _PrayerRow(
                name: prayerNames[k]!,
                time: PrayerCalc.hm(t[k]!),
                wajib: prayerKeys.contains(k),
                isNext: k == next.key && sameDay(next.at, now),
                passed: PrayerCalc.at(now, t[k]!).isBefore(now),
                muted: s.muted.contains(k) || !s.adzan,
                done: done.contains(k),
                onBell: prayerKeys.contains(k) ? () => n.toggleMute(k) : null,
                onDone: prayerKeys.contains(k)
                    ? () {
                        HapticFeedback.lightImpact();
                        n.toggleDone(k);
                      }
                    : null,
              ),
          ]),
        ),
        const SizedBox(height: 10),
        const _AdzanSoundCard(),
        const SizedBox(height: 8),
        Text('Metode Kemenag RI (Subuh 20°, Isya 18°). Bisa beda 1–2 menit dengan jadwal masjid setempat.', style: TextStyle(fontSize: 11.5, color: context.faint)),
        // ---- tracker
        const SectionHeader('Tracker sholat'),
        SoftCard(
          child: Row(children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: done.length / 5, strokeWidth: 6, color: kGreen, backgroundColor: kGreen.withValues(alpha: .12)),
                Text('${done.length}/5', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(done.length >= 5 ? 'MasyaAllah, 5 waktu lengkap hari ini! 🌟' : 'Centang sholat yang sudah kamu kerjakan', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(streak > 0 ? '🔥 $streak hari berturut-turut lengkap' : 'Ayo mulai rutin hari ini', style: TextStyle(color: context.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        // ---- hari besar
        SectionHeader('Hari besar terdekat', action: 'Semua', onAction: () => showIslamicDays(context)),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var i = 0; i < 2 && i < events.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 76, color: context.line),
              IslamicDayRow(events[i], compact: true),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Text('Tanggal Hijriah dihitung secara aritmetika dan bisa beda ±1 hari; tanggal resmi mengikuti sidang isbat Kemenag.', style: TextStyle(fontSize: 11.5, color: context.faint)),
      ]),
    );
  }

  static void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
}

/// Kartu pilihan suara pengingat sholat (adzan / notifikasi / getar).
class _AdzanSoundCard extends ConsumerWidget {
  const _AdzanSoundCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(muslimProvider);
    final mode = NotificationService.adzanModes.firstWhere((m) => m.$1 == s.adzanSound, orElse: () => NotificationService.adzanModes.first);
    final on = s.adzan;
    return SoftCard(
      radius: 20,
      onTap: () => showAdzanSoundSheet(context, ref),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? kGreen : context.line, borderRadius: BorderRadius.circular(14)),
          child: Text(!on ? '🔕' : s.adzanSound == 'getar' ? '📳' : s.adzanSound == 'notif' ? '🔔' : '🕌', style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Suara waktu sholat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(on ? mode.$2 : 'Pengingat sholat mati', style: TextStyle(color: on ? const Color(0xFF059669) : context.muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        Text('Ubah', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700)),
        Icon(Icons.chevron_right_rounded, color: context.muted),
      ]),
    );
  }
}

Future<void> showAdzanSoundSheet(BuildContext context, WidgetRef ref) async {
  await showAppSheet(
    context: context,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final s = ref.watch(muslimProvider);
      final n = ref.read(muslimProvider.notifier);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetTitle('Suara waktu sholat', subtitle: 'Dibunyikan saat masuk waktu Subuh, Dzuhur, Ashar, Maghrib & Isya'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: s.adzan,
            activeThumbColor: const Color(0xFF059669),
            title: const Text('Pengingat waktu sholat', style: TextStyle(fontWeight: FontWeight.w700)),
            onChanged: (v) => n.setAdzan(v),
          ),
          const SizedBox(height: 4),
          for (final m in NotificationService.adzanModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: s.adzan && s.adzanSound == m.$1 ? const Color(0xFF059669).withValues(alpha: .1) : ctx.isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => n.setAdzanSound(m.$1),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Row(children: [
                      Icon(s.adzan && s.adzanSound == m.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: s.adzan && s.adzanSound == m.$1 ? const Color(0xFF059669) : ctx.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(m.$3, style: TextStyle(color: ctx.muted, fontSize: 12.5)),
                        ]),
                      ),
                      if (m.$1 != 'getar')
                        TextButton.icon(
                          onPressed: () => NotificationService.instance.testAdzan(m.$1),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Coba'),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(14)),
            child: const Text(
                '💡 Adzan memakai volume ALARM HP, jadi tetap terdengar walau HP mode getar. Untuk menghentikan: ketuk "Matikan adzan" atau geser notifikasinya. Waktu tertentu bisa dibisukan lewat ikon lonceng di jadwal.',
                style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5, height: 1.4)),
          ),
          TextButton(onPressed: () => NotificationService.instance.stopAdzanTest(), child: const Text('Hentikan suara tes')),
        ]),
      );
    }),
  );
}

Future<void> showIslamicDays(BuildContext context) async {
  final list = Hijri.upcoming(DateTime.now(), count: 6);
  await showAppSheet(
    context: context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('Hari besar Islam', subtitle: 'Perkiraan — tanggal resmi mengikuti sidang isbat'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(children: [for (final e in list) IslamicDayRow(e)]),
      ),
    ]),
  );
}

/// Baris hari besar: kotak tanggal, nama + tanggal Hijriah, sisa hari.
class IslamicDayRow extends StatelessWidget {
  const IslamicDayRow(this.e, {super.key, this.compact = false});
  final ({String name, DateTime date, int days, String hijri}) e;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: compact ? null : BoxDecoration(color: context.card2, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 52,
          height: 56,
          decoration: BoxDecoration(color: kGreen.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.date.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kGreen, height: 1.1)),
            Text(monthShortName(e.date.month).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: .5)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${hariLong(e.date)} · ${e.hijri}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: kGreen.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
          child: Text(e.days == 0 ? 'Hari ini' : '${e.days} hari', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    );
  }
}

String hariLong(DateTime d) => fmtDateLong(d).split(',').first;

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.wajib,
    required this.isNext,
    required this.passed,
    required this.muted,
    required this.done,
    this.onBell,
    this.onDone,
  });
  final String name, time;
  final bool wajib, isNext, passed, muted, done;
  final VoidCallback? onBell, onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: isNext ? kGreen.withValues(alpha: .1) : null, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Text(name,
              style: TextStyle(
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                color: isNext ? kGreen : (wajib ? context.ink : context.muted),
              )),
        ),
        Text(time, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isNext ? kGreen : (passed && !isNext ? context.muted : context.ink))),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: onBell == null
              ? null
              : IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onBell,
                  icon: Icon(muted ? Icons.notifications_off_outlined : Icons.notifications_active_rounded, size: 20, color: muted ? context.faint : kGreen),
                ),
        ),
        SizedBox(
          width: 36,
          child: onDone == null
              ? null
              : GestureDetector(
                  onTap: onDone,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? kGreen : Colors.transparent,
                      border: Border.all(color: done ? kGreen : context.line, width: 2),
                    ),
                    child: done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                  ),
                ),
        ),
      ]),
    );
  }
}

/// Kartu ringkas di Beranda.
String muslimSummary(MuslimSettings s, DateTime now) {
  final n = s.next(now);
  return '${prayerNames[n.key]} ${fmtTime(n.at)} · ${countdownText(n.at.difference(now))}';
}
