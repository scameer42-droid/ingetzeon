import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/date_utils.dart';
import '../data/models/reminder.dart';

/// Pilihan bunyi alarm. Tiap pilihan punya channel Android sendiri
/// (Android tidak mengizinkan bunyi channel diubah setelah dibuat).
enum AlarmSound {
  melodi('Melodi IngetZeon', 'Lagu alarm khas IngetZeon, berulang sampai dimatikan', 'ingetzeon_alarm_melodi_v1'),
  hp('Nada alarm HP', 'Memakai nada alarm yang kamu pilih di jam HP', 'ingetzeon_alarm_hp_v1'),
  notif('Notifikasi biasa', 'Bunyi singkat sekali, tidak berulang', 'ingetzeon_notif_v1');

  const AlarmSound(this.label, this.description, this.channelId);
  final String label;
  final String description;
  final String channelId;

  static AlarmSound fromName(String? n) =>
      AlarmSound.values.firstWhere((e) => e.name == n, orElse: () => AlarmSound.melodi);
}

/// Mengatur jadwal alarm Android, tetap berbunyi walau aplikasi ditutup.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const actionDone = 'done';
  static const actionSnooze = 'snooze';

  /// Bunyi alarm yang sedang dipakai (diatur dari Profil).
  AlarmSound sound = AlarmSound.melodi;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<NotificationResponse> _responses = StreamController.broadcast();
  NotificationResponse? _launchResponse;

  /// Notifikasi yang diketuk / tombol aksinya ditekan.
  Stream<NotificationResponse> get responses => _responses.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  AndroidNotificationSound? _soundFor(AlarmSound s) => switch (s) {
        AlarmSound.melodi => const RawResourceAndroidNotificationSound('ingetzeon_alarm'),
        AlarmSound.hp => const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
        AlarmSound.notif => null,
      };

  Future<void> init() async {
    tzdata.initializeTimeZones();
    _setLocalTimezone();

    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      onDidReceiveNotificationResponse: _responses.add,
    );

    for (final s in AlarmSound.values) {
      final isAlarm = s != AlarmSound.notif;
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        s.channelId,
        'Alarm · ${s.label}',
        description: s.description,
        importance: Importance.max,
        playSound: true,
        sound: _soundFor(s),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 400, 600, 400, 900]),
        audioAttributesUsage: isAlarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ));
    }

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _launchResponse = launch!.notificationResponse;
  }

  /// Notifikasi yang membuka aplikasi saat aplikasi masih tertutup.
  NotificationResponse? takeLaunchResponse() {
    final r = _launchResponse;
    _launchResponse = null;
    return r;
  }

  void _setLocalTimezone() {
    final offset = DateTime.now().timeZoneOffset.inMilliseconds;
    const preferred = ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura', 'Asia/Singapore', 'Asia/Kuala_Lumpur'];
    for (final name in preferred) {
      final loc = tz.getLocation(name);
      if (loc.currentTimeZone.offset == offset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  Future<bool> requestPermissions() async {
    final granted = await _android?.requestNotificationsPermission() ?? true;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    if (!exact) await _android?.requestExactAlarmsPermission();
    return granted;
  }

  /// Izin layar alarm saat HP terkunci (Android 14+ perlu izin manual).
  Future<void> requestFullScreen() async => _android?.requestFullScreenIntentPermission();

  Future<bool> notificationsEnabled() async => await _android?.areNotificationsEnabled() ?? true;

  Future<bool> canExact() async => await _android?.canScheduleExactNotifications() ?? true;

  NotificationDetails _details(String title, String body, {String? photoPath, AlarmSound? override}) {
    final s = override ?? sound;
    final isAlarm = s != AlarmSound.notif;
    final hasPhoto = photoPath != null && File(photoPath).existsSync();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        s.channelId,
        'Alarm · ${s.label}',
        channelDescription: s.description,
        importance: Importance.max,
        priority: Priority.max,
        category: isAlarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        icon: 'ic_notification',
        color: const Color(0xFF6C63FF),
        ticker: title,
        playSound: true,
        sound: _soundFor(s),
        audioAttributesUsage: isAlarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        vibrationPattern: Int64List.fromList([0, 600, 400, 600, 400, 900]),
        visibility: NotificationVisibility.public,
        fullScreenIntent: isAlarm,
        ongoing: isAlarm,
        autoCancel: !isAlarm,
        timeoutAfter: isAlarm ? 10 * 60 * 1000 : null, // berhenti sendiri setelah 10 menit
        // FLAG_INSISTENT (4): bunyi diulang terus sampai notifikasi ditanggapi
        additionalFlags: isAlarm ? Int32List.fromList([4]) : null,
        largeIcon: hasPhoto ? FilePathAndroidBitmap(photoPath) : null,
        styleInformation: hasPhoto
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(photoPath),
                contentTitle: title,
                summaryText: body,
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(body),
        actions: const [
          AndroidNotificationAction(actionDone, 'Selesai', showsUserInterface: true, cancelNotification: true),
          AndroidNotificationAction(actionSnooze, 'Tunda 10 menit', showsUserInterface: true, cancelNotification: true),
        ],
      ),
    );
  }

  Future<AndroidScheduleMode> _mode() async =>
      await canExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Daftarkan (ulang) alarm untuk satu pengingat. Juga menghentikan alarm yang sedang berbunyi.
  Future<void> schedule(Reminder r) async {
    await _plugin.cancel(r.notifId);
    if (!r.alarm) return;
    final next = r.nextOccurrence();
    if (next == null) return;

    final when = tz.TZDateTime(tz.local, next.year, next.month, next.day, next.hour, next.minute);
    final match = switch (r.repeat) {
      RepeatType.daily => DateTimeComponents.time,
      RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
      RepeatType.monthly => DateTimeComponents.dayOfMonthAndTime,
      RepeatType.once => null,
    };
    final body = [fmtTime(next), if (r.note != null) r.note!].join(' · ');

    try {
      await _plugin.zonedSchedule(
        r.notifId,
        '⏰ ${r.title}',
        body,
        when,
        _details('⏰ ${r.title}', body, photoPath: r.photoPath),
        androidScheduleMode: await _mode(),
        matchDateTimeComponents: match,
        payload: r.id,
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  /// Tunda: bunyikan lagi sekali setelah [delay].
  Future<void> snooze(Reminder r, Duration delay) async {
    final when = tz.TZDateTime.now(tz.local).add(delay);
    final body = 'Ditunda · ${fmtTime(when)}';
    await _plugin.zonedSchedule(
      r.snoozeNotifId,
      '⏰ ${r.title}',
      body,
      when,
      _details('⏰ ${r.title}', body, photoPath: r.photoPath),
      androidScheduleMode: await _mode(),
      payload: r.id,
    );
  }

  static const _hourlyBase = 880000;

  /// Pengingat parkir tiap jam (sampai 12 jam) sejak [r.createdAt].
  Future<void> scheduleParkingHourly(Reminder r) async {
    await cancelParkingHourly();
    final mode = await _mode();
    final start = r.createdAt;
    final lokasi = r.title.replaceFirst(RegExp(r'^Parkir di ', caseSensitive: false), '');
    for (var h = 1; h <= 12; h++) {
      final at = start.add(Duration(hours: h));
      if (!at.isAfter(DateTime.now())) continue;
      final body = 'Kamu sudah parkir $h jam di $lokasi (sejak ${fmtTime(start)}).';
      try {
        await _plugin.zonedSchedule(
          _hourlyBase + h,
          '⏱ Sudah $h jam parkir',
          body,
          tz.TZDateTime.from(at, tz.local),
          _details('⏱ Sudah $h jam parkir', body, override: AlarmSound.notif),
          androidScheduleMode: mode,
          payload: r.id,
        );
      } catch (e) {
        debugPrint('Gagal jadwal parkir per jam: $e');
      }
    }
  }

  static const _cycleBase = 870000;

  /// Pengingat haid: 2 hari sebelum & pada hari perkiraan (jam 08.00).
  /// [next] null → batalkan semua.
  Future<void> scheduleCycle(DateTime? next, {DateTime? endDay}) async {
    for (var i = 1; i <= 3; i++) {
      await _plugin.cancel(_cycleBase + i);
    }
    if (next == null) return;
    final mode = await _mode();
    final items = [
      (id: _cycleBase + 1, at: DateTime(next.year, next.month, next.day - 2, 8), title: '🌸 Haid 2 hari lagi',
        body: 'Perkiraan haid ${fmtDateShort(next)}. Siapkan pembalut & jaga kondisi ya.'),
      (id: _cycleBase + 2, at: DateTime(next.year, next.month, next.day, 8), title: '🌸 Haid diperkirakan hari ini',
        body: 'Kalau sudah mulai, buka IngetZeon lalu ketuk "Haid mulai" agar perkiraan makin akurat.'),
      if (endDay != null)
        (id: _cycleBase + 3, at: DateTime(endDay.year, endDay.month, endDay.day, 19), title: '🌿 Haid sudah selesai?',
          body: 'Perkiraan haidmu selesai hari ini. Kalau sudah, ketuk "Haid selesai" atau bilang ke asisten "haid selesai".'),
    ];
    for (final it in items) {
      if (!it.at.isAfter(DateTime.now())) continue;
      try {
        await _plugin.zonedSchedule(
          it.id,
          it.title,
          it.body,
          tz.TZDateTime.from(it.at, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              AlarmSound.notif.channelId,
              'Alarm · ${AlarmSound.notif.label}',
              channelDescription: AlarmSound.notif.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_notification',
              color: const Color(0xFFE11D74),
              styleInformation: BigTextStyleInformation(it.body),
            ),
          ),
          androidScheduleMode: mode,
          payload: 'cycle',
        );
      } catch (e) {
        debugPrint('Gagal jadwal pengingat haid: $e');
      }
    }
  }

  // ---------- Ruang Tenang ----------
  static const _calmBase = 860000; // +1 cek mood, +2 jurnal, +10.. kebiasaan, +900 fokus

  NotificationDetails _simple(String body, Color color) => NotificationDetails(
        android: AndroidNotificationDetails(
          AlarmSound.notif.channelId,
          'Alarm · ${AlarmSound.notif.label}',
          channelDescription: AlarmSound.notif.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: color,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  Future<void> _daily(int id, int hour, int minute, String title, String body, String payload, Color color) async {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(id, title, body, tz.TZDateTime.from(at, tz.local), _simple(body, color),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: DateTimeComponents.time, payload: payload);
    } catch (e) {
      debugPrint('Gagal jadwal harian: $e');
    }
  }

  /// Pengingat harian cek mood (pagi) & jurnal (malam). null = matikan.
  Future<void> scheduleCalm({int? checkinHour, int? journalHour}) async {
    await _plugin.cancel(_calmBase + 1);
    await _plugin.cancel(_calmBase + 2);
    if (checkinHour != null) {
      await _daily(_calmBase + 1, checkinHour, 0, '🙂 Gimana perasaanmu pagi ini?', 'Catat mood & energimu, nanti aku sarankan jadwal yang pas untuk hari ini.', 'calm:mood', const Color(0xFF4F46E5));
    }
    if (journalHour != null) {
      await _daily(_calmBase + 2, journalHour, 0, '📓 Waktunya refleksi malam', 'Luangkan 3 menit untuk menulis jurnal — apa yang kamu syukuri hari ini?', 'calm:jurnal', const Color(0xFF7C3AED));
    }
  }

  /// Pengingat kebiasaan harian.
  Future<void> scheduleHabits(List<({int index, String title, int hour, int minute})> items) async {
    for (var i = 0; i < 60; i++) {
      await _plugin.cancel(_calmBase + 10 + i);
    }
    for (final it in items.take(60)) {
      await _daily(_calmBase + 10 + it.index, it.hour, it.minute, it.title, 'Yuk, centang kebiasaan baikmu hari ini ✨', 'calm:kebiasaan', const Color(0xFF12A150));
    }
  }

  /// Notifikasi saat sesi fokus/istirahat selesai. [at] null = batalkan.
  Future<void> scheduleFocusEnd(DateTime? at, {String title = '', String body = ''}) async {
    await _plugin.cancel(_calmBase + 900);
    if (at == null || !at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(_calmBase + 900, title, body, tz.TZDateTime.from(at, tz.local), _details(title, body, override: AlarmSound.notif),
          androidScheduleMode: await _mode(), payload: 'calm:fokus');
    } catch (e) {
      debugPrint('Gagal jadwal fokus: $e');
    }
  }

  // ---------- Adzan ----------
  static const _prayerBase = 850000;

  /// Notifikasi waktu sholat (maks. 40 slot, dijadwalkan ulang tiap aplikasi dibuka).
  Future<void> schedulePrayers(List<({int id, DateTime at, String title, String body})> items) async {
    for (var i = 0; i < 40; i++) {
      await _plugin.cancel(_prayerBase + i);
    }
    final mode = await _mode();
    for (final it in items) {
      if (it.id >= 40 || !it.at.isAfter(DateTime.now())) continue;
      try {
        await _plugin.zonedSchedule(_prayerBase + it.id, it.title, it.body, tz.TZDateTime.from(it.at, tz.local), _simple(it.body, const Color(0xFF059669)),
            androidScheduleMode: mode, payload: 'muslim');
      } catch (e) {
        debugPrint('Gagal jadwal adzan: $e');
      }
    }
  }

  Future<void> cancelParkingHourly() async {
    for (var h = 1; h <= 12; h++) {
      await _plugin.cancel(_hourlyBase + h);
    }
  }

  /// Hentikan bunyi alarm tunda yang sedang tampil.
  Future<void> stopSnooze(Reminder r) => _plugin.cancel(r.snoozeNotifId);

  Future<void> cancel(Reminder r) async {
    await _plugin.cancel(r.notifId);
    await _plugin.cancel(r.snoozeNotifId);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> rescheduleAll(List<Reminder> list) async {
    for (final r in list) {
      await schedule(r);
    }
  }

  /// Tes bunyi alarm: berbunyi 5 detik lagi (kunci layar HP untuk melihat layar alarm).
  Future<void> testAlarm(AlarmSound s) async {
    await _plugin.cancel(999999);
    await _plugin.zonedSchedule(
      999999,
      '⏰ Tes alarm IngetZeon',
      '${s.label} · ketuk Selesai untuk mematikan',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      _details('⏰ Tes alarm IngetZeon', s.label, override: s),
      androidScheduleMode: await _mode(),
      payload: 'test',
    );
  }

  Future<void> stopTest() => _plugin.cancel(999999);
}
