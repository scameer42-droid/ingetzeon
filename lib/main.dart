import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/i18n/i18n.dart';
import 'data/repositories/reminder_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('en_US');
  await Hive.initFlutter();
  await ReminderRepository.init();
  await SettingsRepository.init();
  I18n.setLang(SettingsRepository().get<String>('lang', 'id'));
  NotificationService.instance.sound =
      AlarmSound.fromName(SettingsRepository().get<String>('alarmSound', 'melodi'));
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: IngetZeonApp()));
}
