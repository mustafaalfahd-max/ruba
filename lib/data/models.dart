import 'package:flutter/material.dart';

import '../theme.dart';

/// نوع العلاج — يحدّد سلوك الجدولة والتحذيرات.
enum MedType {
  /// كورس محدد المدة: مضاد حيوي 3 مرات يومياً لـ 7 أيام.
  course,

  /// دائم بلا نهاية: فيتامين د مرة يومياً.
  permanent,

  /// عند اللزوم: خافض حرارة بحد أدنى بين الجرعتين.
  prn,
}

MedType medTypeFrom(String s) => switch (s) {
      'course' => MedType.course,
      'prn' => MedType.prn,
      _ => MedType.permanent,
    };

String medTypeCode(MedType t) => switch (t) {
      MedType.course => 'course',
      MedType.prn => 'prn',
      MedType.permanent => 'perm',
    };

String medTypeLabel(MedType t) => switch (t) {
      MedType.course => 'كورس',
      MedType.prn => 'عند اللزوم',
      MedType.permanent => 'دائم',
    };

/// حالة الجرعة في السجل.
enum DoseStatus { given, skipped, missed, late, upcoming }

String doseStatusCode(DoseStatus s) => s.name;

DoseStatus doseStatusFrom(String s) =>
    DoseStatus.values.firstWhere((e) => e.name == s, orElse: () => DoseStatus.upcoming);

String doseStatusLabel(DoseStatus s) => switch (s) {
      DoseStatus.given => 'أُعطيت',
      DoseStatus.skipped => 'تُخطّيت',
      DoseStatus.missed => 'فُوّتت',
      DoseStatus.late => 'متأخرة',
      DoseStatus.upcoming => 'قادمة',
    };

/// (لون النقطة، خلفية الوسم، لون نص الوسم)
({Color dot, Color bg, Color fg}) doseStatusColors(DoseStatus s) => switch (s) {
      DoseStatus.given => (dot: RC.cyan, bg: RC.cyanWash, fg: RC.cyanDark),
      DoseStatus.missed => (dot: RC.magentaDark, bg: RC.magentaWash, fg: RC.magentaDark),
      DoseStatus.skipped => (dot: RC.ink6, bg: RC.muted, fg: RC.ink3),
      DoseStatus.late => (dot: RC.gold, bg: RC.amberWash, fg: RC.amberInk),
      DoseStatus.upcoming => (dot: RC.ink7, bg: RC.paper, fg: RC.ink4),
    };

class Child {
  final int id;
  final String name;
  final String? dob; // yyyy-MM-dd
  final String sex; // f | m
  final double? weightKg;
  final int goalMl;
  final bool goalAuto;
  final int intervalMin; // الفاصل بين الرضعات
  final int reminderLeadMin;
  final String quietFrom; // HH:mm
  final String quietTo; // HH:mm
  final int sortOrder;
  final bool archived;
  final int colorValue;

  const Child({
    required this.id,
    required this.name,
    this.dob,
    this.sex = 'f',
    this.weightKg,
    this.goalMl = 700,
    this.goalAuto = true,
    this.intervalMin = 150,
    this.reminderLeadMin = 15,
    this.quietFrom = '23:00',
    this.quietTo = '05:00',
    this.sortOrder = 0,
    this.archived = false,
    this.colorValue = 0xFF0088B0,
  });

  Color get color => Color(colorValue);
  String get initial => name.isEmpty ? '؟' : name.characters.first;

