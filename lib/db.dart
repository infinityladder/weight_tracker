import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class BodyLogDb {
  BodyLogDb._(this._db);

  final Database _db;

  /// The fixed list of measurements users choose from, in body order. Keys
  /// match those used by earlier versions so past values carry over.
  static const measures = [
    ('c_neck', 'Neck'),
    ('c_shoulder', 'Shoulders'),
    ('c_chest', 'Chest'),
    ('c_l_bicep', 'L-Bicep'),
    ('c_r_bicep', 'R-Bicep'),
    ('c_l_forearm', 'L-Forearm'),
    ('c_r_forearm', 'R-Forearm'),
    ('c_abdomen', 'Abdomen'),
    ('waist', 'Waist'),
    ('hips', 'Hips'),
    ('c_l_thigh', 'L-Thigh'),
    ('c_r_thigh', 'R-Thigh'),
    ('c_l_above_knee', 'L-Above Knee'),
    ('c_r_above_knee', 'R-Above Knee'),
    ('c_l_calf', 'L-Calf'),
    ('c_r_calf', 'R-Calf'),
  ];

  /// Shown on a fresh install; the rest are switched on in Settings.
  static const shownByDefault = {'c_chest', 'waist', 'hips', 'c_l_thigh', 'c_r_thigh'};

  /// Makes the fields table match [measures]: standard fields get their label
  /// and order, missing ones are added (hidden unless [fresh] and shown by
  /// default), and anything else is hidden for good. Values are never deleted.
  static Future<void> _syncMeasures(DatabaseExecutor db, {required bool fresh}) async {
    for (final (i, (key, label)) in measures.indexed) {
      final updated = await db.update('fields', {'label': label, 'built_in': 1, 'sort_order': i},
          where: 'key = ?', whereArgs: [key]);
      if (updated == 0) {
        await db.insert('fields', {
          'key': key,
          'label': label,
          'built_in': 1,
          'hidden': fresh && shownByDefault.contains(key) ? 0 : 1,
          'sort_order': i,
        });
      }
    }
    final keys = [for (final (k, _) in measures) k];
    await db.update('fields', {'built_in': 0, 'hidden': 1, 'sort_order': 1000},
        where: 'key NOT IN (${List.filled(keys.length, '?').join(',')})', whereArgs: keys);
  }

  static const _createEntries = '''
    CREATE TABLE entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      minutes INTEGER NOT NULL,
      weight_kg REAL,
      measurements TEXT NOT NULL DEFAULT '{}',
      UNIQUE(date, minutes)
    )''';

  static Future<BodyLogDb> open() async {
    final path = p.join(await getDatabasesPath(), 'body_log.db');
    final db = await openDatabase(
      path,
      version: 5,
      onUpgrade: (db, from, to) async {
        if (from < 2) {
          // v1 stored a named slot per entry; map each slot to a representative time.
          await db.execute('ALTER TABLE entries RENAME TO entries_v1');
          await db.execute(_createEntries);
          await db.execute('''
            INSERT INTO entries(id, date, minutes, weight_kg, measurements)
            SELECT id, date,
              CASE slot WHEN 'afterLunch' THEN 780 WHEN 'afterDinner' THEN 1140 ELSE 480 END,
              weight_kg, measurements
            FROM entries_v1''');
          await db.execute('DROP TABLE entries_v1');
        }
        if (from < 5) await _syncMeasures(db, fresh: false);
      },
      onCreate: (db, version) async {
        await db.execute(_createEntries);
        await db.execute('''
          CREATE TABLE fields(
            key TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            built_in INTEGER NOT NULL,
            hidden INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL
          )''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await _syncMeasures(db, fresh: true);
      },
    );
    return BodyLogDb._(db);
  }

  // Entries

  Future<List<Entry>> entries() async {
    final rows = await _db.query('entries');
    return rows.map(_entryFromRow).toList()..sort(Entry.newestFirst);
  }

  Entry _entryFromRow(Map<String, Object?> r) {
    final m = jsonDecode(r['measurements'] as String) as Map<String, dynamic>;
    return Entry(
      id: r['id'] as int,
      date: DateTime.parse(r['date'] as String),
      minutes: r['minutes'] as int,
      weightKg: (r['weight_kg'] as num?)?.toDouble(),
      measurements: m.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }

  /// Updates [e] by id when it has one, otherwise the entry at the same date +
  /// time, otherwise inserts. Moving an entry onto another entry's date + time
  /// replaces that other entry.
  Future<void> saveEntry(Entry e) => _db.transaction((txn) => _save(txn, e));

  /// Saves many entries in one transaction, each as [saveEntry] would.
  Future<void> saveEntries(Iterable<Entry> entries) => _db.transaction((txn) async {
        for (final e in entries) {
          await _save(txn, e);
        }
      });

  static Future<void> _save(Transaction txn, Entry e) async {
    final values = {
      'date': dateKey(e.date),
      'minutes': e.minutes,
      'weight_kg': e.weightKg,
      'measurements': jsonEncode(e.measurements),
    };
    if (e.id != null) {
      await txn.delete('entries',
          where: 'date = ? AND minutes = ? AND id != ?', whereArgs: [values['date'], e.minutes, e.id]);
      await txn.update('entries', values, where: 'id = ?', whereArgs: [e.id]);
      return;
    }
    final updated = await txn.update(
      'entries',
      values,
      where: 'date = ? AND minutes = ?',
      whereArgs: [values['date'], e.minutes],
    );
    if (updated == 0) await txn.insert('entries', values);
  }

  Future<void> deleteEntry(int id) => _db.delete('entries', where: 'id = ?', whereArgs: [id]);

  // Fields

  Future<List<MeasureField>> fields() async {
    final rows = await _db.query('fields', orderBy: 'sort_order');
    return [
      for (final r in rows)
        MeasureField(
          key: r['key'] as String,
          label: r['label'] as String,
          builtIn: r['built_in'] == 1,
          hidden: r['hidden'] == 1,
          sortOrder: r['sort_order'] as int,
        ),
    ];
  }

  /// Shows or hides a standard measurement.
  Future<void> setFieldShown(String key, bool shown) => _db.update('fields', {'hidden': shown ? 0 : 1},
      where: 'key = ? AND built_in = 1', whereArgs: [key]);

  // Settings

  Future<String?> setting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
