import 'dart:io';

import 'package:body_log/db.dart';
import 'package:body_log/models.dart';
import 'package:body_log/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // A custom field that later becomes a default part, hidden by the user.
    await v1.insert('fields', {'key': 'c_chest', 'label': 'Chest', 'built_in': 0, 'hidden': 1, 'sort_order': 3});
    await v1.close();

    final db = await BodyLogDb.open();
    final entries = await db.entries();
    expect([for (final e in entries) (e.minutes, e.weightKg)], [(1140, 81.2), (780, 80.8), (480, 80.0)]);
    expect(entries.last.measurements, {'waist': 90.0});

    // Standard measures are added; the existing Chest keeps the visibility the user chose.
    final fields = await db.fields();
    expect(fields.where((f) => f.label == 'Chest').map((f) => (f.key, f.hidden)), [('c_chest', true)]);
    expect(fields.where((f) => f.builtIn).map((f) => f.label), [for (final (_, l) in BodyLogDb.measures) l]);
  });

  test('v4 fields become the standard list; non-standard ones are hidden, values kept', () async {
    final v4 = await openDatabase(path, version: 4, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
          minutes INTEGER NOT NULL, weight_kg REAL, measurements TEXT NOT NULL DEFAULT '{}', UNIQUE(date, minutes))''');
      await db.execute('''CREATE TABLE fields(key TEXT PRIMARY KEY, label TEXT NOT NULL, built_in INTEGER NOT NULL,
          hidden INTEGER NOT NULL DEFAULT 0, sort_order INTEGER NOT NULL)''');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      await db.insert('fields', {'key': 'waist', 'label': 'Waist', 'built_in': 1, 'sort_order': 0});
      await db.insert('fields', {'key': 'c_shoulder', 'label': 'Shoulder', 'built_in': 0, 'sort_order': 1});
      await db.insert('fields', {'key': 'c_mood', 'label': 'Mood', 'built_in': 0, 'sort_order': 2});
      await db.insert('entries', {'date': '2026-10-01', 'minutes': 480, 'measurements': '{"c_mood":3.0}'});
    });
    await v4.close();

    final db = await BodyLogDb.open();
    final fields = {for (final f in await db.fields()) f.key: f};
    expect((fields['waist']!.hidden, fields['c_shoulder']!.label, fields['c_shoulder']!.hidden), (false, 'Shoulders', false));
    expect(fields['c_l_calf']!.hidden, isTrue); // new standard measures start switched off
    expect((fields['c_mood']!.builtIn, fields['c_mood']!.hidden), (false, true));
    expect((await db.entries()).single.measurements, {'c_mood': 3.0});

    await db.setFieldShown('c_l_calf', true);
    await db.setFieldShown('c_mood', true); // not standard: stays hidden
    final after = {for (final f in await db.fields()) f.key: f};
    expect((after['c_l_calf']!.hidden, after['c_mood']!.hidden), (false, true));
  });

  test('fresh install has the standard list with a few shown', () async {
    final db = await BodyLogDb.open();
    final fields = await db.fields();
    expect(fields.map((f) => f.label), [for (final (_, l) in BodyLogDb.measures) l]);
    expect(fields.where((f) => !f.hidden).map((f) => f.key).toSet(), BodyLogDb.shownByDefault);
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

  test('import merges by date + time and switches on measurements it fills', () async {
    final db = await BodyLogDb.open();
    final d = DateTime(2026, 3, 1);
    await db.saveEntry(Entry(date: d, minutes: 420, weightKg: 70, measurements: const {'waist': 80}));
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(await loadAppData(db)),
    ]);
    addTearDown(container.dispose);

    final summary = await container.read(appProvider.notifier).importCsv(
          'date,time,weight_kg,Waist (cm),L-Calf (cm)\r\n'
          '2026-03-01,07:00,69.5,,36\r\n' // same time: weight replaced, waist kept, calf added
          '2026-03-02,07:10,69.2,79,\r\n',
        );
    expect((summary.added, summary.updated), (1, 1));

    final data = container.read(appProvider);
    final first = data.entryAt(d, 420)!;
    expect(first.weightKg, 69.5);
    expect(first.measurements, {'waist': 80.0, 'c_l_calf': 36.0});
    expect(data.entryAt(DateTime(2026, 3, 2), 430)!.weightKg, 69.2);
    expect(data.fields.singleWhere((f) => f.key == 'c_l_calf').hidden, isFalse);
  });
}
