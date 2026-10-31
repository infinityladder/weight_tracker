import 'dart:io';

import 'package:body_log/db.dart';
import 'package:body_log/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String path;
  setUp(() async {
    path = p.join(await getDatabasesPath(), 'body_log.db');
    if (File(path).existsSync()) await deleteDatabase(path);
  });

  test('v1 slots migrate to times and keep their data', () async {
    final v1 = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
          slot TEXT NOT NULL, weight_kg REAL, measurements TEXT NOT NULL DEFAULT '{}', UNIQUE(date, slot))''');
      await db.execute('''CREATE TABLE fields(key TEXT PRIMARY KEY, label TEXT NOT NULL, built_in INTEGER NOT NULL,
          hidden INTEGER NOT NULL DEFAULT 0, sort_order INTEGER NOT NULL)''');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    });
    await v1.insert('entries', {'date': '2026-10-01', 'slot': 'morning', 'weight_kg': 80.0, 'measurements': '{"waist":90.0}'});
    await v1.insert('entries', {'date': '2026-10-01', 'slot': 'afterLunch', 'weight_kg': 80.8});
    await v1.insert('entries', {'date': '2026-10-01', 'slot': 'afterDinner', 'weight_kg': 81.2});
    await v1.close();

    final db = await BodyLogDb.open();
    final entries = await db.entries();
    expect([for (final e in entries) (e.minutes, e.weightKg)], [(1140, 81.2), (780, 80.8), (480, 80.0)]);
    expect(entries.last.measurements, {'waist': 90.0});
  });

  test('save updates by id, by matching date+time, or inserts', () async {
    final db = await BodyLogDb.open();
    final d = DateTime(2026, 10, 2);
    await db.saveEntry(Entry(date: d, minutes: 420, weightKg: 80));
    await db.saveEntry(Entry(date: d, minutes: 420, weightKg: 79.9)); // same time: update
    await db.saveEntry(Entry(date: d, minutes: 1200, weightKg: 81)); // new time: insert
    var all = await db.entries();
    expect([for (final e in all) e.weightKg], [81, 79.9]);

    // Editing the evening entry onto 07:00 replaces the 07:00 entry.
    await db.saveEntry(Entry(id: all.first.id, date: d, minutes: 420, weightKg: 81));
    all = await db.entries();
    expect(all.length, 1);
    expect((all.single.minutes, all.single.weightKg), (420, 81.0));
  });
}
