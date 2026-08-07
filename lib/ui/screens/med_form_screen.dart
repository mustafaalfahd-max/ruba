import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';

const _forms = ['شراب', 'حبوب', 'قطرات', 'تحاميل', 'بخاخ'];
const _units = ['مل', 'ملغم', 'نقطة'];

/// يوزّع مواعيد اليوم بالتساوي بدءاً من الثامنة صباحاً.
/// عند تفعيل «تجنّب ساعات النوم» تُزاح المواعيد الواقعة داخل نافذة الهدوء إلى نهايتها.
List<String> suggestTimes(
  int perDay, {
  required bool avoidSleep,
  required String quietFrom,
  required String quietTo,
}) {
  final step = (1440 / perDay).round();
  final out = <String>[];
  final from = minutesOf(quietFrom), to = minutesOf(quietTo);

  bool inQuiet(int m) => from <= to ? (m >= from && m < to) : (m >= from || m < to);

  for (var i = 0; i < perDay; i++) {
    var m = (480 + i * step) % 1440;
    if (avoidSleep && inQuiet(m)) {
      m = to;
      // تفادي تكرار الموعد نفسه لو وقع أكثر من جرعة داخل نافذة الهدوء.
      while (out.contains(hhmmFromMinutes(m))) {
        m = (m + 30) % 1440;
      }
    }
    out.add(hhmmFromMinutes(m));
  }
  return out;
}

/// إضافة علاج أو تعديله. الحقول المعروضة تتغيّر حسب نوع العلاج المختار.
class MedFormScreen extends StatefulWidget {
  const MedFormScreen({super.key, this.existing});

  final Medication? existing;

  @override
  State<MedFormScreen> createState() => _MedFormScreenState();
}

