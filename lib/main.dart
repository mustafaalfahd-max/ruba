import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/db.dart';
import 'services/backup_service.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'state/settings.dart';
import 'theme.dart';
import 'ui/shell.dart';
import 'ui/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
  await RubaDb.open();
  await AppState.I.load();
  await Notifs.init();
  // نسخة احتياطية صامتة مرة كل يوم — البيانات محلية بالكامل ولا مزامنة تحميها.
  unawaited(BackupService.autoBackupIfDue());
  runApp(const RubaApp());
}

class RubaApp extends StatelessWidget {
  const RubaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ربى',
        debugShowCheckedModeBanner: false,
        theme: buildRubaTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _Root(),
      );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          // الترحيب يظهر حتى يوجد طفل واحد على الأقل.
          if (AppState.I.children.isEmpty) return const WelcomeScreen();
          return const Shell();
        },
      );
}
