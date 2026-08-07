import 'package:flutter/material.dart';

/// ألوان التصميم كما وردت في مشروع Claude Design.
/// أي لون جديد يُضاف هنا لا في أماكن متفرقة، حتى يبقى الوضع الداكن قابلاً للتنفيذ لاحقاً من مكان واحد.
class RC {
  RC._();

  // الأساسيات
  static const paper = Color(0xFFF3F2F2); // خلفية التطبيق
  static const ink = Color(0xFF201E1D); // النص الأساسي
  static const cyan = Color(0xFF0088B0); // اللون الأساسي — الرضاعة
  static const cyanDark = Color(0xFF006786);
  static const cyanWash = Color(0xFFE9F8FF);
  static const cyanPale = Color(0xFF99E0FF);
  static const magenta = Color(0xFFD6006C); // العلاجات
  static const magentaDark = Color(0xFFAA0B56);
  static const magentaInk = Color(0xFF790E3D);
  static const magentaWash = Color(0xFFFFF1F4);
  static const magentaPale = Color(0xFFFFC0D0);
  static const amber = Color(0xFFB07D00); // التأخير
  static const amberLine = Color(0xFFEDBB00);
  static const amberInk = Color(0xFF8A6100);
  static const amberWash = Color(0xFFFFF8E6);
  static const gold = Color(0xFFC79A1A); // بلوغ الهدف

  // الأسطح
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8F4F4); // شريط التبويبات والأوراق السفلية
  static const muted = Color(0xFFEAE7E7);
  static const mutedDeep = Color(0xFFEAE9E9);
  static const track = Color(0xFFE2DFDF); // مسار حلقة التقدم
  static const line = Color(0xFFD7D3D3);

  // درجات النص
  static const ink2 = Color(0xFF444141);
  static const ink3 = Color(0xFF605D5D);
  static const ink4 = Color(0xFF7D7979);
  static const ink5 = Color(0xFF8D8989);
  static const ink6 = Color(0xFF9B9797);
  static const ink7 = Color(0xFFBAB6B6);
  static const ghost = Color(0xFFC4C0C0);

  static const toastBg = Color(0xFF2D2B2B);
  static const toastInk = Color(0xFFF8F4F4);
  static const toastIcon = Color(0xFF62C5EE);

  static Color hair(double o) => const Color(0xFF201E1D).withValues(alpha: o);

  /// ظل البطاقات في التصميم: 0 1px 2px rgba(45,43,43,.10)
  static List<BoxShadow> shadow([double o = .10]) => [
        BoxShadow(
          color: const Color(0xFF2D2B2B).withValues(alpha: o),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lift(double blur, double o, [double dy = 3]) => [
        BoxShadow(
          color: const Color(0xFF2D2B2B).withValues(alpha: o),
          blurRadius: blur,
          offset: Offset(0, dy),
        ),
      ];
}

/// ثيم التطبيق. الخط متروك لخط النظام — أندرويد يستخدم Noto Naskh Arabic
/// وهو نفس خط التصميم، فلا داعي لتضمين ملف خط وزيادة حجم الحزمة.
ThemeData buildRubaTheme() {
  const base = TextStyle(color: RC.ink, height: 1.35);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: RC.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RC.cyan,
      primary: RC.cyan,
      surface: RC.paper,
      brightness: Brightness.light,
    ),
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      displayLarge: base.copyWith(fontSize: 76, fontWeight: FontWeight.w600, height: .9),
      headlineLarge: base.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      headlineMedium: base.copyWith(fontSize: 26, fontWeight: FontWeight.w600),
      titleLarge: base.copyWith(fontSize: 21, fontWeight: FontWeight.w600),
      titleMedium: base.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 17),
      bodyMedium: base.copyWith(fontSize: 15),
      bodySmall: base.copyWith(fontSize: 13, color: RC.ink4),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      isDense: true,
    ),
  );
}

/// أرقام بعرض ثابت — يمنع رقصة العدّاد التنازلي كل ثانية.
const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