  Child copyWith({
    String? name,
    String? dob,
    String? sex,
    double? weightKg,
    int? goalMl,
    bool? goalAuto,
    int? intervalMin,
    int? reminderLeadMin,
    String? quietFrom,
    String? quietTo,
    int? sortOrder,
    bool? archived,
  }) =>
      Child(
        id: id,
        name: name ?? this.name,
        dob: dob ?? this.dob,
        sex: sex ?? this.sex,
        weightKg: weightKg ?? this.weightKg,
        goalMl: goalMl ?? this.goalMl,
        goalAuto: goalAuto ?? this.goalAuto,
        intervalMin: intervalMin ?? this.intervalMin,
        reminderLeadMin: reminderLeadMin ?? this.reminderLeadMin,
        quietFrom: quietFrom ?? this.quietFrom,
        quietTo: quietTo ?? this.quietTo,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
        colorValue: colorValue,
      );

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'name': name,
        'dob': dob,
        'sex': sex,
        'weight_kg': weightKg,
        'goal_ml': goalMl,
        'goal_auto': goalAuto ? 1 : 0,
        'interval_min': intervalMin,
        'reminder_lead_min': reminderLeadMin,
        'quiet_from': quietFrom,
        'quiet_to': quietTo,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'color_value': colorValue,
      };

  factory Child.fromMap(Map<String, Object?> m) => Child(
        id: m['id'] as int,
        name: m['name'] as String,
        dob: m['dob'] as String?,
        sex: (m['sex'] as String?) ?? 'f',
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        goalMl: (m['goal_ml'] as int?) ?? 700,
        goalAuto: ((m['goal_auto'] as int?) ?? 1) == 1,
        intervalMin: (m['interval_min'] as int?) ?? 150,
        reminderLeadMin: (m['reminder_lead_min'] as int?) ?? 15,
        quietFrom: (m['quiet_from'] as String?) ?? '23:00',
        quietTo: (m['quiet_to'] as String?) ?? '05:00',
        sortOrder: (m['sort_order'] as int?) ?? 0,
        archived: ((m['archived'] as int?) ?? 0) == 1,
        colorValue: (m['color_value'] as int?) ?? 0xFF0088B0,
      );
}

class Feeding {
  final int id;
  final int childId;
  final DateTime at;
  final int ml;
  final String? note;

