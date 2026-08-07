import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class _StatsData {
  final List<Bar> bars;
  final int goal;
  final int avgDaily;
  final double avgFeedsPerDay;
  final int avgFeedMl;
  final Duration longestGap;

  const _StatsData({
    required this.bars,
    required this.goal,
    required this.avgDaily,
    required this.avgFeedsPerDay,
    required this.avgFeedMl,
    required this.longestGap,
  });
}

/// الإحصائيات: الكمية اليومية مقابل الهدف، أرقام ملخّصة، منحنى الوزن، والتزام العلاجات.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  bool _month = false;

  @override
  void initState() {
    super.initState();
    AppState.I.addListener(_onChange);
  }

  @override
  void dispose() {
    AppState.I.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<_StatsData> _load() async {
    final app = AppState.I;
    final c = app.current!;
    final hour = Settings.I.dayStartHour;
    final days = _month ? 30 : 7;
    final now = DateTime.now();
    final todayStart = dayStartFor(now, hour);
    final from = todayStart.subtract(Duration(days: days - 1));
    final to = todayStart.add(const Duration(days: 1));

    final totals = await app.repo.dailyTotals(c.id, from, to, hour);
    final counts = await app.repo.dailyCounts(c.id, from, to, hour);
    final feeds = await app.repo.feedings(c.id, from, to);

    final bars = <Bar>[];
    var sum = 0, daysWithData = 0, feedCount = 0;
    for (var i = days - 1; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      final total = totals[d.millisecondsSinceEpoch] ?? 0;
      final n = counts[d.millisecondsSinceEpoch] ?? 0;
      if (total > 0) {
        sum += total;
        daysWithData++;
      }
      feedCount += n;
      // في عرض الشهر نُظهر رقم اليوم كل خمسة أيام فقط كي لا تتزاحم التسميات.
      final label = _month ? (i % 5 == 0 ? '${d.day}' : '') : dowShort(d);
      bars.add((label: label, value: total));
    }

    var longest = Duration.zero;
    for (var i = 1; i < feeds.length; i++) {
      final gap = feeds[i].at.difference(feeds[i - 1].at);
      if (gap > longest) longest = gap;
    }

    return _StatsData(
      bars: bars,
      goal: c.goalMl,
      avgDaily: daysWithData == 0 ? 0 : (sum / daysWithData).round(),
      avgFeedsPerDay: daysWithData == 0 ? 0 : feedCount / daysWithData,
      avgFeedMl: feedCount == 0 ? 0 : (sum / feedCount).round(),
      longestGap: longest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    if (app.current == null) return const SizedBox.shrink();

    return FutureBuilder<_StatsData>(
      future: _load(),
      builder: (context, snap) {
        final d = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإحصائيات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: RC.muted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _rangeBtn('أسبوع', !_month, () => setState(() => _month = false)),
                      _rangeBtn('شهر', _month, () => setState(() => _month = true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RubaCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الكمية اليومية مقابل الهدف',
                      style: TextStyle(fontSize: 14, color: RC.ink4)),
                  const SizedBox(height: 12),
                  if (d != null)
                    DailyBars(bars: d.bars, goal: d.goal)
                  else
                    const SizedBox(height: 150),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _stat('${d?.avgDaily ?? 0} مل', 'المتوسط اليومي'),
                _stat((d?.avgFeedsPerDay ?? 0).toStringAsFixed(1), 'متوسط عدد الرضعات'),
                _stat('${d?.avgFeedMl ?? 0} مل', 'متوسط حجم الرضعة'),
                _stat(_gapLabel(d?.longestGap ?? Duration.zero),
                    'أطول فاصل بين رضعتين'),
              ],
            ),
            const SizedBox(height: 12),
            RubaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('منحنى الوزن',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  WeightCurve(
                    values: app.weights.reversed.map((w) => w.kg).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        app.weights.isEmpty
                            ? '—'
                            : '${app.weights.last.kg} كغ · ${shortDayLabel(app.weights.last.at)}',
                        style: const TextStyle(fontSize: 12.5, color: RC.ink4),
                      ),
                      Text(
                        app.weights.isEmpty
                            ? '—'
                            : '${app.weights.first.kg} كغ · ${shortDayLabel(app.weights.first.at)}',
                        style: const TextStyle(fontSize: 12.5, color: RC.ink4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (app.medViews.isNotEmpty)
              RubaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('التزام العلاجات',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final v in app.medViews) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(v.med.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.5)),
                          ),
                          Text('${v.adherencePct}%',
                              style: const TextStyle(fontSize: 14.5, color: RC.ink3)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ThinBar(
                        value: v.adherencePct / 100,
                        height: 5,
                        color: v.adherencePct >= 90 ? RC.cyan : RC.amberLine,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 6),
            GhostButton(
              label: 'تصدير تقرير للطبيب',
              icon: Icons.picture_as_pdf_rounded,
              height: 52,
              fontSize: 16.5,
              onTap: () async {
                flash(context, 'جارٍ تجهيز تقرير آخر 30 يوماً');
                try {
                  await ReportService.shareReport();
                } catch (e) {
                  if (context.mounted) flash(context, 'تعذّر تجهيز التقرير: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _rangeBtn(String label, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: on ? RC.card : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              color: on ? RC.ink : RC.ink4,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );

  Widget _stat(String value, String label) => RubaCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        shadowOpacity: .08,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 13, color: RC.ink4, height: 1.4)),
          ],
        ),
      );

  String _gapLabel(Duration d) {
    if (d == Duration.zero) return '—';
    final h = d.inHours, m = d.inMinutes % 60;
    return h == 0 ? '$m د' : '$h س $m د';
  }
}
