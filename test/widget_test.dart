import 'package:body_log/body_map.dart';
import 'package:body_log/csv_import.dart';
import 'package:body_log/db.dart';
import 'package:body_log/models.dart';
import 'package:body_log/state.dart';
import 'package:body_log/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main window contains its ends and can wrap midnight', () {
    const w = WeighWindow(6 * 60, 10 * 60);
    expect(w.contains(6 * 60), isTrue);
    expect(w.contains(10 * 60), isTrue);
    expect(w.contains(10 * 60 + 1), isFalse);
    const night = WeighWindow(22 * 60, 2 * 60);
    expect(night.contains(23 * 60), isTrue);
    expect(night.contains(60), isTrue);
    expect(night.contains(12 * 60), isFalse);
    expect(WeighWindow.decode(w.encode()), w);
    expect(WeighWindow.decode('junk'), WeighWindow.defaultWindow);
    expect(hhmm(7 * 60 + 5), '07:05');
  });

  test('unit conversion round-trips', () {
    const u = Units(UnitSystem.imperial);
    expect(u.fmtWeight(u.weightIn(160)), '160.00');
    expect(u.fmtLength(u.lengthIn(32.5)), '32.5');
    expect(parseNumber('72,4'), 72.4);
    expect(parseNumber(''), isNull);
  });

  group('goal progress', () {
    final goal = Goal(targetWeightKg: 70, targetDate: DateTime(2026, 3, 1), startWeightKg: 80);

    test('halfway with 4 weeks left', () {
      final p = GoalProgress(goal: goal, currentKg: 75, today: DateTime(2026, 2, 1));
      expect(p.fraction, 0.5);
      expect(p.leftKg, 5);
      expect(p.daysLeft, 28);
      expect(p.perWeekKg, closeTo(-1.25, 1e-9));
      expect(p.reached, isFalse);
    });

    test('reached when at or below target', () {
      final p = GoalProgress(goal: goal, currentKg: 69.8, today: DateTime(2026, 2, 1));
      expect(p.reached, isTrue);
      expect(p.fraction, 1);
      expect(p.leftKg, 0);
    });

    test('gain goal', () {
      final gain = Goal(targetWeightKg: 60, targetDate: DateTime(2026, 3, 1), startWeightKg: 55);
      final p = GoalProgress(goal: gain, currentKg: 56, today: DateTime(2026, 2, 1));
      expect(p.fraction, closeTo(0.2, 1e-9));
      expect(p.reached, isFalse);
    });
  });

  test('earliest weight in the window is the main record; the rest are notes', () {
    final d1 = DateTime(2026, 1, 1), d2 = DateTime(2026, 1, 2);
    final entries = [
      Entry(id: 1, date: d1, minutes: 7 * 60, weightKg: 80),
      Entry(id: 2, date: d1, minutes: 13 * 60, weightKg: 80.9),
      Entry(id: 3, date: d2, minutes: 6 * 60 + 30, weightKg: 79.5),
      Entry(id: 4, date: d2, minutes: 9 * 60, weightKg: 79.7), // second in-window weigh-in
      Entry(id: 5, date: d2, minutes: 19 * 60, weightKg: 81),
      Entry(id: 6, date: d2, minutes: 8 * 60, measurements: const {'waist': 90}), // no weight
    ]..sort(Entry.newestFirst);
    final data = AppData(entries: entries, fields: const [], goal: null, unitSystem: UnitSystem.metric);
    expect(data.mainWeights.map((e) => e.id), [3, 1]);
    expect(data.latestMain!.id, 3);
    expect(data.firstMain!.id, 1);
    expect(data.notesFor(d2).map((e) => e.id), [4, 5]);

    final shifted = data.copyWith(window: const WeighWindow(12 * 60, 14 * 60));
    expect(shifted.mainWeights.map((e) => e.id), [2]);
  });

  test('BMI uses the latest main weigh-in and the height', () {
    final d = DateTime(2026, 1, 1);
    final entries = [
      Entry(id: 1, date: d, minutes: 7 * 60, weightKg: 72),
      Entry(id: 2, date: d, minutes: 20 * 60, weightKg: 90), // a note, not the main record
    ]..sort(Entry.newestFirst);
    final data = AppData(entries: entries, fields: const [], goal: null, unitSystem: UnitSystem.metric);
    expect(data.latestBmi, isNull); // no height yet
    final tall = data.copyWith(heightCm: () => 180);
    expect(tall.latestBmi, closeTo(22.2, 0.05));
    expect(tall.copyWith(window: const WeighWindow(0, 23 * 60 + 59)).heightCm, 180); // kept
    expect(tall.copyWith(heightCm: () => null).latestBmi, isNull);
    expect([for (final b in <double>[18.4, 18.5, 24.9, 25, 29.9, 30]) bmiCategory(b)],
        ['Underweight', 'Healthy', 'Healthy', 'Overweight', 'Overweight', 'Obese']);
    expect([for (final b in <double>[18.4, 22.9, 23, 27.4, 27.5]) bmiCategory(b, BmiRanges.asian)],
        ['Underweight', 'Healthy', 'Overweight', 'Overweight', 'Obese']);
    expect(tall.copyWith(bmiRanges: BmiRanges.asian).copyWith(heightCm: () => 170).bmiRanges, BmiRanges.asian); // kept
  });

  test('health analyses are stored as a list; never set means all', () {
    expect(HealthAnalysis.decode(null), HealthAnalysis.values.toSet());
    expect(HealthAnalysis.decode(''), isEmpty);
    expect(HealthAnalysis.decode('waistRatio,gone'), {HealthAnalysis.waistRatio});
    expect(HealthAnalysis.encode({HealthAnalysis.waistRatio, HealthAnalysis.bmi}), 'bmi,waistRatio');
    expect(HealthAnalysis.values.where((a) => !a.usesHeight), [HealthAnalysis.waistHip]);
  });

  test('waist-to-hip ratio uses the WHO limit for the body', () {
    final data = AppData(
      entries: [Entry(date: DateTime(2026, 1, 1), minutes: 480, measurements: const {'waist': 87, 'hips': 100})],
      fields: const [],
      goal: null,
      unitSystem: UnitSystem.metric,
    );
    expect(data.latestWaistHipRatio, 0.87);
    expect(waistHipCategory(0.87, BodyType.male), 'Healthy');
    expect(waistHipCategory(0.87, BodyType.female), 'Increased risk');
    expect((waistHipCategory(0.899, BodyType.male), waistHipCategory(0.90, BodyType.male)), ('Healthy', 'Increased risk'));
  });

  test('waist-to-height ratio uses the latest waist and the height', () {
    final entries = [
      Entry(date: DateTime(2026, 1, 2), minutes: 480, measurements: const {'waist': 90}),
      Entry(date: DateTime(2026, 1, 1), minutes: 480, measurements: const {'waist': 95}),
    ];
    final data = AppData(entries: entries, fields: const [], goal: null, unitSystem: UnitSystem.metric);
    expect(data.latestWaistRatio, isNull); // no height yet
    expect(data.copyWith(heightCm: () => 180).latestWaistRatio, 0.5);
    expect([for (final r in <double>[0.39, 0.4, 0.49, 0.5, 0.59, 0.6]) waistRatioCategory(r)],
        ['Low', 'Healthy', 'Healthy', 'Increased risk', 'Increased risk', 'High risk']);
  });

  test('start weigh-in is the first main weigh-in on or after the chosen date', () {
    final entries = [
      Entry(id: 1, date: DateTime(2026, 1, 1), minutes: 420, weightKg: 82),
      Entry(id: 2, date: DateTime(2026, 1, 5), minutes: 420, weightKg: 81),
      Entry(id: 3, date: DateTime(2026, 1, 9), minutes: 420, weightKg: 80),
    ]..sort(Entry.newestFirst);
    AppData at(DateTime? d) =>
        AppData(entries: entries, fields: const [], goal: null, unitSystem: UnitSystem.metric, startDate: d);
    expect(at(null).startMain!.id, 1);
    expect(at(DateTime(2026, 1, 5)).startMain!.id, 2);
    expect(at(DateTime(2026, 1, 6)).startMain!.id, 3); // that day's entry was deleted
    expect(at(DateTime(2026, 2, 1)).startMain!.id, 1); // nothing after: fall back to first
    expect(at(null).mainDates, {DateTime(2026, 1, 1), DateTime(2026, 1, 5), DateTime(2026, 1, 9)});
  });

  test('measurement changes count from the start date', () {
    final entries = [
      Entry(id: 1, date: DateTime(2026, 1, 1), minutes: 420, weightKg: 82, measurements: const {'waist': 95}),
      Entry(id: 2, date: DateTime(2026, 1, 8), minutes: 420, weightKg: 81, measurements: const {'waist': 93}),
      Entry(id: 3, date: DateTime(2026, 1, 15), minutes: 420, weightKg: 80),
      Entry(id: 4, date: DateTime(2026, 1, 22), minutes: 420, weightKg: 79, measurements: const {'waist': 90}),
    ]..sort(Entry.newestFirst);
    AppData at(DateTime? d) =>
        AppData(entries: entries, fields: const [], goal: null, unitSystem: UnitSystem.metric, startDate: d);
    // No start chosen: from the first weigh-in, and the first waist value.
    expect(at(null).startDay, DateTime(2026, 1, 1));
    expect(at(null).measurementAtStart('waist'), (DateTime(2026, 1, 1), 95.0));
    // Start on the 15th (no waist that day): the last waist logged before it.
    expect(at(DateTime(2026, 1, 15)).measurementAtStart('waist'), (DateTime(2026, 1, 8), 93.0));
    // Waist first logged after the start: that first value.
    expect(at(DateTime(2026, 1, 1)).measurementAtStart('hips'), isNull);
    final noEarlyWaist = AppData(
      entries: entries.where((e) => e.id != 1 && e.id != 2).toList(),
      fields: const [],
      goal: null,
      unitSystem: UnitSystem.metric,
      startDate: DateTime(2026, 1, 15),
    );
    expect(noEarlyWaist.measurementAtStart('waist'), (DateTime(2026, 1, 22), 90.0));
  });

  test('skin colour is saved by name and defaults to light', () {
    expect(SkinTone.decode('brown'), SkinTone.brown);
    expect(SkinTone.decode('dark'), SkinTone.dark);
    expect(SkinTone.decode(null), SkinTone.light);
    expect(Figure.of(BodyType.female, SkinTone.brown), Figure.femaleBrown);
  });

  test('body parts match by name and side', () {
    MeasureField f(String label) => MeasureField(key: label, label: label, builtIn: false, hidden: false, sortOrder: 0);
    final lThigh = partFor(f('L-Thigh'))!, rThigh = partFor(f('R-Thigh'))!;
    final lKnee = partFor(f('L-Above Knee'))!, rKnee = partFor(f('right above-knee'))!;
    expect((lThigh.right, rThigh.right, lKnee.right, rKnee.right), (false, true, false, true));
    expect(lKnee.y, greaterThan(lThigh.y));
    expect(lKnee.y, lessThan(partFor(f('Knee'))!.y));
    expect(partFor(f('Mood')), isNull);
    // Every standard measure has a place on the body, on the side its name says.
    for (final (key, label) in BodyLogDb.measures) {
      if (customMeasureKeys.contains(key)) continue;
      for (final figure in Figure.values) {
        final part = partFor(f(label), figure);
        expect(part, isNotNull, reason: label);
        if (label.startsWith('L-')) expect(part!.right, isFalse, reason: label);
        if (label.startsWith('R-')) expect(part!.right, isTrue, reason: label);
      }
    }
    // The female waist is narrower and hips wider than the male ones.
    double width(BodyPart p) => p.x2 - p.x1;
    expect(width(partFor(f('Waist'), Figure.female)!), lessThan(width(partFor(f('Waist'))!)));
    expect(width(partFor(f('Hips'), Figure.female)!), greaterThan(width(partFor(f('Hips'))!)));
    // Custom measurements stay off the body, whatever they're called.
    const custom = MeasureField(key: 'c_custom_1', label: 'Left calf', builtIn: true, hidden: false, sortOrder: 0);
    expect(partFor(custom), isNull);
  });

  test('csv export has time and main flag, quotes labels, includes hidden fields', () {
    final data = AppData(
      entries: [
        Entry(id: 2, date: DateTime(2026, 1, 1), minutes: 18 * 60, weightKg: 81),
        Entry(id: 1, date: DateTime(2026, 1, 1), minutes: 7 * 60 + 5, weightKg: 80, measurements: const {'waist': 90, 'c_arm': 30}),
      ],
      fields: const [
        MeasureField(key: 'waist', label: 'Waist', builtIn: true, hidden: false, sortOrder: 0),
        MeasureField(key: 'c_arm', label: 'Arm, left', builtIn: false, hidden: true, sortOrder: 1),
      ],
      goal: null,
      unitSystem: UnitSystem.metric,
    );
    expect(
      buildCsv(data),
      'date,time,main_weigh_in,weight_kg,Waist (cm),"Arm, left (cm)"\n'
      '2026-01-01,07:05,yes,80.00,90.0,30.0\n'
      '2026-01-01,18:00,no,81.00,,\n',
    );
  });

  group('csv import', () {
    const fields = [
      MeasureField(key: 'waist', label: 'Waist', builtIn: true, hidden: false, sortOrder: 0),
      MeasureField(key: 'c_arm', label: 'Arm, left', builtIn: false, hidden: true, sortOrder: 1),
    ];

    test('reads back what export writes, in either unit system', () {
      final entries = [
        Entry(id: 2, date: DateTime(2026, 1, 1), minutes: 18 * 60, weightKg: 81.25),
        Entry(id: 1, date: DateTime(2026, 1, 1), minutes: 7 * 60 + 5, weightKg: 80, measurements: const {'waist': 90, 'c_arm': 30}),
      ];
      for (final units in UnitSystem.values) {
        final data = AppData(entries: entries, fields: fields, goal: null, unitSystem: units);
        final back = parseCsvImport(buildCsv(data), fields);
        expect(back.skippedColumns, isEmpty);
        expect(back.badRows, isEmpty);
        expect([for (final e in back.entries) (e.date, e.minutes)], [(DateTime(2026, 1, 1), 425), (DateTime(2026, 1, 1), 1080)]);
        // Exported values are rounded (2 decimals for weight, 1 for lengths).
        expect(back.entries[0].weightKg, closeTo(80, 0.01));
        expect(back.entries[0].measurements['waist'], closeTo(90, 0.2));
        expect(back.entries[0].measurements['c_arm'], closeTo(30, 0.2));
        expect(back.entries[1].weightKg, closeTo(81.25, 0.01));
        expect(back.entries[1].measurements, isEmpty);
      }
    });

    test('reports unknown columns and unreadable rows; tolerates CRLF, BOM and missing time', () {
      const csv = '\uFEFFdate,Weight (kg),Waist,Mood\r\n'
          '2026-02-01,70.5,80,3\r\n'
          'yesterday,71,,\r\n'
          '2026-02-02,,,\r\n';
      final r = parseCsvImport(csv, fields);
      expect(r.skippedColumns, ['Mood']);
      expect(r.badRows, [3]);
      expect(r.entries.single.minutes, 8 * 60);
      expect(r.entries.single.weightKg, 70.5);
      expect(r.entries.single.measurements, {'waist': 80.0});
    });

    test('rejects a file without a date column', () {
      expect(() => parseCsvImport('a,b\n1,2\n', fields), throwsA(isA<CsvImportException>()));
    });

    test('reads semicolon, tab and UTF-16 files; rejects spreadsheets', () {
      final semi = parseCsvImport('date;time;weight_kg\n2026-01-02;07:00;70,5\n', fields);
      expect(semi.entries.single.date, DateTime(2026, 1, 2));
      expect(semi.entries.single.weightKg, 70.5);
      final tab = parseCsvImport('date\ttime\tweight_kg\n2026-01-02\t07:00\t70.5\n', fields);
      expect(tab.entries.single.weightKg, 70.5);
      final utf16 = [0xFF, 0xFE, for (final u in 'date,weight_kg\n2026-01-02,70\n'.codeUnits) ...[u, 0]];
      expect(parseCsvImport(decodeCsvBytes(utf16), fields).entries.single.weightKg, 70);
      expect(() => decodeCsvBytes([0x50, 0x4B, 3, 4]), throwsA(isA<CsvImportException>()));
    });
  });
}
