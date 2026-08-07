import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// وصف الإصدار كما يقرأه التطبيق من ملف `version.json`.
///
/// نموذج الملف الذي تنشره من الحاسوب:
/// ```json
/// {
///   "versionCode": 7,
///   "versionName": "1.3.0",
///   "apkUrl": "https://.../ruba-1.3.0.apk",
///   "sha256": "9f2c...",
///   "changelog": ["إصلاح تنبيه الجرعات", "تسريع فتح السجل"],
///   "mandatory": false
/// }
/// ```
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? sha256;
  final List<String> changelog;
  final bool mandatory;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.sha256,
    this.changelog = const [],
    this.mandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
        versionName: (j['versionName'] ?? '').toString(),
        apkUrl: (j['apkUrl'] ?? '').toString(),
        sha256: (j['sha256'] as String?)?.trim().toLowerCase(),
        changelog: (j['changelog'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        mandatory: j['mandatory'] == true,
      );
}

class UpdateCheckResult {
  final UpdateInfo? info;
  final bool upToDate;
  final String? error;

  const UpdateCheckResult({this.info, this.upToDate = false, this.error});
}

/// التحديث الذاتي: يقرأ بيان الإصدار من عنوان تحدده، ينزّل الـ APK،
/// يتحقق من بصمته، ثم يسلّمه لمثبّت أندرويد.
///
/// كل الإصدارات يجب أن تُوقَّع بنفس مفتاح التوقيع، وإلا رفض أندرويد التثبيت فوقها.
class UpdateService {
  static Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<String> currentVersionName() async =>
      (await PackageInfo.fromPlatform()).version;

  static Future<UpdateCheckResult> check(String manifestUrl) async {
    final url = manifestUrl.trim();
    if (url.isEmpty) {
      return const UpdateCheckResult(error: 'أدخل عنوان مصدر التحديث أولاً');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return const UpdateCheckResult(error: 'العنوان غير صالح');
    }
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return UpdateCheckResult(error: 'تعذّر الوصول إلى المصدر (${res.statusCode})');
      }
      // بعض المحرّرات وأدوات ويندوز تكتب BOM في مقدمة الملف، و jsonDecode يرفضه.
      final body = utf8.decode(res.bodyBytes).replaceFirst(RegExp(r'^﻿'), '');
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return const UpdateCheckResult(error: 'صيغة ملف الإصدار غير متوقعة');
      }
      final info = UpdateInfo.fromJson(json);
      if (info.apkUrl.isEmpty) {
        return const UpdateCheckResult(error: 'ملف الإصدار لا يحتوي على رابط APK');
      }
      final current = await currentVersionCode();
      if (info.versionCode <= current) {
        return const UpdateCheckResult(upToDate: true);
      }
      return UpdateCheckResult(info: info);
    } on FormatException {
      return const UpdateCheckResult(error: 'ملف الإصدار ليس JSON صالحاً');
    } catch (e) {
      return UpdateCheckResult(error: 'تعذّر التحقق: $e');
    }
  }

  /// ينزّل الـ APK ويستدعي [onProgress] بنسبة 0..1، ثم يتحقق من البصمة.
  static Future<File> download(
    UpdateInfo info, {
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'ruba-${info.versionName}.apk'));
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw HttpException('تعذّر تنزيل التحديث (${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == 0 ? 0 : received / total, received, total);
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }

    final expected = info.sha256;
    if (expected != null && expected.isNotEmpty) {
      final actual = sha256.convert(await file.readAsBytes()).toString();
      if (actual != expected) {
        await file.delete();
        throw const FormatException(
          'بصمة الملف المنزَّل لا تطابق المعلنة — أُلغي التحديث حمايةً لك',
        );
      }
    }
    return file;
  }

  /// يفتح مثبّت أندرويد. يطلب النظام موافقة يدوية على التثبيت من مصدر خارجي.
  static Future<String?> install(File apk) async {
    final r = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    return r.type == ResultType.done ? null : r.message;
  }
}
