import 'package:sqflite/sqflite.dart';

import '../util/dates.dart';
import 'db.dart';
import 'models.dart';

/// كل الوصول إلى قاعدة البيانات يمرّ من هنا، وكل استعلام مكتوب بـ SQL صريح.
class Repo {
  Database get _db => RubaDb.instance;

  // ── الأطفال ────────────────────────────────────────────────────────────────

  Future<List<Child>> children({bool includeArchived = false}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM children ${includeArchived ? '' : 'WHERE archived = 0'} '
      'ORDER BY sort_order ASC, id ASC',
    );
    return rows.map(Child.fromMap).toList();
  }

  Future<Child?> child(int id) async {
    final rows = await _db.rawQuery('SELECT * FROM children WHERE id = ?', [id]);
    return rows.isEmpty ? null : Child.fromMap(rows.first);
  }

  Future<int> insertChild(Child c) async {
    final id = await _db.insert('children', c.toMap());
    await insertGoal(id, c.goalMl, DateTime.now());
    return id;
  }

  Future<void> updateChild(Child c) async {
    await _db.update('children', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> setArchived(int childId, bool archived) async {
    await _db.rawUpdate(
      'UPDATE children SET archived = ? WHERE id = ?',
      [archived ? 1 : 0, childId],
    );
  }

  Future<void> reorderChildren(List<int> idsInOrder) async {
    final batch = _db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.rawUpdate('UPDATE children SET sort_order = ? WHERE id = ?', [i, idsInOrder[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ── الهدف اليومي (بسجل تاريخي) ─────────────────────────────────────────────

  Future<void> insertGoal(int childId, int ml, DateTime from) async {
    await _db.insert('goals', {
      'child_id': childId,
      'effective_from_ms': from.millisecondsSinceEpoch,
      'daily_target_ml': ml,
    });
  }

  /// الهدف الساري في يوم معيّن. يقع الاختيار على أحدث صف بدأ سريانه قبل نهاية ذلك اليوم.
  Future<int> goalOn(int childId, DateTime dayEnd, int fallback) async {
    final rows = await _db.rawQuery(
      'SELECT daily_target_ml FROM goals WHERE child_id = ? AND effective_from_ms <= ? '
      'ORDER BY effective_from_ms DESC LIMIT 1',
      [childId, dayEnd.millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return fallback;
    return rows.first['daily_target_ml'] as int;
  }

  // ── الرضعات ────────────────────────────────────────────────────────────────

  Future<List<Feeding>> feedings(int childId, DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM feedings WHERE child_id = ? AND at_ms >= ? AND at_ms < ? ORDER BY at_ms ASC',
      [childId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows.map(Feeding.fromMap).toList();
  }

  Future<int> insertFeeding(Feeding f) => _db.insert('feedings', f.toMap());

  /// آخر رضعة لطفل — أساس حساب موعد الرضعة القادمة وتذكيرها.
  Future<DateTime?> lastFeedAt(int childId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(at_ms) AS t FROM feedings WHERE child_id = ?',
      [childId],
    );
    final t = rows.first['t'] as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<void> updateFeeding(Feeding f) async {
    await _db.update('feedings', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
  }

  Future<void> deleteFeeding(int id) async {
    await _db.rawDelete('DELETE FROM feedings WHERE id = ?', [id]);
  }

  /// مجموع كل يوم منطقي ضمن مدى. المفتاح هو ميلي ثانية بداية اليوم.
  Future<Map<int, int>> dailyTotals(
    int childId,
    DateTime from,
    DateTime to,
    int dayStartHour,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT at_ms, ml FROM feedings WHERE child_id = ? AND at_ms >= ? AND at_ms < ?',
      [childId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final out = <int, int>{};
    for (final r in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(r['at_ms'] as int);
      final key = dayStartFor(at, dayStartHour).millisecondsSinceEpoch;
      out[key] = (out[key] ?? 0) + (r['ml'] as int);
    }
    return out;
  }

  /// عدد الرضعات لكل يوم منطقي — للإحصائيات.
  Future<Map<int, int>> dailyCounts(
    int childId,
    DateTime from,
    DateTime to,
    int dayStartHour,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT at_ms FROM feedings WHERE child_id = ? AND at_ms >= ? AND at_ms < ?',
      [childId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final out = <int, int>{};
    for (final r in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(r['at_ms'] as int);
      final key = dayStartFor(at, dayStartHour).millisecondsSinceEpoch;
      out[key] = (out[key] ?? 0) + 1;
    }
    return out;
  }

  // ── العلاجات ───────────────────────────────────────────────────────────────

  Future<List<Medication>> medications(int childId, {bool? ended}) async {
    final where = StringBuffer('WHERE child_id = ?');
    final args = <Object?>[childId];
    if (ended != null) {
      where.write(' AND ended = ?');
      args.add(ended ? 1 : 0);
    }
    final rows = await _db.rawQuery('SELECT * FROM medications $where ORDER BY id DESC', args);
    return Future.wait(rows.map((r) async {
      final times = await _timesOf(r['id'] as int);
      return Medication.fromMap(r, times);
    }));
  }

  Future<Medication?> medication(int id) async {
    final rows = await _db.rawQuery('SELECT * FROM medications WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Medication.fromMap(rows.first, await _timesOf(id));
  }

  Future<List<String>> _timesOf(int medId) async {
    final rows = await _db.rawQuery(
      'SELECT at_hhmm FROM med_times WHERE med_id = ? ORDER BY ordinal ASC',
      [medId],
    );
    return rows.map((r) => r['at_hhmm'] as String).toList();
  }

  Future<int> insertMedication(Medication m) async {
    final id = await _db.insert('medications', m.toMap());
    await _writeTimes(id, m.times);
    return id;
  }

  Future<void> updateMedication(Medication m) async {
    await _db.update('medications', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
    await _writeTimes(m.id, m.times);
  }

  Future<void> _writeTimes(int medId, List<String> times) async {
    await _db.rawDelete('DELETE FROM med_times WHERE med_id = ?', [medId]);
    final batch = _db.batch();
    for (var i = 0; i < times.length; i++) {
      batch.insert('med_times', {'med_id': medId, 'at_hhmm': times[i], 'ordinal': i});
    }
    await batch.commit(noResult: true);
  }

  Future<void> setMedEnded(int medId, bool ended) async {
    await _db.rawUpdate(
      'UPDATE medications SET ended = ?, ended_ms = ? WHERE id = ?',
      [ended ? 1 : 0, ended ? DateTime.now().millisecondsSinceEpoch : null, medId],
    );
  }

  Future<void> deleteMedication(int medId) async {
    await _db.rawDelete('DELETE FROM medications WHERE id = ?', [medId]);
  }

  // ── الجرعات ────────────────────────────────────────────────────────────────

  Future<List<MedDose>> doses(int medId, {int limit = 200}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM med_doses WHERE med_id = ? ORDER BY scheduled_ms DESC LIMIT ?',
      [medId, limit],
    );
    return rows.map(MedDose.fromMap).toList();
  }

  Future<List<MedDose>> dosesInRange(int medId, DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM med_doses WHERE med_id = ? AND scheduled_ms >= ? AND scheduled_ms < ? '
      'ORDER BY scheduled_ms ASC',
      [medId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows.map(MedDose.fromMap).toList();
  }

  /// جرعات طفل كامل خلال مدى — لبناء الخط الزمني.
  Future<List<({MedDose dose, Medication med})>> childDosesInRange(
    int childId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT d.* , d.med_id AS mid FROM med_doses d '
      'JOIN medications m ON m.id = d.med_id '
      'WHERE m.child_id = ? AND d.scheduled_ms >= ? AND d.scheduled_ms < ? '
      'ORDER BY d.scheduled_ms ASC',
      [childId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final out = <({MedDose dose, Medication med})>[];
    final cache = <int, Medication>{};
    for (final r in rows) {
      final medId = r['mid'] as int;
      final med = cache[medId] ??= (await medication(medId))!;
      out.add((dose: MedDose.fromMap(r), med: med));
    }
    return out;
  }

  /// تسجيل جرعة. `scheduledAt` هو الموعد المخطّط (أو وقت الإعطاء لعلاجات «عند اللزوم»).
  Future<void> recordDose(
    int medId,
    DateTime scheduledAt,
    DoseStatus status, {
    DateTime? takenAt,
  }) async {
    await _db.insert(
      'med_doses',
      {
        'med_id': medId,
        'scheduled_ms': scheduledAt.millisecondsSinceEpoch,
        'taken_ms': takenAt?.millisecondsSinceEpoch,
        'status': doseStatusCode(status),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// آخر جرعة أُعطيت فعلاً — أساس حساب الحد الأدنى بين الجرعتين.
  Future<DateTime?> lastGiven(int medId) async {
    final rows = await _db.rawQuery(
      "SELECT MAX(COALESCE(taken_ms, scheduled_ms)) AS t FROM med_doses "
      "WHERE med_id = ? AND status = 'given'",
      [medId],
    );
    final t = rows.first['t'] as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<int> givenCount(int medId) async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM med_doses WHERE med_id = ? AND status = 'given'",
      [medId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// عدد الجرعات المُعطاة لعلاج «عند اللزوم» خلال آخر 24 ساعة — لحدّ الجرعات اليومي.
  Future<int> givenSince(int medId, DateTime since) async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM med_doses WHERE med_id = ? AND status = 'given' "
      "AND COALESCE(taken_ms, scheduled_ms) >= ?",
      [medId, since.millisecondsSinceEpoch],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // ── الأوزان والحفاضات ──────────────────────────────────────────────────────

  Future<List<WeightEntry>> weights(int childId, {int limit = 40}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM weights WHERE child_id = ? ORDER BY at_ms DESC LIMIT ?',
      [childId, limit],
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<void> insertWeight(int childId, double kg, DateTime at) async {
    await _db.insert('weights', {
      'child_id': childId,
      'at_ms': at.millisecondsSinceEpoch,
      'kg': kg,
    });
  }

  Future<void> deleteWeight(int id) async {
    await _db.rawDelete('DELETE FROM weights WHERE id = ?', [id]);
  }

  Future<void> insertDiaper(int childId, String type, DateTime at) async {
    await _db.insert('diapers', {
      'child_id': childId,
      'at_ms': at.millisecondsSinceEpoch,
      'type': type,
    });
  }

  /// عدّاد الحفاضات في آخر 24 ساعة: (مبللة، متسخة).
  Future<({int wet, int dirty})> diaperCounts(int childId, DateTime since) async {
    final rows = await _db.rawQuery(
      'SELECT type, COUNT(*) AS c FROM diapers WHERE child_id = ? AND at_ms >= ? GROUP BY type',
      [childId, since.millisecondsSinceEpoch],
    );
    var wet = 0, dirty = 0;
    for (final r in rows) {
      final c = (r['c'] as int?) ?? 0;
      switch (r['type'] as String) {
        case 'wet':
          wet += c;
        case 'dirty':
          dirty += c;
        case 'both':
          wet += c;
          dirty += c;
      }
    }
    return (wet: wet, dirty: dirty);
  }

  // ── التصدير والاستيراد ─────────────────────────────────────────────────────

  static const exportTables = [
    'children',
    'feedings',
    'goals',
    'medications',
    'med_times',
    'med_doses',
    'weights',
    'diapers',
  ];

  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in exportTables) {
      out[t] = await _db.rawQuery('SELECT * FROM $t');
    }
    return out;
  }

  /// يستبدل كل البيانات الحالية بمحتوى النسخة. عملية ذرّية — إما أن تنجح كاملة أو لا شيء.
  Future<void> replaceAll(Map<String, List<Map<String, Object?>>> data) async {
    await _db.transaction((txn) async {
      for (final t in exportTables.reversed) {
        await txn.rawDelete('DELETE FROM $t');
      }
      for (final t in exportTables) {
        final rows = data[t];
        if (rows == null) continue;
        final batch = txn.batch();
        for (final r in rows) {
          batch.insert(t, r, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<({int feedings, int doses, int children})> counts() async {
    Future<int> one(String sql) async =>
        ((await _db.rawQuery(sql)).first.values.first as int?) ?? 0;
    return (
      feedings: await one('SELECT COUNT(*) FROM feedings'),
      doses: await one("SELECT COUNT(*) FROM med_doses WHERE status = 'given'"),
      children: await one('SELECT COUNT(*) FROM children'),
    );
  }
}
