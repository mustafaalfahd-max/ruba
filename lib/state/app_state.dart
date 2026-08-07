import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'settings.dart';

/// جرعة مجدولة في يوم معيّن مع حالتها.
typedef ScheduledDose = ({DateTime at, DoseStatus status, bool recorded});

/// كل ما تحتاجه الواجهة عن علاج واحد، محسوباً مرة واحدة عند التحديث.
class MedView {
  final Medication med;
  final int givenTotal;
  final DateTime? lastGiven;
  final int givenLast24h;
  final List<ScheduledDose> today;

  const MedView({
    required this.med,
    required this.givenTotal,
    required this.lastGiven,
    required this.givenLast24h,
    required this.today,
  });

  /// الوقت المنقضي منذ آخر جرعة — لعلاجات «عند اللزوم».
  Duration? get sinceLast => lastGiven == null ? null : DateTime.now().difference(lastGiven!);

  bool get prnAvailable {
    if (!med.isPrn) return true;
    final s = sinceLast;
    if (s == null) return true;
    return s.inMinutes >= med.minGapHours * 60;
  }

  /// ما تبقّى قبل السماح بالجرعة التالية.
  Duration get prnRemaining {
    final s = sinceLast;
    if (s == null) return Duration.zero;
    final left = med.minGapHours * 60 - s.inMinutes;
    return Duration(minutes: math.max(0, left));
  }

  double get coursePct {
    if (!med.isCourse || med.totalDoses == 0) return 0;
    return (givenTotal / med.totalDoses).clamp(0.0, 1.0);
  }

  /// نسبة الالتزام: للكورس نسبة المُعطى من المخطّط، ولغيره من المستحق حتى الآن.
  int get adherencePct {
    if (med.isCourse && med.totalDoses > 0) {
      return (givenTotal / med.totalDoses * 100).round();
    }
    final due = today.where((d) => d.status != DoseStatus.upcoming).length;
    if (due == 0) return 100;
    final given = today.where((d) => d.status == DoseStatus.given).length;
    return (given / due * 100).round();
  }
}

