import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import '../services/notification_service.dart';

class AppSettings {
  const AppSettings({
    this.name = '',
    this.themeMode = ThemeMode.system,
    this.apiKey = '',
    this.model = 'gemini-flash-latest',
    this.voice = true,
    this.alarmSound = AlarmSound.melodi,
  });

  final String name;
  final ThemeMode themeMode;
  final String apiKey;
  final String model;
  final bool voice;
  final AlarmSound alarmSound;

  bool get hasAi => apiKey.trim().isNotEmpty;

  AppSettings copyWith({String? name, ThemeMode? themeMode, String? apiKey, String? model, bool? voice, AlarmSound? alarmSound}) =>
      AppSettings(
        name: name ?? this.name,
        themeMode: themeMode ?? this.themeMode,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        voice: voice ?? this.voice,
        alarmSound: alarmSound ?? this.alarmSound,
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
    );
  }

  Future<void> setName(String v) async {
    state = state.copyWith(name: v.trim());
    await _repo.set('name', state.name);
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
