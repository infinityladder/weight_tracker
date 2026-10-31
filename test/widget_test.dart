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
    expect(u.fmtWeight(u.weightIn(160)), '160.0');
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
      '2026-01-01,07:05,yes,80.0,90.0,30.0\n'
      '2026-01-01,18:00,no,81.0,,\n',
    );
  });
}
