import 'package:body_log/models.dart';
import 'package:body_log/state.dart';
import 'package:body_log/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default time slot follows time of day', () {
    expect(TimeSlot.forTime(DateTime(2026, 1, 1, 11, 59)), TimeSlot.morning);
    expect(TimeSlot.forTime(DateTime(2026, 1, 1, 12)), TimeSlot.afterLunch);
    expect(TimeSlot.forTime(DateTime(2026, 1, 1, 16, 59)), TimeSlot.afterLunch);
    expect(TimeSlot.forTime(DateTime(2026, 1, 1, 17)), TimeSlot.afterDinner);
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

  test('morning weights drive the headline; lunch/dinner are notes', () {
    final d1 = DateTime(2026, 1, 1), d2 = DateTime(2026, 1, 2);
    final data = AppData(
      entries: [
        Entry(id: 4, date: d2, slot: TimeSlot.afterDinner, weightKg: 81),
        Entry(id: 3, date: d2, slot: TimeSlot.morning, weightKg: 79.5),
        Entry(id: 2, date: d1, slot: TimeSlot.afterLunch, weightKg: 80.9),
        Entry(id: 1, date: d1, slot: TimeSlot.morning, weightKg: 80),
      ],
      fields: const [],
      goal: null,
      unitSystem: UnitSystem.metric,
    );
    expect(data.latestMorning!.id, 3);
    expect(data.firstMorning!.id, 1);
    expect(data.notesFor(d2).map((e) => e.id), [4]);
  });

  test('csv export quotes labels and includes hidden fields', () {
    final data = AppData(
      entries: [
        Entry(id: 1, date: DateTime(2026, 1, 1), slot: TimeSlot.morning, weightKg: 80, measurements: const {'waist': 90, 'c_arm': 30}),
      ],
      fields: const [
        MeasureField(key: 'waist', label: 'Waist', builtIn: true, hidden: false, sortOrder: 0),
        MeasureField(key: 'c_arm', label: 'Arm, left', builtIn: false, hidden: true, sortOrder: 1),
      ],
      goal: null,
      unitSystem: UnitSystem.metric,
    );
    expect(buildCsv(data), 'date,time_slot,weight_kg,Waist (cm),"Arm, left (cm)"\n2026-01-01,morning,80.0,90.0,30.0\n');
  });
}
