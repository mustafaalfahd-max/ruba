import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/backup_service.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String _meta = '…';
  List<({File file, DateTime at, int bytes})> _auto = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final counts = await AppState.I.repo.counts();
    final size = (await BackupService.encode()).length;
    final auto = await BackupService.listAuto();
    if (!mounted) return;
    setState(() {
      _meta = '${counts.feedings} سجل رضاعة · ${counts.doses} جرعة · '
          '${counts.children} أطفال — حجم الملف ${BackupService.humanSize(size)}';
      _auto = auto;
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportAndShare();
      if (mounted) flash(context, 'صُدّرت النسخة — اختر وجهة الحفظ');
    } catch (e) {
      if (mounted) flash(context, 'تعذّر التصدير: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _restorePicked(File file) async {
    final ok = await confirm(
      context,
      title: 'استعادة نسخة',
      message: 'ستُستبدل كل البيانات الحالية على هذا الجهاز بمحتوى النسخة، '
          'ولا يمكن التراجع. تأكد من تصدير نسخة حالية أولاً إن كنت بحاجة إليها.',
      confirmLabel: 'استعادة',
      confirmColor: RC.magentaDark,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await BackupService.restoreFrom(file);
      if (mounted) flash(context, 'اكتملت الاستعادة');
    } catch (e) {
      if (mounted) flash(context, 'فشلت الاستعادة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _pickAndRestore() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final path = res?.files.single.path;
    if (path == null) return;
    await _restorePicked(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    return StackScaffold(
      title: 'النسخ الاحتياطي',
      child: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            RubaCard(
              padding: const EdgeInsets.all(18),
              shadowOpacity: .09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('تصدير نسخة الآن',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(_meta,
                      style: const TextStyle(
                          fontSize: 14.5, color: RC.ink3, height: 1.7)),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _busy ? 'جارٍ العمل…' : 'تصدير نسخة الآن',
                    height: 50,
                    fontSize: 17,
                    onTap: _busy ? null : _export,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RubaCard(
              padding: const EdgeInsets.all(18),
              shadowOpacity: .09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('استعادة من ملف',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.magentaWash,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 20, color: RC.magentaDark),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'الاستعادة تستبدل كل البيانات الحالية على هذا الجهاز '
                            'ولا يمكن التراجع عنها.',
                            style: TextStyle(
                                fontSize: 14.5, color: RC.magentaInk, height: 1.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GhostButton(
                    label: 'اختيار ملف نسخة',
                    height: 50,
                    fontSize: 17,
                    color: RC.magentaDark,
                    textColor: RC.magentaDark,
                    onTap: _pickAndRestore,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RubaCard(
              shadowOpacity: .09,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('النسخ اليومي التلقائي',
                            style: TextStyle(fontSize: 16.5)),
                        SizedBox(height: 2),
                        Text('نسخة صامتة مرة كل يوم عند فتح التطبيق',
                            style: TextStyle(fontSize: 13, color: RC.ink4)),
                      ],
                    ),
                  ),
                  RubaSwitch(
                    value: s.autoBackup,
                    onChanged: (v) async {
                      await s.setAutoBackup(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionLabel('آخر 7 نسخ تلقائية'),
            const SizedBox(height: 10),
            if (_auto.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('لم تُؤخذ نسخ تلقائية بعد.',
                    style: TextStyle(fontSize: 15, color: RC.ink4)),
              ),
            for (final b in _auto)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RubaCard(
                  radius: 14,
                  shadowOpacity: .06,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  onTap: () => _restorePicked(b.file),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${shortDayLabel(b.at)} ${hhmm(b.at)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(BackupService.humanSize(b.bytes),
                          style: const TextStyle(fontSize: 14, color: RC.ink4)),
                      const SizedBox(width: 6),
                      const Icon(Icons.restore_rounded, size: 18, color: RC.ink6),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const Text(
              'اضغط أي نسخة تلقائية لاستعادتها.',
              style: TextStyle(fontSize: 13, color: RC.ink4),
            ),
          ],
        ),
      ),
    );
  }
}
