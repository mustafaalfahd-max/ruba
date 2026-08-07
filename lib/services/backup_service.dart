import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../util/dates.dart';

/// نسخة احتياطية بصيغة JSON داخل ملف بامتداد `.ruba`.
///
/// كل البيانات محلية على الجهاز، ففقدان الهاتف يعني فقدان كل شيء ما لم تُصدَّر نسخة.
/// لذلك يأخذ التطبيق نسخة تلقائية يومياً ويحتفظ بآخر سبع.
class BackupService {
  static const schemaVersion = 1;
  static const _keepAuto = 7;

  static Future<Directory> _autoDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> encode() async {
    final data = await AppState.I.repo.dumpAll();
    return jsonEncode({
      'app': 'ruba',
      'schema': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': data,
    });
  }

  /// يكتب نسخة في مجلد المستندات ويعيد الملف.
  static Future<File> exportToFile() async {
    final now = DateTime.now();
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(
      docs.path,
      'ruba-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.ruba',
    ));
    await file.writeAsString(await encode(), flush: true);
    await Settings.I.setLastBackup(now);
    return file;
  }

  /// يصدّر ثم يفتح ورقة المشاركة ليختار المستخدم وجهة الحفظ أو الإرسال.
  static Future<void> exportAndShare() async {
    final file = await exportToFile();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'نسخة احتياطية — ربى',
      text: 'نسخة بيانات تطبيق ربى. احتفظ بها في مكان آمن.',
    );
  }

  /// نسخة صامتة مرة كل يوم عند فتح التطبيق، مع الإبقاء على آخر سبع نسخ فقط.
  static Future<void> autoBackupIfDue() async {
    if (!Settings.I.autoBackup) return;
    final last = Settings.I.lastBackup;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) {
      return;
    }
    final now = DateTime.now();
    final dir = await _autoDir();
    final file = File(p.join(
      dir.path,
      'auto-${now.year}${two(now.month)}${two(now.day)}.ruba',
    ));
    await file.writeAsString(await encode(), flush: true);
    await Settings.I.setLastBackup(now);
    await _pruneAuto();
  }

  static Future<void> _pruneAuto() async {
    final dir = await _autoDir();
    final files = (await dir.list().toList()).whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(_keepAuto)) {
      await f.delete();
    }
  }

  static Future<List<({File file, DateTime at, int bytes})>> listAuto() async {
    final dir = await _autoDir();
    final out = <({File file, DateTime at, int bytes})>[];
    for (final e in await dir.list().toList()) {
      if (e is! File) continue;
      final stat = await e.stat();
      out.add((file: e, at: stat.modified, bytes: stat.size));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  /// يستبدل كل البيانات الحالية بمحتوى النسخة. لا تراجع عن هذه العملية.
  static Future<void> restoreFrom(File file) async {
    final raw = await file.readAsString();
    final map = jsonDecode(raw);
    if (map is! Map || map['app'] != 'ruba') {
      throw const FormatException('هذا ليس ملف نسخة احتياطية من ربى');
    }
    final schema = map['schema'];
    if (schema is! int || schema > schemaVersion) {
      throw const FormatException('النسخة أحدث من هذا الإصدار من التطبيق');
    }
    final tables = map['tables'];
    if (tables is! Map) throw const FormatException('ملف النسخة تالف');

    final parsed = <String, List<Map<String, Object?>>>{};
    for (final t in Repo.exportTables) {
      final rows = tables[t];
      parsed[t] = rows is List
          ? rows.whereType<Map>().map((r) => Map<String, Object?>.from(r)).toList()
          : const [];
    }

    await AppState.I.repo.replaceAll(parsed);
    await AppState.I.reloadEverything();
  }

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} م.ب';
  }
}
