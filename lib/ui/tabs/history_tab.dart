import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../sheets/feed_sheet.dart';
import '../widgets/common.dart';

class _DayData {
  final int total;
  final int feedCount;
  final int goal;
  final List<TimelineEntry> entries;

  const _DayData({
    required this.total,
    required this.feedCount,
    required this.goal,
    required this.entries,
  });
}

/// السجل: تنقّل بين الأيام، ملخص اليوم، وعرض شهري ملوّن حسب بلوغ الهدف.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  int _offset = 0; // 0 = اليوم
  bool _monthOpen = false;
  Map<int, int> _monthTotals = const {};

  @override
  void initState() {
    super.initState();
    AppState.I.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    AppState.I.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _selectedStart =>
      dayStartOffset(DateTime.now(), Settings.I.dayStartHour, _offset);

  Future<_DayData> _load() async {
    final app = AppState.I;
    final c = app.current;
    if (c == null) {
      return const _DayData(total: 0, feedCount: 0, goal: 0, entries: []);
    }
    final from = _selectedStart, to = from.add(const Duration(days: 1));
    final feeds = await app.repo.feedings(c.id, from, to);
    final goal = await app.repo.goalOn(c.id, to, c.goalMl);
    final doses = await app.repo.childDosesInRange(c.id, from, to);

    final entries = <TimelineEntry>[
      for (final f in feeds)
        TimelineEntry(isFeed: true, at: f.at, label: 'رضعة', amount: '${f.ml} مل', refId: f.id),
      for (final d in doses)
        if (d.dose.status == DoseStatus.given)
          TimelineEntry(
            isFeed: false,
            at: d.dose.takenAt ?? d.dose.scheduledAt,
            label: d.med.name,
            amount: '${trimDose(d.med.dose)} ${d.med.unit}',
            refId: d.med.id,
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return _DayData(
      total: feeds.fold(0, (a, f) => a + f.ml),
      feedCount: feeds.length,
      goal: goal,
      entries: entries,
    );
  }

  Future<void> _loadMonth() async {
    final app = AppState.I;
    final c = app.current;
    if (c == null) return;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1, Settings.I.dayStartHour);
    final next = DateTime(now.year, now.month + 1, 1, Settings.I.dayStartHour);
    final totals = await app.repo.dailyTotals(c.id, first, next, Settings.I.dayStartHour);
    final byDay = <int, int>{};
    totals.forEach((ms, ml) {
      byDay[DateTime.fromMillisecondsSinceEpoch(ms).day] = ml;
    });
    if (mounted) setState(() => _monthTotals = byDay);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    if (app.current == null) return const SizedBox.shrink();

    return FutureBuilder<_DayData>(
      future: _load(),
      builder: (context, snap) {
        final d = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 110),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('السجل',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: () async {
                      setState(() => _monthOpen = !_monthOpen);
                      if (_monthOpen) await _loadMonth();
                    },
                    icon: const Icon(Icons.calendar_month_rounded,
                        size: 22, color: RC.cyan),
                    label: Text(_monthOpen ? 'إغلاق' : 'الشهر',
                        style: const TextStyle(color: RC.cyan, fontSize: 15)),
                  ),
                ],
              ),
            ),
            if (_monthOpen) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _monthCard(d?.goal ?? app.goalToday),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 66,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, i) {
                  final day = dayStartOffset(DateTime.now(), Settings.I.dayStartHour, i);
                  final on = _offset == i;
                  return InkWell(
                    onTap: () => setState(() => _offset = i),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: on ? RC.cyan : RC.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: RC.shadow(.08),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dowShort(day),
                            style: TextStyle(
                              fontSize: 12,
                              color: on ? Colors.white70 : RC.ink3,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: on ? Colors.white : RC.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RubaCard(
                child: Row(
                  children: [
                    _summary('${d?.total ?? 0} مل', 'المجموع', RC.ink),
                    _summary('${d?.feedCount ?? 0}', 'رضعات', RC.ink),
                    _summary(
                      d == null || d.goal == 0
                          ? '—'
                          : '${(d.total / d.goal * 100).round()}%',
                      'من الهدف',
                      d != null && d.goal > 0 && d.total >= d.goal ? RC.gold : RC.cyan,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (d != null && d.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        'لا توجد سجلات في هذا اليوم.',
                        style: TextStyle(fontSize: 15, color: RC.ink4),
                      ),
                    ),
                  for (final e in d?.entries ?? const <TimelineEntry>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _histRow(context, e),
                    ),
                  const SizedBox(height: 6),
                  GhostButton(
                    label: 'إضافة رضعة سابقة',
                    dashed: true,
                    height: 50,
                    onTap: () => openFeedSheet(
                      context,
                      initialAt: _selectedStart.add(const Duration(hours: 6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(String value, String label, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 12.5, color: RC.ink4)),
          ],
        ),
      );

  Widget _histRow(BuildContext context, TimelineEntry e) => Container(
        decoration: BoxDecoration(
          color: RC.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: RC.shadow(.07),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                hhmm(e.at),
                style: TextStyle(
                    fontSize: 15, color: RC.ink4, fontFeatures: tabular.fontFeatures),
              ),
            ),
            Icon(
              e.isFeed ? Icons.local_drink_rounded : Icons.medication_rounded,
              size: 21,
              color: e.isFeed ? RC.cyan : RC.magenta,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17)),
            ),
            Text(e.amount,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _monthCard(int goal) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return RubaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(monthLabel(now),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            children: [
              for (var day = 1; day <= daysInMonth; day++)
                _monthCell(day, _monthTotals[day], goal, day > now.day),
            ],
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: RC.cyan, label: 'بلغ الهدف'),
              _Legend(color: RC.cyanPale, label: 'قريب منه'),
              _Legend(color: RC.magentaPale, label: 'ضعيف'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthCell(int day, int? total, int goal, bool future) {
    Color bg = RC.paper;
    Color fg = RC.ink3;
    if (!future && total != null && goal > 0) {
      final r = total / goal;
      if (r >= 1) {
        bg = RC.cyan;
        fg = Colors.white;
      } else if (r >= .8) {
        bg = RC.cyanPale;
      } else {
        bg = RC.magentaPale;
      }
    }
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text('$day', style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5, color: RC.ink4)),
        ],
      );
}
