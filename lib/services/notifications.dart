import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../data/models.dart';
import '../util/dates.dart';

/// تذكيرات الرضعات والجرعات. كل شيء محلي — لا خادم ولا إنترنت.
///
/// التطبيق يعيد جدولة التذكيرات كاملةً بعد كل تغيير في البيانات بدل تتبّع كل تذكير على حدة،
/// لأن عدد التذكيرات صغير (يوما عمل فقط) والتتبّع التفاضلي مصدر أخطاء لا يستحقها.
class Notifs {
  Notifs._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _feedChannel = AndroidNotificationDetails(
    'ruba_feeds',
    'تذكير الرضعات',
    channelDescription: 'تنبيه قبل موعد الرضعة القادمة',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _doseChannel = AndroidNotificationDetails(
    'ruba_doses',
    'تذكير الجرعات',
    channelDescription: 'تنبيه بمواعيد جرعات العلاج',
    importance: Importance.max,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// نمرّر المواعيد كلحظات مطلقة بتوقيت UTC بدل الاعتماد على اسم منطقة الجهاز.
  /// `TZDateTime.from` تحافظ على اللحظة نفسها، فالتنبيه ينطلق في الوقت المحلي الصحيح
  /// دون الحاجة إلى حزمة إضافية لقراءة اسم المنطقة الزمنية.
  static tz.TZDateTime _instant(DateTime at) => tz.TZDateTime.from(at, tz.UTC);

  static Future<bool> requestPermission() async {
    await init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission() ?? false;
    await android.requestExactAlarmsPermission();
    return granted;
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// يمسح كل التذكيرات ثم يجدول ما يقع خلال الـ 48 ساعة القادمة.
  static Future<void> reschedule({
    required bool enabled,
    required List<Child> children,
    required Map<int, DateTime?> lastFeedByChild,
    required List<Medication> meds,
    required Set<String> handledDoseKeys,
  }) async {
    await init();
    await _plugin.cancelAll();
    if (!enabled) return;

    final now = DateTime.now();
    final horizon = now.add(const Duration(hours: 48));

    for (final c in children) {
      final last = lastFeedByChild[c.id];
      if (last == null) continue;
      final due = last.add(Duration(minutes: c.intervalMin));
      final fireAt = due.subtract(Duration(minutes: c.reminderLeadMin));
      if (fireAt.isAfter(now) && fireAt.isBefore(horizon)) {
        await _schedule(
          id: 100000 + c.id,
          at: fireAt,
          title: 'رضعة ${c.name} بعد ${c.reminderLeadMin} دقيقة',
          body: 'الموعد ${hhmm(due)}',
          details: _feedChannel,
        );
      }
    }

    final nameOf = {for (final c in children) c.id: c.name};

    for (final m in meds) {
      if (m.ended || m.isPrn || !m.remind || m.times.isEmpty) continue;
      final who = children.length > 1 ? ' — ${nameOf[m.childId] ?? ''}' : '';
      for (var dayOffset = 0; dayOffset <= 2; dayOffset++) {
        for (var i = 0; i < m.times.length && i < 6; i++) {
          final mins = minutesOf(m.times[i]);
          final base = DateTime(now.year, now.month, now.day + dayOffset);
          final at = base.add(Duration(minutes: mins));
          if (!at.isAfter(now) || at.isAfter(horizon)) continue;
          if (handledDoseKeys.contains('${m.id}@${at.millisecondsSinceEpoch}')) continue;
          if (m.isCourse && at.isAfter(m.endDate)) continue;
          await _schedule(
            // مساحة 100 لكل علاج تكفي 3 أيام × 6 مواعيد بلا تصادم معرّفات.
            id: 200000 + m.id * 100 + dayOffset * 10 + i,
            at: at,
            title: 'جرعة ${m.name}$who',
            body: '${trimDose(m.dose)} ${m.unit} — الموعد ${m.times[i]}',
            details: _doseChannel,
          );
        }
      }
    }
  }

  static Future<void> _schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _instant(at),
        NotificationDetails(android: details),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // إذن المنبّهات الدقيقة قد يكون مرفوضاً — نتراجع إلى جدولة تقريبية بدل إسقاط التذكير.
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          _instant(at),
          NotificationDetails(android: details),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('تعذّرت جدولة التذكير $id: $e2');
      }
    }
  }
}

/// 5.0 → «5» و 0.6 → «0.6»
String trimDose(double d) =>
    d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
