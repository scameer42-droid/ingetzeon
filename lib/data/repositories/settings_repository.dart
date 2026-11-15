import 'package:hive_flutter/hive_flutter.dart';

/// Penyimpanan pengaturan & riwayat chat.
class SettingsRepository {
  static const boxName = 'settings';

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  Box get _box => Hive.box(boxName);

  T get<T>(String key, T fallback) {
    final v = _box.get(key);
    return v is T ? v : fallback;
  }

  Future<void> set(String key, Object? value) => _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);
}
