import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/common.dart';

/// حوار تأكيد إعطاء الجرعة.
///
/// لعلاجات «عند اللزوم» يفحص الحد الأدنى بين الجرعتين والحد الأقصى اليومي،
/// ويطلب تأكيداً ثانياً صريحاً قبل السماح بجرعة مبكرة. تكرار خافض الحرارة قبل
/// موعده خطأ شائع ليلاً، ولذلك التحذير هنا صريح لا مجرد لون.
Future<void> showDoseDialog(
  BuildContext context, {
  required MedView view,
  required DateTime scheduledAt,
}) =>
    showDialog<void>(
      context: context,
      barrierColor: RC.ink.withValues(alpha: .42),
      builder: (_) => _DoseDialog(view: view, scheduledAt: scheduledAt),
    );

class _DoseDialog extends StatefulWidget {
  const _DoseDialog({required this.view, required this.scheduledAt});

  final MedView view;
  final DateTime scheduledAt;

  @override
  State<_DoseDialog> createState() => _DoseDialogState();
}

class _DoseDialogState extends State<_DoseDialog> {
  bool _confirmedOnce = false;

  Medication get _med => widget.view.med;

  /// جرعة مبكرة: لم تمضِ المدة الدنيا، أو تجاوزنا الحد الأقصى اليومي.
  bool get _tooEarly => _med.isPrn && !widget.view.prnAvailable;

  bool get _overDailyCap =>
      _med.isPrn && widget.view.givenLast24h >= _med.maxPerDay;

  bool get _needsExtraConfirm => _tooEarly || _overDailyCap;

  String get _warning {
    if (_tooEarly) {
      final r = widget.view.prnRemaining;
      final hours = (r.inMinutes / 60).ceil();
      return 'لم تمضِ المدة الدنيا بين الجرعتين '
          '(${hoursLabel(_med.minGapHours)}). '
          'متبقٍ ${hoursLabel(hours)} قبل الجرعة التالية المسموح بها.';
    }
    return 'أُعطيت ${dosesCountLabel(widget.view.givenLast24h)} خلال آخر 24 ساعة، '
        'وهذا يبلغ الحد الأقصى الذي أدخلته (${_med.maxPerDay}).';
  }

  Future<void> _give() async {
    if (_needsExtraConfirm && !_confirmedOnce) {
      setState(() => _confirmedOnce = true);
      return;
    }
    await AppState.I.recordDose(_med.id, widget.scheduledAt, DoseStatus.given);
    if (!mounted) return;
    Navigator.pop(context);
    flash(context, 'سُجّلت جرعة ${_med.name}');
  }

  Future<void> _skip() async {
    await AppState.I.recordDose(_med.id, widget.scheduledAt, DoseStatus.skipped);
    if (!mounted) return;
    Navigator.pop(context);
    flash(context, 'تم تخطّي الجرعة');
  }

  @override
  Widget build(BuildContext context) {
    final warn = _needsExtraConfirm;
    return Dialog(
      backgroundColor: RC.surface,
      insetPadding: const EdgeInsets.all(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تأكيد الجرعة',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: RC.card,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  KeyValueRow('الدواء', _med.name,
                      valueStyle: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  KeyValueRow('الكمية', '${trimDose(_med.dose)} ${_med.unit}'),
                  const SizedBox(height: 7),
                  KeyValueRow('الوقت', hhmm(widget.scheduledAt)),
                ],
              ),
            ),
            if (warn) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: RC.magentaWash,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 22, color: RC.magentaDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _warning,
                        style: const TextStyle(
                            fontSize: 15, height: 1.7, color: RC.magentaInk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'تخطّي',
                    color: RC.hair(.15),
                    textColor: RC.ink3,
                    fontSize: 17,
                    onTap: _skip,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: warn && !_confirmedOnce ? 'متابعة رغم التحذير' : 'أُعطيت',
                    height: 52,
                    fontSize: 17,
                    color: warn && !_confirmedOnce ? RC.magentaDark : RC.cyan,
                    onTap: _give,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
