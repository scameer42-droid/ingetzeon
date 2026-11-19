import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:hive_flutter/hive_flutter.dart';

import '../core/i18n/i18n.dart';
import '../core/utils/date_utils.dart';
import '../data/repositories/settings_repository.dart';
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

    await _createPrayerChannels();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _launchResponse = launch!.notificationResponse;
    _loadSigs();
  }

  // ---------- jadwal hemat: hanya daftar ulang yang berubah ----------
  // Tiap panggilan jadwal/batal di Android membaca & menulis ulang SELURUH daftar jadwal di HP.
  // Ratusan panggilan saat aplikasi dibuka bikin HP macet ("tidak menanggapi"), jadi kita catat
  // jadwal yang sudah terdaftar dan hanya mengirim yang benar-benar berubah.
  static const _sigKey = 'notif_sig_v2';
  final Map<String, String> _sig = {};
  bool _needsReset = false;
  Box get _box => Hive.box(SettingsRepository.boxName);
  String get _today => dayKey(DateTime.now());

  void _loadSigs() {
    final raw = _box.get(_sigKey);
    if (raw is Map) {
      raw.forEach((k, v) => _sig['$k'] = '$v');
    } else {
      _needsReset = true; // pertama kali setelah update: bersihkan jadwal lama sekaligus (1 panggilan)
    }
  }

  Future<void> _saveSigs() => _box.put(_sigKey, Map<String, String>.from(_sig));

  /// Sekali saja: hapus semua jadwal lama yang menumpuk, lalu semua didaftarkan ulang dengan rapi.
  Future<void> resetIfNeeded() async {
    if (!_needsReset) return;
    _needsReset = false;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    _sig.clear();
    await _saveSigs();
  }

  /// Sudah terdaftar dengan isi yang sama hari ini? (sekali sehari tetap didaftarkan ulang untuk jaga-jaga)
  bool _same(int id, String sig) => _sig['$id'] == '$_today|${I18n.lang}|$sig';

  Future<void> _mark(int id, String sig) async {
    _sig['$id'] = '$_today|${I18n.lang}|$sig';
    await _saveSigs();
  }

  /// Batalkan hanya bila memang pernah dijadwalkan (atau [force]).
  Future<void> _cancelId(int id, {bool force = false}) async {
    if (!force && !_sig.containsKey('$id')) return;
    _sig.remove('$id');
    await _saveSigs();
    await _plugin.cancel(id);
  }

  /// Beri jeda kecil agar HP tetap responsif saat menjadwalkan banyak notifikasi.
  Future<void> _breathe() => Future.delayed(const Duration(milliseconds: 12));

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

  /// Teks notifikasi mengikuti bahasa tampilan.
  static String _t(String s) => tr(s);

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
        ticker: _t(title),
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
                contentTitle: _t(title),
                summaryText: _t(body),
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(_t(body)),
        actions: [
          AndroidNotificationAction(actionDone, tr('Selesai'), showsUserInterface: true, cancelNotification: true),
          AndroidNotificationAction(actionSnooze, tr('Tunda 10 menit'), showsUserInterface: true, cancelNotification: true),
        ],
      ),
    );
  }

  /// Pengingat utama: mode "jam alarm" — paling tepat waktu, tetap jalan saat HP tidur/hemat baterai.
  Future<AndroidScheduleMode> _mode() async =>
      await canExact() ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Notifikasi pendukung (sholat, mood, kebiasaan, parkir): tepat waktu tanpa ikon alarm di status bar.
  Future<AndroidScheduleMode> _modeSoft() async =>
      await canExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Bebas dari pembatasan hemat baterai?
  Future<bool> batteryUnrestricted() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Buka pengaturan aplikasi supaya pengguna bisa memilih "Baterai → Tidak dibatasi".
  /// (Tanpa izin REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, yang dibatasi oleh kebijakan Google Play.)
  Future<bool> requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.ignoreBatteryOptimizations.isGranted) return true;
    await openAppSettings();
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Tes: notifikasi pengingat berbunyi [seconds] detik lagi, memakai mode yang sama dengan pengingat asli.
  Future<void> testReminder({int seconds = 60}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    const title = '⏰ Tes pengingat IngetZeon';
    final body = 'Dijadwalkan untuk ${fmtTime(when)} — kalau muncul tepat waktu, notifikasi sudah beres ✅';
    await _plugin.cancel(999998);
    await _plugin.zonedSchedule(999998, _t(title), _t(body), when, _details(title, body, override: AlarmSound.notif),
        androidScheduleMode: await _mode());
  }

  /// Daftarkan (ulang) alarm untuk satu pengingat. Juga menghentikan alarm yang sedang berbunyi.
  Future<void> schedule(Reminder r, {bool stopRinging = false}) async {
    final next = r.alarm ? r.nextOccurrence() : null;
    if (next == null) {
      await _cancelId(r.notifId, force: stopRinging);
      return;
    }

    final when = tz.TZDateTime(tz.local, next.year, next.month, next.day, next.hour, next.minute);
    final match = switch (r.repeat) {
      RepeatType.daily => DateTimeComponents.time,
      RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
      RepeatType.monthly => DateTimeComponents.dayOfMonthAndTime,
      RepeatType.once => null,
    };
    final body = [fmtTime(next), if (r.note != null) r.note!].join(' · ');
    final mode = await _mode();
    final sig = '${r.title}|$body|${when.toIso8601String()}|$match|${r.photoPath}|${sound.name}|${mode.name}';
    if (_same(r.notifId, sig) && !stopRinging) return;
    if (stopRinging) await _plugin.cancel(r.notifId);

    try {
      await _plugin.zonedSchedule(
        r.notifId,
        _t('⏰ ${r.title}'),
        _t(body),
        when,
        _details('⏰ ${r.title}', body, photoPath: r.photoPath),
        androidScheduleMode: mode,
        matchDateTimeComponents: match,
        payload: r.id,
      );
      await _mark(r.notifId, sig);
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
      _t('⏰ ${r.title}'),
      _t(body),
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
    final mode = await _modeSoft();
    final start = r.createdAt;
    final lokasi = r.title.replaceFirst(RegExp(r'^Parkir di ', caseSensitive: false), '');
    for (var h = 1; h <= 12; h++) {
      final at = start.add(Duration(hours: h));
      if (!at.isAfter(DateTime.now())) continue;
      final body = 'Kamu sudah parkir $h jam di $lokasi (sejak ${fmtTime(start)}).';
      try {
        await _breathe();
        await _plugin.zonedSchedule(
          _hourlyBase + h,
          _t('⏱ Sudah $h jam parkir'),
          _t(body),
          tz.TZDateTime.from(at, tz.local),
          _details('⏱ Sudah $h jam parkir', body, override: AlarmSound.notif),
          androidScheduleMode: mode,
          payload: r.id,
        );
        await _mark(_hourlyBase + h, 'parkir');
      } catch (e) {
        debugPrint('Gagal jadwal parkir per jam: $e');
      }
    }
  }

  static const _cycleBase = 870000;

  /// Pengingat haid: 2 hari sebelum & pada hari perkiraan (jam 08.00).
  /// [next] null → batalkan semua.
  Future<void> scheduleCycle(DateTime? next, {DateTime? endDay}) async {
    final sigAll = '${next?.toIso8601String()}|${endDay?.toIso8601String()}';
    if (_same(_cycleBase, sigAll)) return;
    for (var i = 1; i <= 3; i++) {
      await _cancelId(_cycleBase + i);
    }
    await _mark(_cycleBase, sigAll);
    if (next == null) return;
    final mode = await _modeSoft();
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
        await _mark(it.id, 'haid');
        await _plugin.zonedSchedule(
          it.id,
          _t(it.title),
          _t(it.body),
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
              styleInformation: BigTextStyleInformation(_t(it.body)),
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
          styleInformation: BigTextStyleInformation(_t(body)),
        ),
      );

  Future<void> _daily(int id, int hour, int minute, String title, String body, String payload, Color color) async {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final mode = await _modeSoft();
    final sig = '$hour:$minute|$title|$body|${mode.name}';
    if (_same(id, sig)) return;
    try {
      await _breathe();
      await _plugin.zonedSchedule(id, _t(title), _t(body), tz.TZDateTime.from(at, tz.local), _simple(body, color),
          androidScheduleMode: mode, matchDateTimeComponents: DateTimeComponents.time, payload: payload);
      await _mark(id, sig);
    } catch (e) {
      debugPrint('Gagal jadwal harian: $e');
    }
  }

  /// Pengingat harian cek mood (pagi) & jurnal (malam). null = matikan.
  /// Pengingat olahraga harian (null = mati).
  Future<void> scheduleWorkout({int? hour, int minute = 0}) async {
    if (hour == null) {
      await _cancelId(_calmBase + 3);
      return;
    }
    await _daily(_calmBase + 3, hour, minute, '🏃 Waktunya olahraga!', 'Cukup 10–15 menit. Badan sehat, perut makin rata 💪', 'olahraga', const Color(0xFFF97316));
  }

  Future<void> scheduleCalm({int? checkinHour, int? journalHour}) async {
    if (checkinHour == null) await _cancelId(_calmBase + 1);
    if (journalHour == null) await _cancelId(_calmBase + 2);
    if (checkinHour != null) {
      await _daily(_calmBase + 1, checkinHour, 0, '🙂 Gimana perasaanmu pagi ini?', 'Catat mood & energimu, nanti aku sarankan jadwal yang pas untuk hari ini.', 'calm:mood', const Color(0xFF4F46E5));
    }
    if (journalHour != null) {
      await _daily(_calmBase + 2, journalHour, 0, '📓 Waktunya refleksi malam', 'Luangkan 3 menit untuk menulis jurnal — apa yang kamu syukuri hari ini?', 'calm:jurnal', const Color(0xFF7C3AED));
    }
  }

  /// Pengingat kebiasaan harian.
  Future<void> scheduleHabits(List<({int index, String title, int hour, int minute})> items) async {
    final keep = {for (final it in items.take(60)) _calmBase + 10 + it.index};
    for (var i = 0; i < 60; i++) {
      final id = _calmBase + 10 + i;
      if (!keep.contains(id)) await _cancelId(id);
    }
    for (final it in items.take(60)) {
      await _daily(_calmBase + 10 + it.index, it.hour, it.minute, it.title, 'Yuk, centang kebiasaan baikmu hari ini ✨', 'calm:kebiasaan', const Color(0xFF12A150));
    }
  }

  /// Notifikasi saat sesi fokus/istirahat selesai. [at] null = batalkan.
  Future<void> scheduleFocusEnd(DateTime? at, {String title = '', String body = ''}) async {
    await _cancelId(_calmBase + 900, force: true);
    if (at == null || !at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(_calmBase + 900, _t(title), _t(body), tz.TZDateTime.from(at, tz.local), _details(title, body, override: AlarmSound.notif),
          androidScheduleMode: await _mode(), payload: 'calm:fokus');
    } catch (e) {
      debugPrint('Gagal jadwal fokus: $e');
    }
  }

  // ---------- Adzan ----------
  static const _prayerBase = 850000;

  /// Pilihan suara notifikasi sholat: (kode, nama, keterangan).
  static const adzanModes = <(String, String, String)>[
    ('penuh', 'Adzan lengkap', 'Suara adzan muadzin ±2–3 menit (Subuh pakai adzan Subuh)'),
    ('pendek', 'Adzan singkat', 'Takbir pembuka saja ±20 detik'),
    ('notif', 'Bunyi notifikasi', 'Suara notifikasi biasa HP'),
    ('getar', 'Getar saja', 'Tanpa suara'),
  ];

  // Channel Android tidak bisa diubah bunyinya setelah dibuat → tiap suara punya channel sendiri.
  static String _prayerChannel(String mode, bool subuh) => switch (mode) {
        'penuh' => subuh ? 'sholat_subuh_v1' : 'sholat_adzan_v1',
        'pendek' => 'sholat_pendek_v1',
        'notif' => 'sholat_notif_v1',
        _ => 'sholat_getar_v1',
      };

  static AndroidNotificationSound? _adzanSound(String mode, bool subuh) => switch (mode) {
        'penuh' => RawResourceAndroidNotificationSound(subuh ? 'adzan_subuh' : 'adzan'),
        'pendek' => const RawResourceAndroidNotificationSound('adzan_pendek'),
        _ => null,
      };

  static String _prayerChannelName(String mode, bool subuh) => switch (mode) {
        'penuh' => subuh ? 'Sholat · Adzan Subuh' : 'Sholat · Adzan',
        'pendek' => 'Sholat · Adzan singkat',
        'notif' => 'Sholat · Bunyi notifikasi',
        _ => 'Sholat · Getar saja',
      };

  Future<void> _createPrayerChannels() async {
    for (final (mode, subuh) in const [('penuh', false), ('penuh', true), ('pendek', false), ('notif', false), ('getar', false)]) {
      final adzan = mode == 'penuh' || mode == 'pendek';
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        _prayerChannel(mode, subuh),
        _prayerChannelName(mode, subuh),
        description: 'Pengingat masuk waktu sholat',
        importance: Importance.max,
        playSound: mode != 'getar',
        sound: _adzanSound(mode, subuh),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 300, 500]),
        // adzan memakai jalur suara alarm supaya tetap terdengar walau HP mode getar
        audioAttributesUsage: adzan ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ));
    }
  }

  NotificationDetails _prayerDetails(String body, String mode, bool subuh) {
    final adzan = mode == 'penuh' || mode == 'pendek';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _prayerChannel(mode, subuh),
        _prayerChannelName(mode, subuh),
        channelDescription: 'Pengingat masuk waktu sholat',
        importance: Importance.max,
        priority: Priority.max,
        icon: 'ic_notification',
        color: const Color(0xFF059669),
        category: AndroidNotificationCategory.reminder,
        playSound: mode != 'getar',
        sound: _adzanSound(mode, subuh),
        audioAttributesUsage: adzan ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 300, 500]),
        styleInformation: BigTextStyleInformation(_t(body)),
        actions: adzan ? [AndroidNotificationAction('stop_adzan', tr('🔇 Matikan adzan'), cancelNotification: true)] : null,
      ),
    );
  }

  /// Notifikasi waktu sholat (maks. 40 slot, dijadwalkan ulang tiap aplikasi dibuka).
  Future<void> schedulePrayers(List<({int id, String key, DateTime at, String title, String body})> items, {String sound = 'penuh'}) async {
    final mode = await _modeSoft();
    final keep = <int, ({int id, String key, DateTime at, String title, String body})>{
      for (final it in items)
        if (it.id < 40 && it.at.isAfter(DateTime.now())) _prayerBase + it.id: it,
    };
    for (var i = 0; i < 40; i++) {
      if (!keep.containsKey(_prayerBase + i)) await _cancelId(_prayerBase + i);
    }
    for (final e in keep.entries) {
      final it = e.value;
      final sig = '${it.at.toIso8601String()}|${it.body}|${mode.name}|$sound';
      if (_same(e.key, sig)) continue;
      try {
        await _breathe();
        await _plugin.zonedSchedule(e.key, _t(it.title), _t(it.body), tz.TZDateTime.from(it.at, tz.local), _prayerDetails(it.body, sound, it.key == 'subuh'),
            androidScheduleMode: mode, payload: 'muslim');
        await _mark(e.key, sig);
      } catch (e) {
        debugPrint('Gagal jadwal adzan: $e');
      }
    }
  }

  /// Bunyikan contoh suara sholat sekarang juga.
  Future<void> testAdzan(String sound, {bool subuh = false}) async {
    await _plugin.cancel(999997);
    final label = adzanModes.firstWhere((m) => m.$1 == sound, orElse: () => adzanModes.first).$2;
    await _plugin.show(999997, _t('🕌 Tes suara sholat · $label'), _t('Beginilah bunyinya saat masuk waktu sholat. Ketuk "Matikan adzan" atau geser notifikasi untuk berhenti.'),
        _prayerDetails('Beginilah bunyinya saat masuk waktu sholat. Ketuk "Matikan adzan" atau geser notifikasi untuk berhenti.', sound, subuh),
        payload: 'adzan_test');
  }

  Future<void> stopAdzanTest() => _plugin.cancel(999997);

  Future<void> cancelParkingHourly() async {
    for (var h = 1; h <= 12; h++) {
      await _cancelId(_hourlyBase + h);
    }
  }

  /// Hentikan bunyi alarm tunda yang sedang tampil.
  Future<void> stopSnooze(Reminder r) => _plugin.cancel(r.snoozeNotifId);

  Future<void> cancel(Reminder r) async {
    await _cancelId(r.notifId, force: true);
    await _cancelId(r.snoozeNotifId, force: true);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _sig.clear();
    await _saveSigs();
  }

  Future<void> rescheduleAll(List<Reminder> list) async {
    await resetIfNeeded();
    for (final r in list) {
      await schedule(r);
    }
  }

  /// Tes bunyi alarm: berbunyi 5 detik lagi (kunci layar HP untuk melihat layar alarm).
  Future<void> testAlarm(AlarmSound s) async {
    await _plugin.cancel(999999);
    await _plugin.zonedSchedule(
      999999,
      _t('⏰ Tes alarm IngetZeon'),
      _t('${s.label} · ketuk Selesai untuk mematikan'),
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      _details('⏰ Tes alarm IngetZeon', s.label, override: s),
      androidScheduleMode: await _mode(),
      payload: 'test',
    );
  }

  Future<void> stopTest() => _plugin.cancel(999999);
}
