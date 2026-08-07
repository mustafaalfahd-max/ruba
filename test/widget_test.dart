import 'package:flutter_test/flutter_test.dart';
import 'package:ruba/state/app_state.dart';
import 'package:ruba/ui/screens/med_form_screen.dart';
import 'package:ruba/util/dates.dart';

void main() {
  group('حدود اليوم المنطقي', () {
    test('رضعة بعد منتصف الليل تُحسب على اليوم السابق', () {
      // اليوم يبدأ 6 صباحاً، فرضعة الثانية فجراً من يوم 8 تعود ليوم 7.
      final at = DateTime(2026, 8, 8, 2, 15);
      expect(dayStartFor(at, 6), DateTime(2026, 8, 7, 6));
    });

    test('رضعة بعد بداية اليوم تُحسب على اليوم نفسه', () {
      final at = DateTime(2026, 8, 8, 7, 0);
      expect(dayStartFor(at, 6), DateTime(2026, 8, 8, 6));
    });

    test('بداية يوم عند منتصف الليل تعني تقويماً عادياً', () {
      final at = DateTime(2026, 8, 8, 2, 15);
      expect(dayStartFor(at, 0), DateTime(2026, 8, 8));
    });
  });

  group('الهدف اليومي', () {
    test('يُحسب 110 مل لكل كيلوغرام ويُقرَّب لأقرب 10', () {
      expect(suggestedGoal(6.8), 750);
      expect(suggestedGoal(4.0), 440);
    });
  });

  group('توزيع مواعيد الجرعات', () {
    test('ثلاث مرات يومياً تعني كل ثماني ساعات بدءاً من الثامنة', () {
      final t = suggestTimes(3, avoidSleep: false, quietFrom: '23:00', quietTo: '05:00');
      expect(t, ['08:00', '16:00', '00:00']);
    });

    test('مرتان يومياً تعني كل اثنتي عشرة ساعة', () {
      final t = suggestTimes(2, avoidSleep: false, quietFrom: '23:00', quietTo: '05:00');
      expect(t, ['08:00', '20:00']);
    });

    test('تجنّب ساعات النوم يزيح الموعد الليلي إلى نهاية نافذة الهدوء', () {
      final t = suggestTimes(3, avoidSleep: true, quietFrom: '23:00', quietTo: '05:00');
      expect(t.contains('00:00'), isFalse);
      expect(t, contains('05:00'));
    });

    test('لا تتكرر المواعيد عند وقوع أكثر من جرعة داخل نافذة الهدوء', () {
      final t = suggestTimes(6, avoidSleep: true, quietFrom: '22:00', quietTo: '06:00');
      expect(t.toSet().length, t.length);
    });
  });

  group('صياغة النصوص العربية', () {
    test('العدّاد التنازلي بصيغة ساعة:دقيقة:ثانية', () {
      expect(countdownLabel(const Duration(hours: 1, minutes: 5, seconds: 9)), '1:05:09');
      expect(countdownLabel(const Duration(minutes: -3)), '0:03:00');
    });

    test('تصريف عدد الساعات', () {
      expect(hoursLabel(1), 'ساعة');
      expect(hoursLabel(2), 'ساعتين');
      expect(hoursLabel(5), '5 ساعات');
      expect(hoursLabel(13), '13 ساعة');
    });

    test('تصريف عدد المرات اليومية', () {
      expect(perDayLabel(1), 'مرة واحدة يومياً');
      expect(perDayLabel(2), 'مرتين يومياً');
      expect(perDayLabel(3), '3 مرات يومياً');
    });

    test('تحويل الدقائق إلى نص وقت والعكس', () {
      expect(hhmmFromMinutes(0), '00:00');
      expect(hhmmFromMinutes(1440 + 90), '01:30');
      expect(minutesOf('16:05'), 965);
    });
  });
}
