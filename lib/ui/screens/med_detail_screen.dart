import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';
import 'med_form_screen.dart';

/// تفاصيل العلاج: نسبة الالتزام، إجراءات، وسجل الجرعات كاملاً.
class MedDetailScreen extends StatelessWidget {
  const MedDetailScreen({super.key, required this.medId});

  final int medId;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        MedView? view;
        for (final v in app.medViews) {
          if (v.med.id == medId) view = v;
        }
        if (view == null) {
          return const StackScaffold(
            title: 'تفاصيل العلاج',
            child: Center(child: Text('حُذف هذا العلاج')),
          );
        }
        final m = view.med;

        return StackScaffold(
          title: 'تفاصيل العلاج',
          actionLabel: 'تعديل',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MedFormScreen(existing: m)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              RubaCard(
                padding: const EdgeInsets.all(18),
                shadowOpacity: .09,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الالتزام الإجمالي',
                            style: TextStyle(fontSize: 15, color: RC.ink4)),
                        Text(
                          '${view.adherencePct}%',
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w600, color: RC.cyan),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ThinBar(value: view.adherencePct / 100, height: 7),
                    const SizedBox(height: 12),
                    Text(
                      _meta(m, view),
                      style: const TextStyle(fontSize: 14.5, color: RC.ink3, height: 1.6),
                    ),
                  ],
                ),
              ),
              if ((m.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                RubaCard(
                  shadowOpacity: .07,
                  child: Text(m.note!,
                      style: const TextStyle(fontSize: 15, color: RC.ink3, height: 1.7)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'تعديل',
                      height: 46,
                      fontSize: 15.5,
                      color: RC.hair(.14),
                      textColor: RC.ink2,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MedFormScreen(existing: m)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: m.remind ? 'إيقاف التذكير' : 'استئناف التذكير',
                      height: 46,
                      fontSize: 15.5,
                      color: RC.hair(.14),
                      textColor: RC.ink2,
                      onTap: () async {
                        await app.saveMedication(m.copyWith(remind: !m.remind));
                        if (context.mounted) {
                          flash(context,
                              m.remind ? 'أُوقف تذكير ${m.name}' : 'استُؤنف تذكير ${m.name}');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: m.ended ? 'إعادة تفعيل' : 'إنهاء',
                      height: 46,
                      fontSize: 15.5,
                      color: RC.magentaDark.withValues(alpha: .5),
                      textColor: RC.magentaDark,
                      onTap: () async {
                        if (!m.ended) {
                          final ok = await confirm(
                            context,
                            title: 'إنهاء العلاج',
                            message:
                                'سينتقل ${m.name} إلى قائمة المنتهية وتتوقّف تذكيراته. '
                                'سجل الجرعات يبقى محفوظاً.',
                            confirmLabel: 'إنهاء',
                            confirmColor: RC.magentaDark,
                          );
                          if (!ok) return;
                        }
                        await app.endMedication(m.id, !m.ended);
                        if (context.mounted) {
                          flash(context, m.ended ? 'أُعيد تفعيل العلاج' : 'أُنهي العلاج');
                          if (!m.ended) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('سجل الجرعات'),
              const SizedBox(height: 10),
              _DoseLog(medId: medId),
            ],
          ),
        );
      },
    );
  }

  String _meta(Medication m, MedView v) {
    final head = '${m.name} · ${trimDose(m.dose)} ${m.unit}';
    if (m.isCourse) {
      return '$head · ${v.givenTotal} من ${m.totalDoses} جرعة · '
          'ينتهي ${shortDayLabel(m.endDate)}';
    }
    if (m.isPrn) {
      final since = v.sinceLast;
      return '$head · عند اللزوم · بحد أدنى ${hoursLabel(m.minGapHours)} بين الجرعتين'
          '${since == null ? '' : ' · آخر جرعة قبل ${hoursLabel(since.inHours)}'}';
    }
    return '$head · ${perDayLabel(m.perDay)}';
  }
}

class _DoseLog extends StatelessWidget {
  const _DoseLog({required this.medId});

  final int medId;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return FutureBuilder<List<MedDose>>(
      future: app.repo.doses(medId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final doses = snap.data!;
        if (doses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'لم تُسجَّل أي جرعة بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: RC.ink4),
            ),
          );
        }
        final today = dayStartFor(DateTime.now(), Settings.I.dayStartHour);
        return Column(
          children: [
            for (final d in doses)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _row(d, today),
              ),
          ],
        );
      },
    );
  }

  Widget _row(MedDose d, DateTime today) {
    final colors = doseStatusColors(d.status);
    final at = d.takenAt ?? d.scheduledAt;
    final dayDiff = today.difference(dayStartFor(at, Settings.I.dayStartHour)).inDays;
    final dayLabel = switch (dayDiff) {
      0 => 'اليوم',
      1 => 'أمس',
      2 => 'قبل يومين',
      _ => shortDayLabel(at),
    };

    return Container(
      decoration: BoxDecoration(
        color: RC.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: RC.shadow(.06),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colors.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(dayLabel, style: const TextStyle(fontSize: 15, color: RC.ink4)),
          ),
          Expanded(
            child: Text(
              hhmm(at),
              style: TextStyle(fontSize: 16.5, fontFeatures: tabular.fontFeatures),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              doseStatusLabel(d.status),
              style: TextStyle(fontSize: 13, color: colors.fg),
            ),
          ),
        ],
      ),
    );
  }
}
