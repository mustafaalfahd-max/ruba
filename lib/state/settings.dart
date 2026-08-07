import 'package:shared_preferences/shared_preferences.dart';

/// التفضيلات العامة — كل ما ليس بياناتِ طفلٍ بعينه.
class Settings {
  Settings._(this._p);

  final SharedPreferences _p;

  static late Settings I;

  static Future<void> init() async {
    I = Settings._(await SharedPreferences.getInstance());
  }

  static const _kWelcomeDone = 'welcome_done';
  static const _kDayStartHour = 'day_start_hour';
  static const _kTheme = 'theme';
  static const _kQuickMl = 'quick_ml';
  static const _kNotifications = 'notifications_enabled';
  static const _kAutoBackup = 'auto_backup';
  static const _kLastBackupMs = 'last_backup_ms';
  static const _kUpdateUrl = 'update_url';
  static const _kCurrentChild = 'current_child';

  bool get welcomeDone => _p.getBool(_kWelcomeDone) ?? false;
  Future<void> setWelcomeDone(bool v) => _p.setBool(_kWelcomeDone, v);

  /// الساعة التي يبدأ عندها «اليوم» في الحسابات. رضعة الثانية فجراً تُحسب على اليوم السابق.
  int get dayStartHour => _p.getInt(_kDayStartHour) ?? 6;
  Future<void> setDayStartHour(int v) => _p.setInt(_kDayStartHour, v);

  String get theme => _p.getString(_kTheme) ?? 'فاتح';
  Future<void> setTheme(String v) => _p.setString(_kTheme, v);

  List<int> get quickMl {
    final raw = _p.getStringList(_kQuickMl);
    if (raw == null || raw.isEmpty) return const [30, 60, 90, 120, 150];
    return raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  Future<void> setQuickMl(List<int> v) =>
      _p.setStringList(_kQuickMl, v.map((e) => e.toString()).toList());

  bool get notificationsEnabled => _p.getBool(_kNotifications) ?? true;
  Future<void> setNotificationsEnabled(bool v) => _p.setBool(_kNotifications, v);

  bool get autoBackup => _p.getBool(_kAutoBackup) ?? true;
  Future<void> setAutoBackup(bool v) => _p.setBool(_kAutoBackup, v);

  DateTime? get lastBackup {
    final ms = _p.getInt(_kLastBackupMs);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastBackup(DateTime v) => _p.setInt(_kLastBackupMs, v.millisecondsSinceEpoch);

  /// بيان الإصدار يُقرأ من الفرع الرئيسي مباشرةً لا من وسم إصدار،
  /// فيبقى العنوان ثابتاً ولا يحتاج تعديلاً في الهاتف مع كل نشر.
  static const defaultUpdateUrl =
      'https://raw.githubusercontent.com/mustafaalfahd-max/ruba/main/updates/version.json';

  String get updateUrl => _p.getString(_kUpdateUrl) ?? defaultUpdateUrl;
  Future<void> setUpdateUrl(String v) => _p.setString(_kUpdateUrl, v.trim());

  int? get currentChild => _p.getInt(_kCurrentChild);
  Future<void> setCurrentChild(int v) => _p.setInt(_kCurrentChild, v);
}
