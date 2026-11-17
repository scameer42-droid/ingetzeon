import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/i18n.dart';
import '../data/repositories/settings_repository.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';

class AppSettings {
  const AppSettings({
    this.name = '',
    this.themeMode = ThemeMode.system,
    this.apiKey = '',
    this.model = 'gemini-flash-latest',
    this.voice = true,
    this.alarmSound = AlarmSound.melodi,
    this.avatarPath = '',
    this.lang = 'id',
    this.welcomed = true,
  });

  final String name;
  final ThemeMode themeMode;
  final String apiKey;
  final String model;
  final bool voice;
  final AlarmSound alarmSound;

  /// Foto profil (path file di HP), kosong = pakai inisial nama.
  final String avatarPath;

  /// Bahasa tampilan: 'id' atau 'en'.
  final String lang;

  /// Sudah melewati layar sambutan (isi nama) saat pertama buka.
  final bool welcomed;

  bool get hasAi => apiKey.trim().isNotEmpty;

  AppSettings copyWith({String? name, ThemeMode? themeMode, String? apiKey, String? model, bool? voice, AlarmSound? alarmSound, String? avatarPath, String? lang, bool? welcomed}) =>
      AppSettings(
        name: name ?? this.name,
        themeMode: themeMode ?? this.themeMode,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        voice: voice ?? this.voice,
        alarmSound: alarmSound ?? this.alarmSound,
        avatarPath: avatarPath ?? this.avatarPath,
        lang: lang ?? this.lang,
        welcomed: welcomed ?? this.welcomed,
      );
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  AppSettings build() {
    final repo = ref.read(settingsRepositoryProvider);
    final theme = repo.get<String>('theme', 'system');
    return AppSettings(
      name: repo.get<String>('name', ''),
      themeMode: ThemeMode.values.firstWhere((e) => e.name == theme, orElse: () => ThemeMode.system),
      apiKey: repo.get<String>('apiKey', ''),
      model: repo.get<String>('model', 'gemini-flash-latest'),
      voice: repo.get<bool>('voice', true),
      alarmSound: AlarmSound.fromName(repo.get<String>('alarmSound', 'melodi')),
      avatarPath: repo.get<String>('avatar', ''),
      lang: I18n.lang,
      welcomed: repo.get<bool>('welcomed', false) || repo.get<String>('name', '').trim().isNotEmpty,
    );
  }

  /// Selesai layar sambutan: simpan nama lalu masuk ke beranda.
  Future<void> finishWelcome(String name) async {
    await setName(name);
    state = state.copyWith(welcomed: true);
    await _repo.set('welcomed', true);
  }

  Future<void> setName(String v) async {
    state = state.copyWith(name: v.trim());
    await _repo.set('name', state.name);
  }

  /// Ganti foto profil; foto lama dihapus dari HP. [path] null = hapus foto.
  Future<void> setAvatar(String? path) async {
    final old = state.avatarPath;
    state = state.copyWith(avatarPath: path ?? '');
    await _repo.set('avatar', state.avatarPath);
    if (old.isNotEmpty && old != path) await PhotoService.instance.delete(old);
  }

  /// Ganti bahasa tampilan aplikasi.
  Future<void> setLang(String l) async {
    I18n.setLang(l);
    state = state.copyWith(lang: I18n.lang);
    await _repo.set('lang', I18n.lang);
  }

  Future<void> setTheme(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _repo.set('theme', m.name);
  }

  Future<void> setApiKey(String v) async {
    state = state.copyWith(apiKey: v.trim());
    await _repo.set('apiKey', state.apiKey);
  }

  Future<void> setModel(String v) async {
    final m = v.trim().isEmpty ? 'gemini-flash-latest' : v.trim();
    state = state.copyWith(model: m);
    await _repo.set('model', m);
  }

  Future<void> setVoice(bool v) async {
    state = state.copyWith(voice: v);
    await _repo.set('voice', v);
  }


  Future<void> setAlarmSound(AlarmSound v) async {
    state = state.copyWith(alarmSound: v);
    await _repo.set('alarmSound', v.name);
    NotificationService.instance.sound = v;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