/// الحالة المشتركة للتطبيق. مصدر واحد للحقيقة، ويعيد التحميل من قاعدة البيانات بعد كل تغيير.
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState I = AppState._();

  final repo = Repo();

  bool ready = false;
  List<Child> children = const [];
  List<Child> archivedChildren = const [];
  int? currentId;

  List<Feeding> todayFeeds = const [];
  int goalToday = 700;
  List<MedView> medViews = const [];
  List<TimelineEntry> timeline = const [];
  ({int wet, int dirty}) diapers = (wet: 0, dirty: 0);
  List<WeightEntry> weights = const [];

  int get dayStartHour => Settings.I.dayStartHour;

  Child? get current {
    if (children.isEmpty) return null;
    return children.firstWhere((c) => c.id == currentId, orElse: () => children.first);
  }

  DateTime get dayStart => dayStartFor(DateTime.now(), dayStartHour);
  DateTime get dayEnd => dayStart.add(const Duration(days: 1));

  // ── القيم المشتقّة للشاشة الرئيسية ────────────────────────────────────────

  int get totalToday => todayFeeds.fold(0, (a, f) => a + f.ml);
  int get leftToday => math.max(0, goalToday - totalToday);
  double get pct => goalToday <= 0 ? 0 : math.min(1, totalToday / goalToday);
  bool get goalReached => totalToday >= goalToday && goalToday > 0;

  /// رمادي عند الصفر، يتشبّع نحو التركوازي مع التقدّم، وذهبي عند بلوغ الهدف.
  Color get ringColor =>
      goalReached ? RC.gold : Color.lerp(RC.ringStart, RC.cyan, pct)!;

  DateTime? get lastFeedAt => todayFeeds.isEmpty ? null : todayFeeds.last.at;

  DateTime get nextFeedAt {
    final c = current;
    final interval = Duration(minutes: c?.intervalMin ?? 150);
    final last = lastFeedAt;
    if (last == null) return DateTime.now().add(interval);
    return last.add(interval);
  }

  bool get feedLate => DateTime.now().isAfter(nextFeedAt);

  /// متوسط حجم الرضعة اليوم، أو 120 مل كتقدير أولي قبل أول رضعة.
  int get avgFeedMl =>
      todayFeeds.isEmpty ? 120 : math.max(1, (totalToday / todayFeeds.length).round());

  int get remainingFeeds => math.max(1, (leftToday / avgFeedMl).ceil());

  int get mlPerRemainingFeed => (leftToday / remainingFeeds).round();

  String get splitLine => goalReached
      ? 'تجاوزت هدف اليوم — أحسنت'
      : '${feedsCountLabel(remainingFeeds)} متبقية · $mlPerRemainingFeed مل لكل رضعة';

  /// أقرب جرعة مجدولة لم تُسجَّل بعد.
  ({MedView view, DateTime at})? get nextDose {
    ({MedView view, DateTime at})? best;
    final now = DateTime.now();
    for (final v in medViews) {
      if (v.med.ended || v.med.isPrn) continue;
      for (final d in v.today) {
        if (d.recorded) continue;
        // نُبقي جرعة فات موعدها بأقل من ساعتين معروضة كي لا تختفي قبل تسجيلها.
        if (d.at.isBefore(now.subtract(const Duration(hours: 2)))) continue;
        if (best == null || d.at.isBefore(best.at)) best = (view: v, at: d.at);
      }
    }
    return best;
  }

  // ── التحميل ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    children = await repo.children();
    archivedChildren =
        (await repo.children(includeArchived: true)).where((c) => c.archived).toList();

    final saved = Settings.I.currentChild;
    if (children.isNotEmpty) {
      currentId = children.any((c) => c.id == saved) ? saved : children.first.id;
    } else {
      currentId = null;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final c = current;
    if (c == null) {
      todayFeeds = const [];
      medViews = const [];
      timeline = const [];
      weights = const [];
      ready = true;
      notifyListeners();
      return;
    }

    final from = dayStart, to = dayEnd;
    todayFeeds = await repo.feedings(c.id, from, to);
    goalToday = await repo.goalOn(c.id, to, c.goalMl);
    weights = await repo.weights(c.id);
    diapers = await repo.diaperCounts(c.id, DateTime.now().subtract(const Duration(hours: 24)));

    final meds = await repo.medications(c.id);
    final views = <MedView>[];
    for (final m in meds) {
      views.add(await _buildMedView(m, from, to));
    }
    medViews = views;

    timeline = _buildTimeline();

    ready = true;
    notifyListeners();
    unawaitedReschedule();
  }

  Future<MedView> _buildMedView(Medication m, DateTime from, DateTime to) async {
    final records = await repo.dosesInRange(m.id, from, to);
    final byMs = {for (final d in records) d.scheduledAt.millisecondsSinceEpoch: d};
    final now = DateTime.now();

    final today = <ScheduledDose>[];
    if (m.isPrn) {
      // «عند اللزوم» بلا مواعيد مخطّطة — نعرض ما أُعطي فعلاً فقط.
      for (final d in records) {
        today.add((at: d.takenAt ?? d.scheduledAt, status: d.status, recorded: true));
      }
    } else {
      for (final t in m.times) {
        final at = _occurrence(from, to, t);
        if (at == null) continue;
        if (m.isCourse && at.isAfter(m.endDate)) continue;
        final rec = byMs[at.millisecondsSinceEpoch];
        if (rec != null) {
          today.add((at: at, status: rec.status, recorded: true));
        } else if (at.isAfter(now)) {
          today.add((at: at, status: DoseStatus.upcoming, recorded: false));
        } else if (now.difference(at) > const Duration(hours: 2)) {
          today.add((at: at, status: DoseStatus.missed, recorded: false));
        } else {
          today.add((at: at, status: DoseStatus.late, recorded: false));
        }
      }
      today.sort((a, b) => a.at.compareTo(b.at));
    }

    return MedView(
      med: m,
      givenTotal: await repo.givenCount(m.id),
      lastGiven: await repo.lastGiven(m.id),
      givenLast24h: await repo.givenSince(m.id, now.subtract(const Duration(hours: 24))),
      today: today,
    );
  }

  /// يحوّل موعداً بصيغة HH:mm إلى لحظة داخل نافذة اليوم المنطقي [from, to).
  DateTime? _occurrence(DateTime from, DateTime to, String hhmmText) {
    final mins = minutesOf(hhmmText);
    for (final base in [from, from.add(const Duration(days: 1))]) {
      final at = DateTime(base.year, base.month, base.day, mins ~/ 60, mins % 60);
      if (!at.isBefore(from) && at.isBefore(to)) return at;
    }
    return null;
  }

  List<TimelineEntry> _buildTimeline() {
    final out = <TimelineEntry>[
      for (final f in todayFeeds)
        TimelineEntry(isFeed: true, at: f.at, label: 'رضعة', amount: '${f.ml} مل', refId: f.id),
    ];
    for (final v in medViews) {
      for (final d in v.today) {
        if (d.status != DoseStatus.given) continue;
        out.add(TimelineEntry(
          isFeed: false,
          at: d.at,
          label: v.med.name,
          amount: '${trimDose(v.med.dose)} ${v.med.unit}',
          refId: v.med.id,
        ));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at)); // الأحدث أولاً
    return out;
  }

  int get doseCountToday => timeline.where((e) => !e.isFeed).length;

  // ── العمليات ──────────────────────────────────────────────────────────────

  Future<void> selectChild(int id) async {
    currentId = id;
    await Settings.I.setCurrentChild(id);
    await refresh();
  }

  Future<int> addChild(Child c) async {
    final id = await repo.insertChild(c);
    if (c.weightKg != null) await repo.insertWeight(id, c.weightKg!, DateTime.now());
    await load();
    await selectChild(id);
    return id;
  }

  Future<void> saveChild(Child c, {int? newGoal}) async {
    await repo.updateChild(c);
    if (newGoal != null && newGoal != goalToday) {
      await repo.insertGoal(c.id, newGoal, DateTime.now());
    }
    await load();
  }

  Future<void> archiveChild(int id, bool archived) async {
    await repo.setArchived(id, archived);
    await load();
  }

  Future<void> addFeeding(int ml, DateTime at, String? note) async {
    final c = current;
    if (c == null) return;
    await repo.insertFeeding(Feeding(id: 0, childId: c.id, at: at, ml: ml, note: note));
    await refresh();
  }

  Future<void> editFeeding(Feeding f) async {
    await repo.updateFeeding(f);
    await refresh();
  }

  Future<void> removeFeeding(int id) async {
    await repo.deleteFeeding(id);
    await refresh();
  }

  Future<void> saveMedication(Medication m) async {
    if (m.id == 0) {
      await repo.insertMedication(m);
    } else {
      await repo.updateMedication(m);
    }
    await refresh();
  }

  Future<void> endMedication(int medId, bool ended) async {
    await repo.setMedEnded(medId, ended);
    await refresh();
  }

  Future<void> deleteMedication(int medId) async {
    await repo.deleteMedication(medId);
    await refresh();
  }

  Future<void> recordDose(int medId, DateTime scheduledAt, DoseStatus status) async {
    await repo.recordDose(
      medId,
      scheduledAt,
      status,
      takenAt: status == DoseStatus.given ? DateTime.now() : null,
    );
    await refresh();
  }

  Future<void> addWeight(double kg) async {
    final c = current;
    if (c == null) return;
    await repo.insertWeight(c.id, kg, DateTime.now());
    if (c.goalAuto) {
      final goal = suggestedGoal(kg);
      await repo.updateChild(c.copyWith(weightKg: kg, goalMl: goal));
      await repo.insertGoal(c.id, goal, DateTime.now());
    } else {
      await repo.updateChild(c.copyWith(weightKg: kg));
    }
    await load();
  }

  Future<void> addDiaper(String type) async {
    final c = current;
    if (c == null) return;
    await repo.insertDiaper(c.id, type, DateTime.now());
    await refresh();
  }

  /// بعد استعادة نسخة احتياطية تتغيّر كل الجداول تحت أقدامنا.
  Future<void> reloadEverything() => load();

  /// تُستدعى بعد كل تغيير. لا ننتظرها كي لا تؤخّر إعادة رسم الواجهة.
  void unawaitedReschedule() {
    _rescheduleAll();
  }

  Future<void> _rescheduleAll() async {
    final handled = <String>{};
    for (final v in medViews) {
      for (final d in v.today) {
        if (d.recorded) handled.add('${v.med.id}@${d.at.millisecondsSinceEpoch}');
      }
    }

    // تذكير الرضاعة يخصّ كل طفل لا الطفل المعروض فقط.
    final lastByChild = <int, DateTime?>{};
    final allMeds = <Medication>[];
    for (final c in children) {
      lastByChild[c.id] = await repo.lastFeedAt(c.id);
      allMeds.addAll(c.id == currentId
          ? medViews.map((v) => v.med)
          : await repo.medications(c.id, ended: false));
    }

    await Notifs.reschedule(
      enabled: Settings.I.notificationsEnabled,
      children: children,
      lastFeedByChild: lastByChild,
      meds: allMeds,
      handledDoseKeys: handled,
    );
  }
}

/// القاعدة الشائعة للرضاعة الصناعية: نحو 110 مل لكل كيلوغرام يومياً، مقرّبة لأقرب 10.
int suggestedGoal(double weightKg) => (weightKg * 110 / 10).round() * 10;
