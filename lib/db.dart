import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class BodyLogDb {
  BodyLogDb._(this._db);

  final Database _db;

  static const builtInFields = [('waist', 'Waist'), ('hips', 'Hips'), ('thigh', 'Thigh')];

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
      version: 2,
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
        for (final (i, (key, label)) in builtInFields.indexed) {
          await db.insert('fields', {'key': key, 'label': label, 'built_in': 1, 'sort_order': i});
        }
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
  Future<void> saveEntry(Entry e) async {
    final values = {
      'date': dateKey(e.date),
      'minutes': e.minutes,
      'weight_kg': e.weightKg,
      'measurements': jsonEncode(e.measurements),
    };
    await _db.transaction((txn) async {
      if (e.id != null) {
        await txn.delete('entries',
            where: 'date = ? AND minutes = ? AND id != ?',
            whereArgs: [values['date'], e.minutes, e.id]);
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
    });
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

  /// Adds a custom field, or un-hides a previously removed one with the same name.
  Future<void> addField(String label) async {
    final key = 'c_${label.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final existing = await _db.query('fields', where: 'key = ?', whereArgs: [key]);
    if (existing.isNotEmpty) {
      await _db.update('fields', {'hidden': 0, 'label': label.trim()},
          where: 'key = ?', whereArgs: [key]);
      return;
    }
    final maxOrder = Sqflite.firstIntValue(
            await _db.rawQuery('SELECT MAX(sort_order) FROM fields')) ??
        0;
    await _db.insert('fields', {
      'key': key,
      'label': label.trim(),
      'built_in': 0,
      'sort_order': maxOrder + 1,
    });
  }

  Future<void> hideField(String key) => _db.update('fields', {'hidden': 1},
      where: 'key = ? AND built_in = 0', whereArgs: [key]);

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
