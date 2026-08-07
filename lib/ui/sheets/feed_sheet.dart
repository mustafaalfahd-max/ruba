import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';

/// ورقة تسجيل الرضعة. الهدف: ضغطتان من فتح التطبيق إلى حفظ الرضعة.
Future<void> openFeedSheet(
  BuildContext context, {
  Feeding? existing,
  DateTime? initialAt,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // حجاب أسود ثابت — RC.ink يصبح فاتحاً في الوضع الداكن فيبيّض الشاشة.
      barrierColor: Colors.black.withValues(alpha: .38),
      builder: (_) => _FeedSheet(existing: existing, initialAt: initialAt),
    );

class _FeedSheet extends StatefulWidget {
  const _FeedSheet({this.existing, this.initialAt});

  final Feeding? existing;
  final DateTime? initialAt;

  @override
  State<_FeedSheet> createState() => _FeedSheetState();
}

class _FeedSheetState extends State<_FeedSheet> {
  late String _ml = widget.existing?.ml.toString() ?? '';
  late DateTime _at = widget.existing?.at ?? widget.initialAt ?? DateTime.now();
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _noteOpen = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _noteOpen = (widget.existing?.note ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        _ml = _ml.isEmpty ? '' : _ml.substring(0, _ml.length - 1);
      } else if (key == 'C') {
        _ml = '';
      } else if (_ml.length < 4) {
        _ml = _ml == '0' ? key : _ml + key;
      }
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (t == null) return;
    setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final ml = int.tryParse(_ml) ?? 0;
    if (ml <= 0) {
      flash(context, 'أدخل الكمية أولاً');
      return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final app = AppState.I;
    if (_isEdit) {
      await app.editFeeding(Feeding(
        id: widget.existing!.id,
        childId: widget.existing!.childId,
        at: _at,
        ml: ml,
        note: note,
      ));
    } else {
      await app.addFeeding(ml, _at, note);
    }
    if (!mounted) return;
    Navigator.pop(context);
    flash(context, _isEdit ? 'حُدّثت الرضعة' : 'حُفظت الرضعة · $ml مل');
  }

  @override
  Widget build(BuildContext context) {
    final quick = Settings.I.quickMl;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: RC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RC.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? 'تعديل الرضعة' : 'تسجيل رضعة',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء',
                        style: TextStyle(color: RC.ink4, fontSize: 15)),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < quick.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    PillButton(
                      label: '${quick[i]}',
                      selected: _ml == '${quick[i]}',
                      expand: true,
                      onTap: () => setState(() => _ml = '${quick[i]}'),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _ml.isEmpty ? '0' : _ml,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: _ml.isEmpty ? RC.ghost : RC.ink,
                      fontFeatures: tabular.fontFeatures,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('مل', style: TextStyle(fontSize: 19, color: RC.ink4)),
                ],
              ),
              SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  for (final k in keys)
                    Material(
                      color: RC.card,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      child: InkWell(
                        onTap: () => _press(k),
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: k == '⌫'
                              ? Icon(Icons.backspace_outlined, size: 21, color: RC.ink)
                              : Text(k, style: TextStyle(fontSize: 23, color: RC.ink)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: RC.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 21, color: RC.cyan),
                        SizedBox(width: 9),
                        Text('الوقت', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    TextButton(
                      onPressed: _pickTime,
                      child: Text(
                        hhmm(_at),
                        style: TextStyle(
                          fontSize: 18,
                          color: RC.ink,
                          fontFeatures: tabular.fontFeatures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() => _noteOpen = !_noteOpen),
                  icon: Icon(
                    _noteOpen ? Icons.keyboard_arrow_up_rounded : Icons.edit_note_rounded,
                    size: 18,
                    color: RC.cyanDark,
                  ),
                  label: Text('ملاحظة',
                      style: TextStyle(color: RC.cyanDark, fontSize: 15)),
                ),
              ),
              if (_noteOpen) ...[
                const SizedBox(height: 4),
                FilledField(
                  controller: _note,
                  hint: 'مثلاً: تقيّأت قليلاً بعدها',
                  fontSize: 16,
                ),
              ],
              const SizedBox(height: 14),
              PrimaryButton(label: 'حفظ الرضعة', onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}