class _MedFormScreenState extends State<MedFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _dose = TextEditingController(
      text: widget.existing == null ? '' : trimDoseText(widget.existing!.dose));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  late String _form = widget.existing?.form ?? 'شراب';
  late String _unit = widget.existing?.unit ?? 'مل';
  late MedType _type = widget.existing?.type ?? MedType.course;
  late int _perDay = widget.existing?.perDay ?? 3;
  late int _days = widget.existing?.days ?? 7;
  late int _minGap = widget.existing?.minGapHours ?? 6;
  late int _maxDay = widget.existing?.maxPerDay ?? 4;
  late bool _avoidSleep = widget.existing?.avoidSleep ?? true;
  late bool _remind = widget.existing?.remind ?? true;
  late List<String> _times = List.of(widget.existing?.times ?? const []);

  @override
  void initState() {
    super.initState();
    if (_times.isEmpty) _regenerateTimes();
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    super.dispose();
  }

  void _regenerateTimes() {
    final c = AppState.I.current;
    _times = suggestTimes(
      _perDay,
      avoidSleep: _avoidSleep,
      quietFrom: c?.quietFrom ?? '23:00',
      quietTo: c?.quietTo ?? '05:00',
    );
  }

  void _setPerDay(int v) {
    setState(() {
      _perDay = v.clamp(1, 6);
      _regenerateTimes();
    });
  }

  Future<void> _pickTime(int i) async {
    final t = await showTimePicker(
      context: context,
      initialTime: timeOfDayFrom(_times[i]),
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (t == null) return;
    setState(() => _times[i] = t.hhmmText);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      flash(context, 'اكتب اسم الدواء');
      return;
    }
    final dose = double.tryParse(_dose.text.trim()) ?? 0;
    if (dose <= 0) {
      flash(context, 'أدخل مقدار الجرعة');
      return;
    }
    final child = AppState.I.current;
    if (child == null) return;

    final m = Medication(
      id: widget.existing?.id ?? 0,
      childId: child.id,
      name: name,
      form: _form,
      dose: dose,
      unit: _unit,
      type: _type,
      perDay: _type == MedType.prn ? 0 : _perDay,
      days: _days,
      minGapHours: _minGap,
      maxPerDay: _maxDay,
      startAt: widget.existing?.startAt ?? DateTime.now(),
      avoidSleep: _avoidSleep,
      remind: _remind,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ended: widget.existing?.ended ?? false,
      endedAt: widget.existing?.endedAt,
      times: _type == MedType.prn ? const [] : _times.take(_perDay).toList(),
    );

    await AppState.I.saveMedication(m);
    if (!mounted) return;
    Navigator.pop(context);
    flash(context, widget.existing == null ? 'أُضيف $name' : 'حُدّث $name');
  }

  @override
  Widget build(BuildContext context) {
    final isPrn = _type == MedType.prn;
    return StackScaffold(
      title: widget.existing == null ? 'إضافة علاج' : 'تعديل علاج',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _label('اسم الدواء'),
          FilledField(controller: _name, hint: 'مثلاً: أوجمنتين 625'),
          const SizedBox(height: 16),
          _label('الشكل'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final f in _forms)
                PillButton(
                  label: f,
                  selected: _form == f,
                  onTap: () => setState(() => _form = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('مقدار الجرعة'),
          SizedBox(
            width: 170,
            child: FilledField(
              controller: _dose,
              hint: '5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(height: 16),
          _label('الوحدة'),
          // أزرار بعرضها الطبيعي داخل Wrap — حشرها في نصف عرض الشاشة
          // كان يلفّ نصوصها إلى سطرين («ملغ / م»).
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final u in _units)
                PillButton(
                  label: u,
                  selected: _unit == u,
                  onTap: () => setState(() => _unit = u),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('النوع'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final t in MedType.values)
                PillButton(
                  label: medTypeLabel(t),
                  selected: _type == t,
                  onTap: () => setState(() {
                    _type = t;
                    if (t != MedType.prn) _regenerateTimes();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          RubaCard(
            shadowOpacity: .08,
            child: Column(
              children: [
                if (isPrn) ...[
                  StepperRow(
                    label: 'الحد الأدنى بين الجرعتين (ساعة)',
                    value: '$_minGap',
                    onDec: () => setState(() => _minGap = (_minGap - 1).clamp(1, 24)),
                    onInc: () => setState(() => _minGap = (_minGap + 1).clamp(1, 24)),
                  ),
                  const SizedBox(height: 14),
                  StepperRow(
                    label: 'الحد الأقصى يومياً',
                    value: '$_maxDay',
                    onDec: () => setState(() => _maxDay = (_maxDay - 1).clamp(1, 8)),
                    onInc: () => setState(() => _maxDay = (_maxDay + 1).clamp(1, 8)),
                  ),
                ] else ...[
                  StepperRow(
                    label: 'عدد المرات يومياً',
                    value: '$_perDay',
                    onDec: () => _setPerDay(_perDay - 1),
                    onInc: () => _setPerDay(_perDay + 1),
                  ),
                  if (_type == MedType.course) ...[
                    const SizedBox(height: 14),
                    StepperRow(
                      label: 'مدة الكورس (يوم)',
                      value: '$_days',
                      onDec: () => setState(() => _days = (_days - 1).clamp(1, 30)),
                      onInc: () => setState(() => _days = (_days + 1).clamp(1, 30)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: RC.cyanWash,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        'تاريخ الانتهاء المحسوب: '
                        '${shortDayLabel((widget.existing?.startAt ?? DateTime.now()).add(Duration(days: _days)))}'
                        ' · ${_perDay * _days} جرعة',
                        style: const TextStyle(fontSize: 14.5, color: RC.cyanDark),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (!isPrn) ...[
            const SizedBox(height: 16),
            _label('المواعيد المقترحة'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _times.length && i < _perDay; i++)
                  InkWell(
                    onTap: () => _pickTime(i),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: RC.card,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: RC.shadow(.07),
                      ),
                      child: Text(
                        _times[i],
                        style: TextStyle(
                          fontSize: 17,
                          color: RC.ink,
                          fontFeatures: tabular.fontFeatures,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          RubaCard(
            shadowOpacity: .08,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (!isPrn)
                  _toggleRow('تجنّب ساعات النوم', _avoidSleep, (v) {
                    setState(() {
                      _avoidSleep = v;
                      _regenerateTimes();
                    });
                  }),
                _toggleRow('تذكير بالجرعة', _remind, (v) => setState(() => _remind = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledField(controller: _note, hint: 'ملاحظة — اختياري', fontSize: 16),
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ العلاج', onTap: _save),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14, color: RC.ink4)),
      );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            RubaSwitch(value: value, onChanged: onChanged),
          ],
        ),
      );
}

String trimDoseText(double d) =>
    d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
