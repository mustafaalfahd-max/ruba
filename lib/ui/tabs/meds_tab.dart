import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../screens/med_detail_screen.dart';
import '../screens/med_form_screen.dart';
import '../sheets/dose_dialog.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// أيقونة لكل شكل دوائي.
IconData medFormIcon(String form) => switch (form) {
      'قطرات' => Icons.water_drop_rounded,
      'حبوب' => Icons.medication_rounded,
      'تحاميل' => Icons.vaccines_rounded,
      'بخاخ' => Icons.air_rounded,
      _ => Icons.medication_liquid_rounded,
    };

class MedsTab extends StatelessWidget {
  const MedsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    final active = app.medViews.where((v) => !v.med.ended).toList();
    final done = app.medViews.where((v) => v.med.ended).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('العلاجات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: RC.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedFormScreen()),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('نشطة'),
        const SizedBox(height: 10),
        if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'لا توجد علاجات نشطة لهذا الطفل.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: RC.ink4),
            ),
          )
        else
          for (final v in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActiveMedCard(view: v),
            ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionLabel('منتهية'),
          const SizedBox(height: 10),
          for (final v in done)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EndedMedCard(view: v),
            ),
        ],
      ],
    );
  }
}

class _ActiveMedCard extends StatelessWidget {
  const _ActiveMedCard({required this.view});

  final MedView view;

  @override
  Widget build(BuildContext context) {
    final m = view.med;
    final tagColors = switch (m.type) {
      MedType.course => (bg: RC.cyanWash, fg: RC.cyanDark),
      MedType.prn => (bg: RC.magentaWash, fg: RC.magentaDark),
      MedType.permanent => (bg: RC.surface, fg: RC.ink3),
    };

    return RubaCard(
      onTap: () {
        if (m.isPrn) {
          // «عند اللزوم» لا موعد لها — الضغط يعني تسجيل جرعة الآن مع فحص التباعد.
          showDoseDialog(context, view: view, scheduledAt: DateTime.now());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MedDetailScreen(medId: m.id)),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(medFormIcon(m.form), size: 26, color: RC.magenta),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${trimDose(m.dose)} ${m.unit} · '
                      '${m.isPrn ? 'عند اللزوم' : perDayLabel(m.perDay)}',
                      style: const TextStyle(fontSize: 14, color: RC.ink4),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  medTypeLabel(m.type),
                  style: TextStyle(fontSize: 12.5, color: tagColors.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (m.isCourse) ...[
            ThinBar(value: view.coursePct),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${view.givenTotal} من ${m.totalDoses} جرعة',
                    style: const TextStyle(fontSize: 13, color: RC.ink4)),
                Text(_nextLine(), style: const TextStyle(fontSize: 13, color: RC.ink4)),
              ],
            ),
          ] else if (m.isPrn)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: view.prnAvailable ? RC.cyanWash : RC.amberWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _prnLine(),
                style: TextStyle(
                  fontSize: 14.5,
                  color: view.prnAvailable ? RC.cyanDark : RC.amberInk,
                ),
              ),
            )
          else
            Text(_nextLine(), style: const TextStyle(fontSize: 13.5, color: RC.ink4)),
        ],
      ),
    );
  }

  String _nextLine() {
    final now = DateTime.now();
    for (final d in view.today) {
      if (!d.recorded && d.at.isAfter(now)) return 'القادمة ${hhmm(d.at)}';
    }
    for (final d in view.today) {
      if (!d.recorded) return 'مستحقة الآن ${hhmm(d.at)}';
    }
    return 'اكتملت جرعات اليوم';
  }

  String _prnLine() {
    final since = view.sinceLast;
    if (since == null) return 'لم تُعطَ بعد — متاح الآن';
    final ago = hoursLabel(since.inHours);
    if (view.prnAvailable) return 'آخر جرعة قبل $ago — متاح الآن';
    final left = (view.prnRemaining.inMinutes / 60).ceil();
    return 'آخر جرعة قبل $ago — متاح بعد ${hoursLabel(left)}';
  }
}

class _EndedMedCard extends StatelessWidget {
  const _EndedMedCard({required this.view});

  final MedView view;

  @override
  Widget build(BuildContext context) {
    final m = view.med;
    return Opacity(
      opacity: .75,
      child: RubaCard(
        color: RC.mutedDeep,
        shadowOpacity: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MedDetailScreen(medId: m.id)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${trimDose(m.dose)} ${m.unit} · ${medTypeLabel(m.type)}',
                    style: const TextStyle(fontSize: 13.5, color: RC.ink4),
                  ),
                ],
              ),
            ),
            Text(
              m.endedAt == null ? 'منتهٍ' : 'اكتمل ${shortDayLabel(m.endedAt!)}',
              style: const TextStyle(fontSize: 13, color: RC.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
