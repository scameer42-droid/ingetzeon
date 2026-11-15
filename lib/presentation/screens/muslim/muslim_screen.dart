import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/muslim_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../services/islam_logic.dart';
import '../../widgets/common.dart';
import 'muslim_tools.dart';

const kGreen = Color(0xFF059669);
const kGreen2 = Color(0xFF10B981);
const kGold = Color(0xFFF59E0B);
const kMuslimGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF047857), Color(0xFF10B981)]);

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
  await showModalBottomSheet(
    context: context,
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
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Cari kota…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
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
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: kMuslimGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: kGreen.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned(right: -4, top: -6, child: Text('🕌', style: TextStyle(fontSize: 54))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => pickCity(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.auto ? Icons.my_location_rounded : Icons.location_on_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(s.city, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Text('${hijri.d} ${hijri.monthName} ${hijri.y} H', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(fmtDateLong(now), style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12.5)),
              const SizedBox(height: 14),
              Text('Menuju ${prayerNames[next.key]}', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600)),
              Text(fmtTime(next.at), style: accentFont(size: 44, color: Colors.white)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(99)),
                child: Text('⏳ ${countdownText(next.at.difference(now))}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // ---- alat
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _Tool('🧭', 'Arah kiblat', const Color(0xFF059669), () => _push(context, const QiblaScreen())),
            _Tool('📖', "Al-Qur'an", const Color(0xFF0EA5E9), () => _push(context, const QuranListScreen())),
            _Tool('🤲', 'Doa harian', const Color(0xFFF59E0B), () => _push(context, const DoaScreen())),
            _Tool('✨', 'Asmaul Husna', const Color(0xFF8B5CF6), () => _push(context, const AsmaScreen())),
            _Tool('📿', 'Tasbih', const Color(0xFFEC4899), () => _push(context, const TasbihScreen())),
            _Tool('📅', 'Hari besar', const Color(0xFF6366F1), () => showIslamicDays(context)),
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
            for (final e in events.take(2))
              ListTile(
                dense: true,
                leading: const Text('🌙', style: TextStyle(fontSize: 22)),
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${fmtDateShort(e.date)} · ${e.hijri}'),
                trailing: Text(e.days == 0 ? 'Hari ini' : '${e.days} hari', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Tanggal Hijriah dihitung secara aritmetika dan bisa beda ±1 hari; tanggal resmi mengikuti sidang isbat Kemenag.', style: TextStyle(fontSize: 11.5, color: context.faint)),
      ]),
    );
  }

  static void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
}

Future<void> showIslamicDays(BuildContext context) async {
  final list = Hijri.upcoming(DateTime.now(), count: 6);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('Hari besar Islam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final e in list)
            ListTile(
              leading: const Text('🌙', style: TextStyle(fontSize: 22)),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${fmtDateLong(e.date)}\n${e.hijri}'),
              isThreeLine: true,
              trailing: Text(e.days == 0 ? 'Hari ini' : '${e.days} hari lagi', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800)),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Perkiraan — tanggal resmi mengikuti sidang isbat.', style: TextStyle(fontSize: 12, color: ctx.faint)),
          ),
        ]),
      ),
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool(this.emoji, this.label, this.color, this.onTap);
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

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
