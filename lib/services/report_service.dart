import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../util/dates.dart';
import 'notifications.dart';

/// تقرير PDF للطبيب يغطّي آخر 30 يوماً: الرضاعة يوماً بيوم، والعلاجات
/// ونسب الالتزام، وسجل الأوزان.
///
/// الخط العربي مضمَّن في الحزمة لأن محرّك PDF لا يملك خطوطاً عربية جاهزة —
/// بدونه تظهر الحروف مربعات فارغة.
class ReportService {
  static const _cyan = PdfColor.fromInt(0xFF0088B0);
  static const _ink = PdfColor.fromInt(0xFF201E1D);
  static const _muted = PdfColor.fromInt(0xFF7D7979);
  static const _hair = PdfColor.fromInt(0xFFE2DFDF);
  static const _head = PdfColor.fromInt(0xFFF3F2F2);
  static const _warn = PdfColor.fromInt(0xFFFFF1F4);
  static const _warnInk = PdfColor.fromInt(0xFF790E3D);

  /// Amiri يغطّي العربية واللاتينية في ملف واحد.
  ///
  /// الخط الواحد مقصود: إضافة `fontFallback` تُبطل تشكيل الحروف العربية في
  /// محرّك PDF فيخرج النص معكوساً حرفاً حرفاً. أي خط بديل لاحقاً يجب أن يغطّي
  /// الأبجديتين معاً لا أن يُضاف كاحتياطي.
  static Future<pw.ThemeData> _theme() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    // محرّك PDF يضيّق المسافة بين بعض الكلمات العربية حتى تكاد تلتصق —
    // تباعد صريح يعيدها إلى الوضوح.
    return theme.copyWith(
      defaultTextStyle: theme.defaultTextStyle.copyWith(wordSpacing: 1.6),
      tableCell: theme.tableCell.copyWith(wordSpacing: 1.6),
      header0: theme.header0.copyWith(wordSpacing: 1.6),
    );
  }

  /// التنوين لا يُصيَّر صحيحاً في محرّك PDF الحالي فيظهر مربعاً — نتفاداه في نصوص التقرير.
  static String _noTanween(String s) => s.replaceAll('ً', '');

  static Future<File> build({int days = 30}) async {
    final app = AppState.I;
    final child = app.current;
    if (child == null) throw StateError('لا يوجد طفل محدد');

    final hour = Settings.I.dayStartHour;
    final now = DateTime.now();
    final todayStart = dayStartFor(now, hour);
    final to = todayStart.add(const Duration(days: 1));
    final from = to.subtract(Duration(days: days));

    final totals = await app.repo.dailyTotals(child.id, from, to, hour);
    final counts = await app.repo.dailyCounts(child.id, from, to, hour);
    final weights = await app.repo.weights(child.id);
    final meds = await app.repo.medications(child.id);

    // ── جدول الأيام ──────────────────────────────────────────────────────────
    final dayRows = <List<String>>[];
    var sum = 0, daysWithData = 0, reached = 0;
    for (var i = days - 1; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      final key = d.millisecondsSinceEpoch;
      final total = totals[key] ?? 0;
      final n = counts[key] ?? 0;
      final goal = await app.repo.goalOn(child.id, d.add(const Duration(days: 1)), child.goalMl);
      if (total > 0) {
        sum += total;
        daysWithData++;
        if (total >= goal) reached++;
      }
      dayRows.add([
        shortDayLabel(d),
        '$total',
        '$goal',
        goal == 0 ? '—' : '${(total / goal * 100).round()}%',
        '$n',
      ]);
    }
    final avg = daysWithData == 0 ? 0 : (sum / daysWithData).round();

    // ── جدول العلاجات ────────────────────────────────────────────────────────
    final medRows = <List<String>>[];
    for (final m in meds) {
      final given = await app.repo.givenCount(m.id);
      medRows.add([
        m.name,
        '${trimDose(m.dose)} ${m.unit}',
        medTypeLabel(m.type),
        m.isPrn ? 'عند اللزوم' : perDayLabel(m.perDay),
        m.isCourse ? '$given / ${m.totalDoses}' : '$given',
        m.ended ? 'منتهٍ' : 'نشط',
      ]);
    }

    final doc = pw.Document(title: 'تقرير ربى — ${child.name}');
    final theme = await _theme();

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(32, 34, 32, 34),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text('تقرير ربى · ${child.name}',
                    style: const pw.TextStyle(fontSize: 10, color: _muted, wordSpacing: 1.6)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('${ctx.pageNumber} من ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ),
        build: (ctx) => [
          pw.Text('تقرير ربى · ${child.name}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 4),
          pw.Text(
            _noTanween('العمر: ${ageLabel(child.dob)}   ·   '
                'الوزن الحالي: ${child.weightKg ?? '؟'} كغ   ·   '
                'المدة: آخر $days يوماً حتى ${shortDayLabel(now)}'),
            style: const pw.TextStyle(fontSize: 10.5, color: _muted),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _kpi('$avg مل', 'المتوسط اليومي'),
              _kpi('${child.goalMl} مل', 'الهدف اليومي'),
              _kpi('$reached', 'يوم بلغ الهدف'),
              _kpi('$daysWithData', 'يوم بسجلات'),
            ],
          ),
          pw.SizedBox(height: 18),
          _section('الرضاعة يوماً بيوم'),
          _table(
            const ['اليوم', 'المجموع بالمل', 'الهدف', 'النسبة', 'عدد الرضعات'],
            dayRows,
          ),
          if (medRows.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _section('العلاجات'),
            _table(
              const ['الدواء', 'الجرعة', 'النوع', 'التكرار', 'جرعات أُعطيت', 'الحالة'],
              medRows,
            ),
          ],
          if (weights.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _section('سجل الأوزان'),
            _table(
              const ['التاريخ', 'الوزن'],
              weights.take(14).map((w) => [shortDayLabel(w.at), '${w.kg} كغ']).toList(),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: _warn,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              _noTanween('هذا التقرير مولَّد من سجلات أدخلها وليّ الأمر يدوياً في تطبيق ربى. '
                  'التطبيق أداة تسجيل ومتابعة ولا يقدّم تشخيصاً ولا توصية دوائية.'),
              style: const pw.TextStyle(fontSize: 10, color: _warnInk, lineSpacing: 3),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeName = child.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(
      dir.path,
      'ruba-report-$safeName-${now.year}${two(now.month)}${two(now.day)}.pdf',
    ));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static pw.Widget _kpi(String value, String label) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(left: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hair),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: _cyan)),
              pw.SizedBox(height: 2),
              pw.Text(_noTanween(label),
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ),
      );

  static pw.Widget _section(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(_noTanween(title),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _cyan)),
      );

  static pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers.map(_noTanween).toList(),
        data: rows.map((r) => r.map(_noTanween).toList()).toList(),
        border: pw.TableBorder.all(color: _hair, width: .5),
        headerDecoration: const pw.BoxDecoration(color: _head),
        headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink),
        cellStyle: const pw.TextStyle(fontSize: 9.5, color: _ink),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      );

  static Future<void> shareReport({int days = 30}) async {
    final file = await build(days: days);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'تقرير ربى',
    );
  }
}
