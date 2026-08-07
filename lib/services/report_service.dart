import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../util/dates.dart';
import 'notifications.dart';

/// تقرير للطبيب يغطّي آخر 30 يوماً: الرضاعة يوماً بيوم، والعلاجات ونسب الالتزام.
///
/// يُولَّد كملف HTML مستقل بدل PDF: يفتح في أي متصفّح على الهاتف، ومنه
/// «طباعة ← حفظ كـ PDF» بضغطتين. هذا يتجنّب تضمين محرّك PDF وخط عربي كامل
/// (زيادة تقارب 3 م.ب في حجم التطبيق) مقابل خطوة واحدة إضافية عند التصدير.
class ReportService {
  static Future<File> build({int days = 30}) async {
    final app = AppState.I;
    final child = app.current;
    if (child == null) throw StateError('لا يوجد طفل محدد');

    final dayStartHour = Settings.I.dayStartHour;
    final now = DateTime.now();
    final to = dayStartFor(now, dayStartHour).add(const Duration(days: 1));
    final from = to.subtract(Duration(days: days));

    final totals = await app.repo.dailyTotals(child.id, from, to, dayStartHour);
    final counts = await app.repo.dailyCounts(child.id, from, to, dayStartHour);
    final weights = await app.repo.weights(child.id);
    final meds = await app.repo.medications(child.id);

    final rows = StringBuffer();
    var sum = 0, daysWithData = 0, reached = 0;
    for (var i = days - 1; i >= 0; i--) {
      final d = dayStartFor(now, dayStartHour).subtract(Duration(days: i));
      final key = d.millisecondsSinceEpoch;
      final total = totals[key] ?? 0;
      final count = counts[key] ?? 0;
      final goal = await app.repo.goalOn(child.id, d.add(const Duration(days: 1)), child.goalMl);
      if (total > 0) {
        sum += total;
        daysWithData++;
        if (total >= goal) reached++;
      }
      final pct = goal == 0 ? 0 : (total / goal * 100).round();
      rows.writeln(
        '<tr><td>${_esc(shortDayLabel(d))}</td><td>$total</td><td>$goal</td>'
        '<td>$pct%</td><td>$count</td></tr>',
      );
    }

    final medRows = StringBuffer();
    for (final m in meds) {
      final given = await app.repo.givenCount(m.id);
      final planned = m.isCourse ? m.totalDoses : 0;
      medRows.writeln(
        '<tr><td>${_esc(m.name)}</td><td>${_esc(m.form)}</td>'
        '<td>${trimDose(m.dose)} ${_esc(m.unit)}</td>'
        '<td>${_esc(medTypeLabel(m.type))}</td>'
        '<td>${m.isPrn ? 'عند اللزوم' : _esc(perDayLabel(m.perDay))}</td>'
        '<td>${planned == 0 ? given : '$given / $planned'}</td>'
        '<td>${m.ended ? 'منتهٍ' : 'نشط'}</td></tr>',
      );
    }

    final weightRows = StringBuffer();
    for (final w in weights.take(12)) {
      weightRows.writeln('<tr><td>${_esc(shortDayLabel(w.at))}</td><td>${w.kg} كغ</td></tr>');
    }

    final avg = daysWithData == 0 ? 0 : (sum / daysWithData).round();
    final html = '''
<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>تقرير ربى — ${_esc(child.name)}</title>
<style>
 body{font-family:"Noto Naskh Arabic",serif;margin:24px;color:#201e1d;line-height:1.7}
 h1{font-size:26px;margin:0 0 4px} h2{font-size:18px;margin:26px 0 8px;color:#006786}
 .sub{color:#7d7979;font-size:14px;margin-bottom:18px}
 table{width:100%;border-collapse:collapse;font-size:14px}
 th,td{border:1px solid #e2dfdf;padding:7px 9px;text-align:start}
 th{background:#f3f2f2;font-weight:600}
 .kpi{display:flex;gap:10px;flex-wrap:wrap;margin:14px 0}
 .kpi div{border:1px solid #e2dfdf;border-radius:12px;padding:10px 14px;min-width:120px}
 .kpi b{display:block;font-size:22px;color:#0088b0}
 .note{margin-top:26px;padding:12px 14px;background:#fff1f4;border-radius:12px;
       color:#790e3d;font-size:13.5px}
 @media print{body{margin:10mm}}
</style></head><body>
<h1>تقرير ربى — ${_esc(child.name)}</h1>
<div class="sub">
 العمر: ${_esc(ageLabel(child.dob))} ·
 الوزن الحالي: ${child.weightKg ?? '—'} كغ ·
 المدة: آخر $days يوماً حتى ${_esc(shortDayLabel(now))}
</div>
<div class="kpi">
 <div><b>$avg مل</b>المتوسط اليومي</div>
 <div><b>${child.goalMl} مل</b>الهدف اليومي</div>
 <div><b>$reached</b>يوماً بلغ الهدف</div>
 <div><b>$daysWithData</b>يوماً بسجلات</div>
</div>
<h2>الرضاعة يوماً بيوم</h2>
<table><thead><tr><th>اليوم</th><th>المجموع (مل)</th><th>الهدف</th>
<th>النسبة</th><th>عدد الرضعات</th></tr></thead><tbody>$rows</tbody></table>
${meds.isEmpty ? '' : '<h2>العلاجات</h2><table><thead><tr><th>الدواء</th><th>الشكل</th><th>الجرعة</th><th>النوع</th><th>التكرار</th><th>جرعات أُعطيت</th><th>الحالة</th></tr></thead><tbody>$medRows</tbody></table>'}
${weights.isEmpty ? '' : '<h2>سجل الأوزان</h2><table><thead><tr><th>التاريخ</th><th>الوزن</th></tr></thead><tbody>$weightRows</tbody></table>'}
<div class="note">
 هذا التقرير مولَّد من سجلات أدخلها ولي الأمر يدوياً في تطبيق ربى.
 التطبيق أداة تسجيل ومتابعة ولا يقدّم تشخيصاً ولا توصية دوائية.
</div>
<script>if(location.hash==='#print')window.print();</script>
</body></html>
''';

    final dir = await getApplicationDocumentsDirectory();
    final safeName = child.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(
      dir.path,
      'ruba-report-$safeName-${now.year}${two(now.month)}${two(now.day)}.html',
    ));
    await file.writeAsString(html, flush: true);
    return file;
  }

  static Future<void> shareReport({int days = 30}) async {
    final file = await build(days: days);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      subject: 'تقرير ربى',
      text: 'افتح الملف في المتصفّح ثم «طباعة ← حفظ كـ PDF».',
    );
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
