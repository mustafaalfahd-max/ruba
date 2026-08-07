import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';

/// ملف الطفل: البيانات، الهدف اليومي، جدولة الرضاعة، سجل الأوزان، والحفاضات.
class ChildScreen extends StatefulWidget {
  const ChildScreen({super.key});

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  late Child _draft;

  @override
  void initState() {
    super.initState();
    _draft = AppState.I.current!;
  }

  Future<void> _save() async {
    await AppState.I.saveChild(_draft, newGoal: _draft.goalMl);
    if (!mounted) return;
    Navigator.pop(context);
    flash(context, 'حُفظ ملف الطفل');
  }

  Future<void> _pickInterval() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.intervalMin ~/ 60, minute: _draft.intervalMin % 60),
      helpText: 'الفاصل بين الرضعات',
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (t == null) return;
    final mins = t.hour * 60 + t.minute;
    if (mins < 30) {
      if (mounted) flash(context, 'الفاصل لا يقل عن 30 دقيقة');
      return;
    }
    setState(() => _draft = _draft.copyWith(intervalMin: mins));
  }

  Future<void> _pickQuiet(bool isFrom) async {
    final t = await showTimePicker(
      context: context,
      initialTime: timeOfDayFrom(isFrom ? _draft.quietFrom : _draft.quietTo),
      helpText: isFrom ? 'بداية ساعات الهدوء' : 'نهاية ساعات الهدوء',
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (t == null) return;
    setState(() => _draft = isFrom
        ? _draft.copyWith(quietFrom: t.hhmmText)
        : _draft.copyWith(quietTo: t.hhmmText));
  }

  Future<void> _addWeight() async {
    final c = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('قياس وزن جديد', style: TextStyle(fontSize: 19)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'كغ', hintText: '6.8'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: RC.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null || v <= 0) return;
    await AppState.I.addWeight(v);
    if (!mounted) return;
    setState(() => _draft = AppState.I.current!);
    flash(context, 'أُضيف القياس $v كغ');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => StackScaffold(
        title: _draft.name,
        actionLabel: 'حفظ',
        onAction: _save,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            RubaCard(
              shadowOpacity: .09,
              child: Column(
                children: [
                  KeyValueRow('الاسم', _draft.name),
                  const SizedBox(height: 11),
                  KeyValueRow('تاريخ الميلاد', _draft.dob ?? '—'),
                  const SizedBox(height: 11),
                  KeyValueRow('العمر', ageLabel(_draft.dob)),
                  const SizedBox(height: 11),
                  KeyValueRow('الجنس', _draft.sex == 'f' ? 'أنثى' : 'ذكر'),
                  const SizedBox(height: 11),
                  KeyValueRow('الوزن الحالي', '${_draft.weightKg ?? '—'} كغ'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('الهدف اليومي'),
            const SizedBox(height: 10),
            RubaCard(
              shadowOpacity: .09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PillButton(
                        label: 'محسوب من الوزن',
                        selected: _draft.goalAuto,
                        expand: true,
                        onTap: () {
                          final w = _draft.weightKg;
                          if (w == null) {
                            flash(context, 'أضف قياس وزن أولاً');
                            return;
                          }
                          setState(() => _draft = _draft.copyWith(
                                goalAuto: true,
                                goalMl: suggestedGoal(w),
                              ));
                        },
                      ),
                      const SizedBox(width: 8),
                      PillButton(
                        label: 'يدوي',
                        selected: !_draft.goalAuto,
                        expand: true,
                        onTap: () => setState(
                            () => _draft = _draft.copyWith(goalAuto: false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_draft.goalMl}',
                        style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w600, color: RC.cyan),
                      ),
                      const SizedBox(width: 8),
                      const Text('مل / يوم',
                          style: TextStyle(fontSize: 16, color: RC.ink4)),
                      const Spacer(),
                      if (!_draft.goalAuto) ...[
                        _round('−', () => setState(() => _draft = _draft.copyWith(
                            goalMl: (_draft.goalMl - 10).clamp(100, 3000)))),
                        const SizedBox(width: 8),
                        _round('+', () => setState(() => _draft = _draft.copyWith(
                            goalMl: (_draft.goalMl + 10).clamp(100, 3000)))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _draft.goalAuto
                        ? '${_draft.weightKg ?? 0} كغ × 110 مل = '
                            '${((_draft.weightKg ?? 0) * 110).round()} مل، مقرّبة لأقرب 10. '
                            'يتحدّث تلقائياً عند إضافة قياس وزن جديد.'
                        : 'قيمة يدوية — لن تتغير عند تحديث الوزن.',
                    style: const TextStyle(fontSize: 14, color: RC.ink3, height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('جدولة الرضاعة'),
            const SizedBox(height: 10),
            RubaCard(
              shadowOpacity: .09,
              child: Column(
                children: [
                  _tapRow('الفاصل بين الرضعات',
                      '${_draft.intervalMin ~/ 60}:${two(_draft.intervalMin % 60)} ساعة',
                      _pickInterval),
                  const SizedBox(height: 12),
                  _tapRow('مهلة التنبيه', '${_draft.reminderLeadMin} دقيقة', _pickLead),
                  const SizedBox(height: 12),
                  _tapRow('بداية ساعات الهدوء', _draft.quietFrom, () => _pickQuiet(true)),
                  const SizedBox(height: 12),
                  _tapRow('نهاية ساعات الهدوء', _draft.quietTo, () => _pickQuiet(false)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('سجل الأوزان'),
            const SizedBox(height: 10),
            RubaCard(
              shadowOpacity: .09,
              child: Column(
                children: [
                  if (app.weights.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('لا توجد قياسات بعد.',
                          style: TextStyle(fontSize: 15, color: RC.ink4)),
                    ),
                  for (final w in app.weights.take(8)) ...[
                    KeyValueRow(
                      shortDayLabel(w.at),
                      '${w.kg} كغ',
                      valueStyle:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                  ],
                  GhostButton(
                    label: 'إضافة قياس',
                    height: 44,
                    fontSize: 15,
                    color: RC.cyan.withValues(alpha: .4),
                    onTap: _addWeight,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionLabel('الحفاضات — آخر 24 ساعة'),
            const SizedBox(height: 10),
            RubaCard(
              shadowOpacity: .09,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _counter('${app.diapers.wet}', 'مبللة'),
                      _counter('${app.diapers.dirty}', 'متسخة'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: '+ مبللة',
                          height: 44,
                          fontSize: 15,
                          color: RC.cyan.withValues(alpha: .4),
                          onTap: () => app.addDiaper('wet'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GhostButton(
                          label: '+ متسخة',
                          height: 44,
                          fontSize: 15,
                          color: RC.cyan.withValues(alpha: .4),
                          onTap: () => app.addDiaper('dirty'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ستّ حفاضات مبللة يومياً فأكثر مؤشر معتاد على كفاية الرضاعة. '
                    'راجع الطبيب إن قلّت.',
                    style: TextStyle(fontSize: 13, color: RC.ink4, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLead() async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: RC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('مهلة التنبيه قبل الموعد', style: TextStyle(fontSize: 19)),
        children: [
          for (final m in [0, 5, 10, 15, 20, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m == 0 ? 'في الموعد تماماً' : '$m دقيقة',
                  style: const TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
    if (v == null) return;
    setState(() => _draft = _draft.copyWith(reminderLeadMin: v));
  }

  Widget _tapRow(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(value, style: const TextStyle(fontSize: 16, color: RC.ink3)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded, size: 20, color: RC.ink6),
              ],
            ),
          ],
        ),
      );

  Widget _counter(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 13, color: RC.ink4)),
        ],
      );

  Widget _round(String glyph, VoidCallback onTap) => Material(
        color: RC.surface,
        shape: CircleBorder(side: BorderSide(color: RC.hair(.14))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(child: Text(glyph, style: const TextStyle(fontSize: 20))),
          ),
        ),
      );
}
