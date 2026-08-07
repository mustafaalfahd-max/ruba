import 'package:flutter/material.dart';

/// لوحة ألوان «ربى» بنسختيها الفاتحة والداكنة.
///
/// كلها getters لا ثوابت، لأن قيمتها تعتمد على [RC.dark] الذي يُضبط مرة واحدة
/// في أعلى الشجرة قبل بناء أي شاشة. هذا يعني أن أي `const` يستعمل لوناً من هنا
/// لن يُصرَّف — وهو المطلوب، فاللون لم يعد ثابتاً.
class RC {
  RC._();

  /// يُضبط من [RubaApp] حسب اختيار المستخدم أو سطوع النظام.
  static bool dark = false;

  static Color _p(int light, int darkValue) => Color(dark ? darkValue : light);

  // ── الأساسيات ──────────────────────────────────────────────────────────────
  static Color get paper => _p(0xFFF3F2F2, 0xFF141313); // خلفية التطبيق
  static Color get ink => _p(0xFF201E1D, 0xFFF0EDEC); // النص الأساسي

  static Color get cyan => _p(0xFF0088B0, 0xFF33ACD1); // الرضاعة
  static Color get cyanDark => _p(0xFF006786, 0xFF8AD6F0); // نص على خلفية تركوازية باهتة
  static Color get cyanWash => _p(0xFFE9F8FF, 0xFF10323E);
  static Color get cyanPale => _p(0xFF99E0FF, 0xFF2E6E86);

  static Color get magenta => _p(0xFFD6006C, 0xFFFF5C9E); // العلاجات
  static Color get magentaDark => _p(0xFFAA0B56, 0xFFFF85B4);
  static Color get magentaInk => _p(0xFF790E3D, 0xFFFFC7DC);
  static Color get magentaWash => _p(0xFFFFF1F4, 0xFF3A1225);
  static Color get magentaPale => _p(0xFFFFC0D0, 0xFF5C2038);

  static Color get amber => _p(0xFFB07D00, 0xFFE0A93A); // التأخير
  static Color get amberLine => _p(0xFFEDBB00, 0xFFC9A227);
  static Color get amberInk => _p(0xFF8A6100, 0xFFE8C77A);
  static Color get amberWash => _p(0xFFFFF8E6, 0xFF3A2F12);
  static Color get gold => _p(0xFFC79A1A, 0xFFE0B93A); // بلوغ الهدف

  // ── الأسطح ─────────────────────────────────────────────────────────────────
  static Color get card => _p(0xFFFFFFFF, 0xFF232120);
  static Color get surface => _p(0xFFF8F4F4, 0xFF1B1A19); // التبويبات والأوراق السفلية
  static Color get muted => _p(0xFFEAE7E7, 0xFF2C2A29);
  static Color get mutedDeep => _p(0xFFEAE9E9, 0xFF262423);
  static Color get track => _p(0xFFE2DFDF, 0xFF2F2C2C); // مسار حلقة التقدم
  static Color get line => _p(0xFFD7D3D3, 0xFF3A3736);

  /// الرمادي الذي تبدأ منه حلقة التقدم قبل أن تتشبّع نحو التركوازي.
  static Color get ringStart => _p(0xFFB8B4B4, 0xFF4E4B4A);

  // ── درجات النص ─────────────────────────────────────────────────────────────
  static Color get ink2 => _p(0xFF444141, 0xFFD6D2D1);
  static Color get ink3 => _p(0xFF605D5D, 0xFFB8B4B3);
  static Color get ink4 => _p(0xFF7D7979, 0xFF948F8E);
  static Color get ink5 => _p(0xFF8D8989, 0xFF8A8584);
  static Color get ink6 => _p(0xFF9B9797, 0xFF7A7574);
  static Color get ink7 => _p(0xFFBAB6B6, 0xFF5E5A59);
  static Color get ghost => _p(0xFFC4C0C0, 0xFF4A4645);

  static Color get toastBg => _p(0xFF2D2B2B, 0xFF3A3736);
  static Color get toastInk => _p(0xFFF8F4F4, 0xFFF3F2F2);
  static Color get toastIcon => _p(0xFF62C5EE, 0xFF8AD6F0);

  /// خطوط الفصل الشعرية — داكنة على الفاتح وفاتحة على الداكن.
  static Color hair(double o) =>
      (dark ? const Color(0xFFF0EDEC) : const Color(0xFF201E1D)).withValues(alpha: o);

  /// ظل البطاقات. في الوضع الداكن الظلال شبه غير مرئية، فنعمّقها قليلاً
  /// كي تبقى حواف البطاقات محسوسة.
  static List<BoxShadow> shadow([double o = .10]) => [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: o * 3.2)
              : const Color(0xFF2D2B2B).withValues(alpha: o),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lift(double blur, double o, [double dy = 3]) => [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: o * 1.6)
              : const Color(0xFF2D2B2B).withValues(alpha: o),
          blurRadius: blur,
          offset: Offset(0, dy),
        ),
      ];
}

/// ثيم التطبيق. الخط متروك لخط النظام — أندرويد يستخدم Noto Naskh Arabic
/// وهو نفس خط التصميم، فلا داعي لتضمين ملف خط وزيادة حجم الحزمة.
ThemeData buildRubaTheme() {
  final base = TextStyle(color: RC.ink, height: 1.35);
  final brightness = RC.dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: RC.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RC.cyan,
      primary: RC.cyan,
      surface: RC.paper,
      brightness: brightness,
    ),
    splashFactory: InkRipple.splashFactory,
    dialogTheme: DialogThemeData(backgroundColor: RC.surface),
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
