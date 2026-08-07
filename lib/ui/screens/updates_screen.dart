import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';

/// التحقق من التحديثات وتنزيلها وتثبيتها — دون متجر تطبيقات.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  late final _url = TextEditingController(text: Settings.I.updateUrl);
  String _version = '…';
  bool _checking = false;
  UpdateInfo? _found;
  double? _progress;
  int _received = 0, _total = 0;
  File? _downloaded;
  String? _message;

  @override
  void initState() {
    super.initState();
    UpdateService.currentVersionName().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    await Settings.I.setUpdateUrl(_url.text);
    setState(() {
      _checking = true;
      _message = null;
      _found = null;
      _downloaded = null;
      _progress = null;
    });
    final res = await UpdateService.check(_url.text);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _found = res.info;
      _message = res.error ?? (res.upToDate ? 'أنت على أحدث نسخة.' : null);
    });
  }

  Future<void> _update() async {
    final info = _found;
    if (info == null) return;
    setState(() {
      _progress = 0;
      _message = null;
    });
    try {
      final file = await UpdateService.download(
        info,
        onProgress: (p, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _received = received;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloaded = file;
        _progress = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _message = '$e';
      });
    }
  }

  Future<void> _install() async {
    final f = _downloaded;
    if (f == null) return;
    final err = await UpdateService.install(f);
    if (err != null && mounted) {
      flash(context, 'تعذّر فتح المثبّت: $err');
    }
  }

  void _later() => setState(() {
        _found = null;
        _downloaded = null;
        _progress = null;
      });

  @override
  Widget build(BuildContext context) => StackScaffold(
        title: 'التحديثات',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            RubaCard(
              padding: const EdgeInsets.all(18),
              shadowOpacity: .09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyValueRow('النسخة الحالية', _version,
                      valueStyle: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: _checking ? 'جارٍ التحقق…' : 'التحقق من وجود تحديث',
                    height: 50,
                    fontSize: 17,
                    onTap: _checking ? null : _check,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('عنوان مصدر التحديث',
                style: TextStyle(fontSize: 14, color: RC.ink4)),
            const SizedBox(height: 6),
            FilledField(
              controller: _url,
              hint: 'https://example.com/ruba/version.json',
              fontSize: 15,
              textDirection: TextDirection.ltr,
              onChanged: (v) => Settings.I.setUpdateUrl(v),
            ),
            const SizedBox(height: 8),
            const Text(
              'ملف JSON ينشره على الحاسوب أو على GitHub Releases، يحوي رقم الإصدار '
              'ورابط ملف APK وبصمته. يقارنه التطبيق بنسخته الحالية.',
              style: TextStyle(fontSize: 13, color: RC.ink4, height: 1.7),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RC.cyanWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_message!,
                    style: const TextStyle(
                        fontSize: 14.5, color: RC.cyanDark, height: 1.7)),
              ),
            ],
            if (_found != null) ...[
              const SizedBox(height: 14),
              RubaCard(
                padding: const EdgeInsets.all(18),
                shadowOpacity: .14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تحديث ${_found!.versionName} متاح',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w600)),
                        if (_total > 0)
                          Text(_sizeLabel(_total),
                              style: const TextStyle(fontSize: 14, color: RC.ink4)),
                      ],
                    ),
                    if (_found!.changelog.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final c in _found!.changelog)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('—', style: TextStyle(color: RC.cyan)),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(c,
                                    style: const TextStyle(
                                        fontSize: 15, height: 1.6, color: RC.ink2)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (_progress != null) ...[
                      const SizedBox(height: 12),
                      ThinBar(value: _progress!),
                      const SizedBox(height: 6),
                      Text(
                        _downloaded != null
                            ? 'اكتمل التنزيل'
                            : 'جارٍ التنزيل ${(_progress! * 100).round()}%'
                                '${_total > 0 ? ' · ${_sizeLabel(_received)} من ${_sizeLabel(_total)}' : ''}',
                        style: const TextStyle(fontSize: 13.5, color: RC.ink4),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_downloaded == null)
                      Row(
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: 'لاحقاً',
                              height: 48,
                              color: RC.hair(.15),
                              textColor: RC.ink3,
                              onTap: _later,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: PrimaryButton(
                              label: 'تحديث الآن',
                              height: 48,
                              fontSize: 16,
                              onTap: _progress != null ? null : _update,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: RC.mutedDeep,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.android_rounded,
                                size: 40, color: RC.ink2),
                            const SizedBox(height: 12),
                            const Text('تثبيت التحديث',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            const Text(
                              'سيطلب أندرويد تأكيد التثبيت من مصدر خارجي. '
                              'بياناتك تبقى كما هي.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14.5, color: RC.ink3, height: 1.7),
                            ),
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: 'تثبيت',
                              height: 46,
                              fontSize: 16,
                              onTap: _install,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  String _sizeLabel(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} ك.ب'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} م.ب';
}
