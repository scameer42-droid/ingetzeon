import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/i18n.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/screens/welcome_screen.dart';
import 'providers/settings_provider.dart';

class IngetZeonApp extends ConsumerWidget {
  const IngetZeonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final lang = ref.watch(settingsProvider.select((s) => s.lang));
    final welcomed = ref.watch(settingsProvider.select((s) => s.welcomed));
    if (I18n.lang != lang) I18n.setLang(lang);
    return MaterialApp(
      title: 'IngetZeon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: lang == 'en' ? const Locale('en', 'US') : const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: welcomed ? MainShell(key: ValueKey('shell-$lang')) : WelcomeScreen(key: ValueKey('welcome-$lang')),
    );
  }
}
