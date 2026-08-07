import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// فتح قاعدة البيانات المحلية وإنشاء مخططها.
/// كل SQL مكتوب صراحةً هنا حتى يبقى تغيير المخطط مرئياً ومراجَعاً.
class RubaDb {
  RubaDb._();

  static const fileName = 'ruba.db';
  static const _version = 1;

  static Database? _db;

  static Database get instance {
    final d = _db;
    if (d == null) {
      throw StateError('لم تُفتح قاعدة البيانات بعد — استدعِ RubaDb.open() أولاً');
    }
    return d;
  }

  static Future<String> path() async => p.join(await getDatabasesPath(), fileName);

  static Future<Database> open() async {
    _db ??= await openDatabase(
      await path(),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async => _createAll(db),
    );
    return _db!;
  }

  /// تُستعمل بعد الاستعادة من نسخة احتياطية: نغلق الاتصال ثم نعيد فتحه على الملف الجديد.
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE children (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT    NOT NULL,
        dob               TEXT,
        sex               TEXT    NOT NULL DEFAULT 'f',
        weight_kg         REAL,
        goal_ml           INTEGER NOT NULL DEFAULT 700,
        goal_auto         INTEGER NOT NULL DEFAULT 1,
        interval_min      INTEGER NOT NULL DEFAULT 150,
        reminder_lead_min INTEGER NOT NULL DEFAULT 15,
        quiet_from        TEXT    NOT NULL DEFAULT '23:00',
        quiet_to          TEXT    NOT NULL DEFAULT '05:00',
        sort_order        INTEGER NOT NULL DEFAULT 0,
        archived          INTEGER NOT NULL DEFAULT 0,
        color_value       INTEGER NOT NULL DEFAULT 8947632
      )
    ''');

    await db.execute('''
      CREATE TABLE feedings (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
        at_ms    INTEGER NOT NULL,
        ml       INTEGER NOT NULL,
        note     TEXT
      )
    ''');
    await db.execute('CREATE INDEX ix_feedings_child_at ON feedings(child_id, at_ms)');

    // سجل الهدف التاريخي — الهدف الساري ليوم ما هو أحدث صف تاريخُ سريانه <= ذلك اليوم.
    await db.execute('''
      CREATE TABLE goals (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id          INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
        effective_from_ms INTEGER NOT NULL,
        daily_target_ml   INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX ix_goals_child_from ON goals(child_id, effective_from_ms)');

    await db.execute('''
      CREATE TABLE medications (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id      INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
        name          TEXT    NOT NULL,
        form          TEXT    NOT NULL DEFAULT 'شراب',
        dose          REAL    NOT NULL DEFAULT 1,
        unit          TEXT    NOT NULL DEFAULT 'مل',
        type          TEXT    NOT NULL DEFAULT 'perm',
        per_day       INTEGER NOT NULL DEFAULT 1,
        days          INTEGER NOT NULL DEFAULT 7,
        min_gap_hours INTEGER NOT NULL DEFAULT 6,
        max_per_day   INTEGER NOT NULL DEFAULT 4,
        start_ms      INTEGER NOT NULL,
        avoid_sleep   INTEGER NOT NULL DEFAULT 1,
        remind        INTEGER NOT NULL DEFAULT 1,
        note          TEXT,
        ended         INTEGER NOT NULL DEFAULT 0,
        ended_ms      INTEGER
      )
    ''');
    await db.execute('CREATE INDEX ix_meds_child ON medications(child_id, ended)');

    await db.execute('''
      CREATE TABLE med_times (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        med_id  INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        at_hhmm TEXT    NOT NULL,
        ordinal INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX ix_med_times_med ON med_times(med_id, ordinal)');

    await db.execute('''
      CREATE TABLE med_doses (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        med_id       INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        scheduled_ms INTEGER NOT NULL,
        taken_ms     INTEGER,
        status       TEXT    NOT NULL DEFAULT 'upcoming'
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX ux_med_doses ON med_doses(med_id, scheduled_ms)');

    await db.execute('''
      CREATE TABLE weights (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
        at_ms    INTEGER NOT NULL,
        kg       REAL    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX ix_weights_child_at ON weights(child_id, at_ms)');

    await db.execute('''
      CREATE TABLE diapers (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
        at_ms    INTEGER NOT NULL,
        type     TEXT    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX ix_diapers_child_at ON diapers(child_id, at_ms)');
  }
}
