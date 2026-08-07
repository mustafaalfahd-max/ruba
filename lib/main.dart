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

class RubaApp extends StatefulWidget {
  const RubaApp({super.key});

  @override
  State<RubaApp> createState() => _RubaAppState();
}

class _RubaAppState extends State<RubaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// يُستدعى عند تبديل النظام بين الفاتح والداكن — يهمّنا في وضع «تلقائي».
  @override
  void didChangePlatformBrightness() {
    if (Settings.I.theme == themeAuto && mounted) setState(() {});
  }

  bool _resolveDark(String mode) => switch (mode) {
        themeDark => true,
        themeAuto =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
        _ => false,
      };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: Settings.I.themeNotifier,
        builder: (context, mode, _) {
          // يُضبط قبل بناء أي شاشة، فكل getters الألوان تقرأ القيمة الصحيحة.
          RC.dark = _resolveDark(mode);
          return _buildApp();
        },
      );

  Widget _buildApp() => MaterialApp(
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
        // بلا const عمداً: تغيير المظهر يعيد بناء MaterialApp، وFlutter يتخطّى
        // إعادة بناء أي widget مطابق بالهوية — فتبقى الشاشات بألوان الوضع القديم.
        home: _Root(),
      );
}

class _Root extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          // الترحيب يظهر حتى يوجد طفل واحد على الأقل.
          if (AppState.I.children.isEmpty) return WelcomeScreen();
          return Shell();
        },
      );
}
