import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../sheets/dose_dialog.dart';
import '../sheets/feed_sheet.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// لوحة اليوم — كل ما يهم مرئي بلا تمرير: كم أُعطي، كم بقي، ومتى الرضعة والجرعة القادمة.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // العدّاد التنازلي يتحدّث كل ثانية؛ بقية الشاشة تُعاد بناءً على AppState.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // المؤقّت أعلاه يعيد البناء كل ثانية، لكن الاعتماد عليه وحده يعني
      // تأخّر ظهور الرضعة المحفوظة حتى الدقّة التالية. نستمع للحالة صراحةً.
      ListenableBuilder(listenable: AppState.I, builder: (context, _) => _body(context));

  Widget _body(BuildContext context) {
    final app = AppState.I;
    if (app.current == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Center(
          child: ProgressRing(
            value: app.pct,
            color: app.ringColor,
            kicker: app.goalReached ? 'اكتمل الهدف' : 'بقي',
            big: app.goalReached ? '${app.goalToday} مل' : '${app.leftToday} مل',
            sub: '${app.totalToday} من ${app.goalToday}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.opacity_rounded, size: 18, color: RC.cyan),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                app.splitLine,
                style: const TextStyle(fontSize: 15, color: RC.ink3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _NextFeedCard(),
        const SizedBox(height: 12),
        if (app.nextDose != null) ...[
          _NextDoseCard(dose: app.nextDose!),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('قائمة اليوم',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text(
                '${feedsCountLabel(app.todayFeeds.length)} · '
                '${dosesCountLabel(app.doseCountToday)}',
                style: const TextStyle(fontSize: 13, color: RC.ink4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (app.timeline.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Text(
              'لم تُسجَّل أي رضعة اليوم بعد — اضغط زر «+».',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: RC.ink4),
            ),
          )
        else
          for (final e in app.timeline)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _TimelineRow(entry: e),
            ),
      ],
    );
  }
}

class _NextFeedCard extends StatelessWidget {
  const _NextFeedCard();

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    final next = app.nextFeedAt;
    final late = app.feedLate;
    final diff = next.difference(DateTime.now());

    return RubaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: late ? RC.amberWash : RC.card,
      outline: late ? RC.amberLine : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.child_care_rounded, size: 26, color: RC.cyan),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    late ? 'تأخّرت الرضعة' : 'الرضعة القادمة',
                    style: const TextStyle(fontSize: 13, color: RC.ink4),
                  ),
                  Text(
                    hhmm(next),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                late ? 'متأخرة منذ' : 'بعد',
                style: const TextStyle(fontSize: 12, color: RC.ink4),
              ),
              Text(
                countdownLabel(diff),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: late ? RC.amber : RC.ink,
                  fontFeatures: tabular.fontFeatures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({required this.dose});

  final ({MedView view, DateTime at}) dose;

  @override
  Widget build(BuildContext context) {
    final med = dose.view.med;
    return RubaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.medication_rounded, size: 26, color: RC.magenta),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${trimDose(med.dose)} ${med.unit} · ${hhmm(dose.at)}',
                        style: const TextStyle(fontSize: 14, color: RC.ink4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: RC.cyanWash,
            shape: const CircleBorder(side: BorderSide(color: RC.cyan, width: 1.5)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showDoseDialog(context, view: dose.view, scheduledAt: dose.at),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.check_rounded, size: 24, color: RC.cyanDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return Container(
      decoration: BoxDecoration(
        color: RC.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: RC.shadow(.07),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: entry.isFeed
                  ? () {
                      Feeding? found;
                      for (final f in app.todayFeeds) {
                        if (f.id == entry.refId) {
                          found = f;
                          break;
                        }
                      }
                      if (found != null) openFeedSheet(context, existing: found);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        hhmm(entry.at),
                        style: TextStyle(
                          fontSize: 15,
                          color: RC.ink4,
                          fontFeatures: tabular.fontFeatures,
                        ),
                      ),
                    ),
                    Icon(
                      entry.isFeed ? Icons.local_drink_rounded : Icons.medication_rounded,
                      size: 21,
                      color: entry.isFeed ? RC.cyan : RC.magenta,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    Text(
                      entry.amount,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: entry.isFeed ? RC.ink : RC.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (entry.isFeed)
            IconButton(
              onPressed: () async {
                await app.removeFeeding(entry.refId);
                if (context.mounted) flash(context, 'حُذفت الرضعة');
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: RC.magentaDark,
              tooltip: 'حذف',
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
