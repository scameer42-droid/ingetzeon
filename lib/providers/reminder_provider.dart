import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/reminder.dart';
import '../data/repositories/reminder_repository.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => ReminderRepository());

/// Detak waktu tiap 30 detik agar hitung mundur & sapaan selalu segar.
final tickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

class RemindersNotifier extends Notifier<List<Reminder>> {
  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);
  NotificationService get _notif => NotificationService.instance;

  @override
  List<Reminder> build() => _sorted(ref.read(reminderRepositoryProvider).getAll());

  List<Reminder> _sorted(List<Reminder> l) => [...l]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  Reminder? byId(String id) {
    for (final r in state) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Simpan baru atau perbarui, lalu daftarkan alarmnya.
  Future<void> upsert(Reminder r) async {
    await _repo.put(r);
    state = _sorted([...state.where((x) => x.id != r.id), r]);
    await _notif.schedule(r);
  }

  /// Perbarui isi pengingat; status selesai direset bila waktu/pengulangan berubah.
  Future<void> edit(Reminder old, Reminder updated) async {
    final changed = old.scheduledAt != updated.scheduledAt || old.repeat != updated.repeat;
    if (old.photoPath != null && old.photoPath != updated.photoPath) await PhotoService.instance.delete(old.photoPath);
    await upsert(changed ? updated.copyWith(done: false, doneDates: const []) : updated);
  }

  Future<void> remove(String id) async {
    final r = byId(id);
    if (r == null) return;
    await _notif.cancel(r);
    await _repo.delete(id);
    await PhotoService.instance.delete(r.photoPath);
    state = state.where((x) => x.id != id).toList();
  }

  Future<void> setDone(Reminder r, DateTime day, bool value) async {
    final cur = byId(r.id) ?? r;
    await upsert(cur.withDone(day, value));
  }

  Future<void> snooze(String id, {Duration delay = const Duration(minutes: 10)}) async {
    final r = byId(id);
    if (r == null) return;
    await _notif.schedule(r); // hentikan bunyi & daftarkan jadwal berikutnya
    await _notif.snooze(r, delay);
  }

  /// Tutup alarm tanpa menandai selesai.
  Future<void> dismissAlarm(String id) async {
    final r = byId(id);
    if (r == null) return;
    await _notif.stopSnooze(r);
    await _notif.schedule(r);
  }

  Future<void> replaceAll(List<Reminder> list) async {
    await _notif.cancelAll();
    for (final r in state) {
      if (!list.any((x) => x.id == r.id)) await PhotoService.instance.delete(r.photoPath);
    }
    await _repo.clear();
    for (final r in list) {
      await _repo.put(r);
    }
    state = _sorted(list);
    await _notif.rescheduleAll(state);
  }

  Future<void> clearAll() => replaceAll(const []);

  Future<void> rescheduleAll() => _notif.rescheduleAll(state);

  /// Tombol "Selesai"/"Tunda" dari notifikasi.
  Future<void> handleNotification(NotificationResponse resp) async {
    final id = resp.payload;
    if (id == null) return;
    final r = byId(id);
    if (r == null) return;
    if (resp.actionId == NotificationService.actionDone) {
      await _notif.stopSnooze(r);
      await setDone(r, DateTime.now(), true);
    } else if (resp.actionId == NotificationService.actionSnooze) {
      await snooze(id);
    }
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, List<Reminder>>(RemindersNotifier.new);