  const Feeding({
    required this.id,
    required this.childId,
    required this.at,
    required this.ml,
    this.note,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'child_id': childId,
        'at_ms': at.millisecondsSinceEpoch,
        'ml': ml,
        'note': note,
      };

  factory Feeding.fromMap(Map<String, Object?> m) => Feeding(
        id: m['id'] as int,
        childId: m['child_id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(m['at_ms'] as int),
        ml: m['ml'] as int,
        note: m['note'] as String?,
      );
}

class Medication {
  final int id;
  final int childId;
  final String name;
  final String form; // شراب | حبوب | قطرات | تحاميل | بخاخ
  final double dose;
  final String unit; // مل | ملغم | نقطة
  final MedType type;
  final int perDay;
  final int days; // للكورس فقط
  final int minGapHours; // لعند اللزوم فقط
  final int maxPerDay; // لعند اللزوم فقط
  final DateTime startAt;
  final bool avoidSleep;
  final bool remind;
  final String? note;
  final bool ended;
  final DateTime? endedAt;
  final List<String> times; // HH:mm

  const Medication({
    required this.id,
    required this.childId,
    required this.name,
    this.form = 'شراب',
    this.dose = 1,
    this.unit = 'مل',
    this.type = MedType.course,
    this.perDay = 3,
    this.days = 7,
    this.minGapHours = 6,
    this.maxPerDay = 4,
    required this.startAt,
    this.avoidSleep = true,
    this.remind = true,
    this.note,
    this.ended = false,
    this.endedAt,
    this.times = const [],
  });

  bool get isCourse => type == MedType.course;
  bool get isPrn => type == MedType.prn;

  /// إجمالي جرعات الكورس المخطّطة.
  int get totalDoses => isCourse ? perDay * days : 0;

  DateTime get endDate => startAt.add(Duration(days: days));

  Medication copyWith({
    String? name,
    String? form,
    double? dose,
    String? unit,
    MedType? type,
    int? perDay,
    int? days,
    int? minGapHours,
    int? maxPerDay,
    bool? avoidSleep,
    bool? remind,
    String? note,
    bool? ended,
    DateTime? endedAt,
    List<String>? times,
  }) =>
      Medication(
        id: id,
        childId: childId,
        name: name ?? this.name,
        form: form ?? this.form,
        dose: dose ?? this.dose,
        unit: unit ?? this.unit,
        type: type ?? this.type,
        perDay: perDay ?? this.perDay,
        days: days ?? this.days,
        minGapHours: minGapHours ?? this.minGapHours,
        maxPerDay: maxPerDay ?? this.maxPerDay,
        startAt: startAt,
        avoidSleep: avoidSleep ?? this.avoidSleep,
        remind: remind ?? this.remind,
        note: note ?? this.note,
        ended: ended ?? this.ended,
        endedAt: endedAt ?? this.endedAt,
        times: times ?? this.times,
      );

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'child_id': childId,
        'name': name,
        'form': form,
        'dose': dose,
        'unit': unit,
        'type': medTypeCode(type),
        'per_day': perDay,
        'days': days,
        'min_gap_hours': minGapHours,
        'max_per_day': maxPerDay,
        'start_ms': startAt.millisecondsSinceEpoch,
        'avoid_sleep': avoidSleep ? 1 : 0,
        'remind': remind ? 1 : 0,
        'note': note,
        'ended': ended ? 1 : 0,
        'ended_ms': endedAt?.millisecondsSinceEpoch,
      };

  factory Medication.fromMap(Map<String, Object?> m, List<String> times) => Medication(
        id: m['id'] as int,
        childId: m['child_id'] as int,
        name: m['name'] as String,
        form: (m['form'] as String?) ?? 'شراب',
        dose: (m['dose'] as num?)?.toDouble() ?? 1,
        unit: (m['unit'] as String?) ?? 'مل',
        type: medTypeFrom((m['type'] as String?) ?? 'perm'),
        perDay: (m['per_day'] as int?) ?? 1,
        days: (m['days'] as int?) ?? 7,
        minGapHours: (m['min_gap_hours'] as int?) ?? 6,
        maxPerDay: (m['max_per_day'] as int?) ?? 4,
        startAt: DateTime.fromMillisecondsSinceEpoch((m['start_ms'] as int?) ?? 0),
        avoidSleep: ((m['avoid_sleep'] as int?) ?? 1) == 1,
        remind: ((m['remind'] as int?) ?? 1) == 1,
        note: m['note'] as String?,
        ended: ((m['ended'] as int?) ?? 0) == 1,
        endedAt: (m['ended_ms'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['ended_ms'] as int),
        times: times,
      );
}

class MedDose {
  final int id;
  final int medId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final DoseStatus status;

  const MedDose({
    required this.id,
    required this.medId,
    required this.scheduledAt,
    this.takenAt,
    this.status = DoseStatus.upcoming,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'med_id': medId,
        'scheduled_ms': scheduledAt.millisecondsSinceEpoch,
        'taken_ms': takenAt?.millisecondsSinceEpoch,
        'status': doseStatusCode(status),
      };

  factory MedDose.fromMap(Map<String, Object?> m) => MedDose(
        id: m['id'] as int,
        medId: m['med_id'] as int,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(m['scheduled_ms'] as int),
        takenAt: (m['taken_ms'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['taken_ms'] as int),
        status: doseStatusFrom((m['status'] as String?) ?? 'upcoming'),
      );
}

class WeightEntry {
  final int id;
  final int childId;
  final DateTime at;
  final double kg;

  const WeightEntry({required this.id, required this.childId, required this.at, required this.kg});

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'child_id': childId,
        'at_ms': at.millisecondsSinceEpoch,
        'kg': kg,
      };

  factory WeightEntry.fromMap(Map<String, Object?> m) => WeightEntry(
        id: m['id'] as int,
        childId: m['child_id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(m['at_ms'] as int),
        kg: (m['kg'] as num).toDouble(),
      );
}

class DiaperEntry {
  final int id;
  final int childId;
  final DateTime at;
  final String type; // wet | dirty | both

  const DiaperEntry({required this.id, required this.childId, required this.at, required this.type});

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'child_id': childId,
        'at_ms': at.millisecondsSinceEpoch,
        'type': type,
      };

  factory DiaperEntry.fromMap(Map<String, Object?> m) => DiaperEntry(
        id: m['id'] as int,
        childId: m['child_id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(m['at_ms'] as int),
        type: m['type'] as String,
      );
}

/// سجل تاريخي للهدف اليومي — لا نُعيد كتابة الماضي عند تغيير الهدف.
class GoalRow {
  final int id;
  final int childId;
  final DateTime effectiveFrom;
  final int dailyTargetMl;

  const GoalRow({
    required this.id,
    required this.childId,
    required this.effectiveFrom,
    required this.dailyTargetMl,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'child_id': childId,
        'effective_from_ms': effectiveFrom.millisecondsSinceEpoch,
        'daily_target_ml': dailyTargetMl,
      };

  factory GoalRow.fromMap(Map<String, Object?> m) => GoalRow(
        id: m['id'] as int,
        childId: m['child_id'] as int,
        effectiveFrom: DateTime.fromMillisecondsSinceEpoch(m['effective_from_ms'] as int),
        dailyTargetMl: m['daily_target_ml'] as int,
      );
}

/// عنصر واحد في الخط الزمني لليوم — رضعة أو جرعة.
class TimelineEntry {
  final bool isFeed;
  final DateTime at;
  final String label;
  final String amount;
  final int refId;

  const TimelineEntry({
    required this.isFeed,
    required this.at,
    required this.label,
    required this.amount,
    required this.refId,
  });
}
