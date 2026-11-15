import 'package:hive_flutter/hive_flutter.dart';

import '../models/reminder.dart';

/// Penyimpanan pengingat di Hive (lokal, offline).
class ReminderRepository {
  static const boxName = 'reminders';

  static Future<void> init() async {
    await Hive.openBox<Map>(boxName);
  }

  Box<Map> get _box => Hive.box<Map>(boxName);

  List<Reminder> getAll() {
    final out = <Reminder>[];
    for (final m in _box.values) {
      try {
        out.add(Reminder.fromMap(m));
      } catch (_) {
        // data rusak dilewati
      }
    }
    return out;
  }

  Future<void> put(Reminder r) => _box.put(r.id, r.toMap());

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();
}
