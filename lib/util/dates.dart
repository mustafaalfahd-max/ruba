import 'package:flutter/material.dart';

const _arMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

const _arDows = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _arDowsShort = ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

String two(int n) => n.toString().padLeft(2, '0');

/// 'HH:mm'
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String hhmmFromMinutes(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  return '${two(m ~/ 60)}:${two(m % 60)}';
}

int minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

int minutesOfDay(DateTime d) => d.hour * 60 + d.minute;

/// 'الجمعة 7 آب'
String longDayLabel(DateTime d) => '${_arDows[d.weekday - 1]} ${d.day} ${_arMonths[d.month - 1]}';

/// '7 آب'
String shortDayLabel(DateTime d) => '${d.day} ${_arMonths[d.month - 1]}';

/// 'آب 2026'
String monthLabel(DateTime d) => '${_arMonths[d.month - 1]} ${d.year}';

String dowShort(DateTime d) => _arDowsShort[d.weekday - 1];

/// نص العمر: '9 أشهر' أو '2 سنة و5 أشهر'.
String ageLabel(String? dob) {
  if (dob == null || dob.isEmpty) return '—';
  final b = DateTime.tryParse(dob);
  if (b == null) return '—';
  final now = DateTime.now();
  var months = (now.year - b.year) * 12 + (now.month - b.month);
  if (now.day < b.day) months--;
  if (months < 0) months = 0;
  final y = months ~/ 12, m = months % 12;
  if (y == 0) {
    if (months == 0) return 'أقل من شهر';
    if (months == 1) return 'شهر';
    if (months == 2) return 'شهران';
    return months <= 10 ? '$months أشهر' : '$months شهراً';
  }
  final yPart = y == 1 ? 'سنة' : (y == 2 ? 'سنتان' : '$y سنوات');
  if (m == 0) return yPart;
  final mPart = m == 1 ? 'شهر' : (m == 2 ? 'شهران' : (m <= 10 ? '$m أشهر' : '$m شهراً'));
  return '$yPart و$mPart';
}

/// 'مرتين يومياً'
String perDayLabel(int n) => switch (n) {
      1 => 'مرة واحدة يومياً',
      2 => 'مرتين يومياً',
      _ => '$n مرات يومياً',
    };

/// 'ساعتين'
String hoursLabel(int n) => switch (n) {
      0 => 'أقل من ساعة',
      1 => 'ساعة',
      2 => 'ساعتين',
      _ => n <= 10 ? '$n ساعات' : '$n ساعة',
    };

String feedsCountLabel(int n) => switch (n) {
      0 => 'لا رضعات',
      1 => 'رضعة واحدة',
      2 => 'رضعتان',
      _ => n <= 10 ? '$n رضعات' : '$n رضعة',
    };

String dosesCountLabel(int n) => switch (n) {
      0 => 'لا جرعات',
      1 => 'جرعة واحدة',
      2 => 'جرعتان',
      _ => n <= 10 ? '$n جرعات' : '$n جرعة',
    };

/// بداية «اليوم» المنطقي الذي تقع فيه [at]، حيث يبدأ اليوم عند الساعة [dayStartHour].
/// رضعة الساعة الثانية فجراً تُحسب على يوم أمس عندما تكون بداية اليوم 6 صباحاً.
DateTime dayStartFor(DateTime at, int dayStartHour) {
  final anchor = DateTime(at.year, at.month, at.day, dayStartHour);
  return at.isBefore(anchor) ? anchor.subtract(const Duration(days: 1)) : anchor;
}

/// بداية اليوم المنطقي رقم [offset] قبل اليوم الحالي (0 = اليوم).
DateTime dayStartOffset(DateTime now, int dayStartHour, int offset) =>
    dayStartFor(now, dayStartHour).subtract(Duration(days: offset));

/// عدّاد بصيغة h:mm:ss
String countdownLabel(Duration d) {
  final s = d.inSeconds.abs();
  return '${s ~/ 3600}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

extension TimeOfDayX on TimeOfDay {
  String get hhmmText => '${two(hour)}:${two(minute)}';
}

TimeOfDay timeOfDayFrom(String hhmm) {
  final m = minutesOf(hhmm);
  return TimeOfDay(hour: m ~/ 60, minute: m % 60);
}
