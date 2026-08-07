import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';
import 'backup_screen.dart';
import 'updates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = i.version);
    });
  }

  Future<void> _pickDayStart() async {
    final s = Settings.I;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: RC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('ساعة بداية اليوم',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'الرضعات قبل هذه الساعة تُحتسب على اليوم السابق.',
              style: TextStyle(fontSize: 14, color: RC.ink4, height: 1.6),
            ),
          ),
          for (final h in [0, 4, 5, 6, 7, 8])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, h),
              child: Row(
                children: [
                  if (s.dayStartHour == h)
                    const Icon(Icons.check_rounded, size: 18, color: RC.cyan)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 10),
                  Text(hhmmFromMinutes(h * 60), style: const TextStyle(fontSize: 17)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await Settings.I.setDayStartHour(picked);
    await AppState.I.refresh();
    if (mounted) setState(() {});
  }

  Future<void> _toggleNotifications() async {
    final s = Settings.I;
    final next = !s.notificationsEnabled;
    if (next) {
      final granted = await Notifs.requestPermission();
      if (!granted && mounted) {
        flash(context, 'لم يُمنح إذن الإشعارات — فعّله من إعدادات النظام');
      }
    }
    await s.setNotificationsEnabled(next);
    AppState.I.unawaitedReschedule();
    if (mounted) setState(() {});
  }

  Future<void> _editQuick(int index) async {
    final s = Settings.I;
    final list = List.of(s.quickMl);
    final controller = TextEditingController(text: '${list[index]}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('كمية سريعة', style: TextStyle(fontSize: 19)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'مل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: RC.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (v == null || v <= 0) return;
    list[index] = v;
    await s.setQuickMl(list);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    final rows = <_Row>[
      _Row(
        icon: Icons.wb_twilight_rounded,
        label: 'ساعة بداية اليوم',
        hint: 'يُحتسب اليوم من هذه الساعة',
        value: hhmmFromMinutes(s.dayStartHour * 60),
        onTap: _pickDayStart,
      ),
      _Row(
        icon: Icons.notifications_active_rounded,
        label: 'الإشعارات',
        hint: 'تذكير الرضعات والجرعات',
        value: s.notificationsEnabled ? 'مفعّلة' : 'معطّلة',
        onTap: _toggleNotifications,
      ),
      _Row(
        icon: Icons.backup_rounded,
        label: 'النسخ الاحتياطي والاستعادة',
        hint: s.lastBackup == null
            ? 'لم تُؤخذ نسخة بعد'
            : 'آخر نسخة ${shortDayLabel(s.lastBackup!)} ${hhmm(s.lastBackup!)}',
        value: '',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BackupScreen()),
        ),
      ),
      _Row(
        icon: Icons.system_update_rounded,
        label: 'التحديثات',
        hint: _version.isEmpty ? 'التحقق من وجود إصدار أحدث' : 'النسخة $_version',
        value: '',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpdatesScreen()),
        ),
      ),
      _Row(
        icon: Icons.info_outline_rounded,
        label: 'معلومات التطبيق',
        hint: 'ربى — رعاية الرضّع',
        value: '',
        onTap: _showAbout,
      ),
    ];

    return StackScaffold(
      title: 'الإعدادات',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RubaCard(
                radius: 18,
                shadowOpacity: .07,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onTap: r.onTap,
                child: Row(
                  children: [
                    Icon(r.icon, size: 23, color: RC.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label, style: const TextStyle(fontSize: 16.5)),
                          const SizedBox(height: 1),
                          Text(r.hint,
                              style: const TextStyle(fontSize: 13, color: RC.ink4)),
                        ],
                      ),
                    ),
                    if (r.value.isNotEmpty)
                      Text(r.value,
                          style: const TextStyle(fontSize: 15, color: RC.ink3)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_left_rounded, size: 20, color: RC.ink6),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'الكميات السريعة الافتراضية في ورقة التسجيل',
            style: TextStyle(fontSize: 13, color: RC.ink4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < s.quickMl.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _editQuick(i),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RC.card,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: RC.shadow(.07),
                      ),
                      child: Text('${s.quickMl[i]}',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'اضغط أي كمية لتعديلها.',
            style: TextStyle(fontSize: 13, color: RC.ink4),
          ),
        ],
      ),
    );
  }

  void _showAbout() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: RC.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('ربى', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('النسخة $_version',
                  style: const TextStyle(fontSize: 15, color: RC.ink3)),
              const SizedBox(height: 12),
              const Text(
                'تطبيق متابعة الرضاعة الصناعية وعلاجات الأطفال. كل البيانات محفوظة '
                'على هذا الجهاز فقط، ولا تُرسل إلى أي خادم.',
                style: TextStyle(fontSize: 15, height: 1.7, color: RC.ink2),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RC.magentaWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ربى أداة تسجيل ومتابعة ولا تُغني عن طبيب الأطفال. '
                  'الجرعات والمواعيد يحدّدها الطبيب لا التطبيق.',
                  style: TextStyle(fontSize: 14, height: 1.7, color: RC.magentaInk),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
          ],
        ),
      );
}

class _Row {
  final IconData icon;
  final String label;
  final String hint;
  final String value;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
  });
}
