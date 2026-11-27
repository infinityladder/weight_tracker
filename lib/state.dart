import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'csv_import.dart';
import 'db.dart';
import 'models.dart';
import 'units.dart';

class AppData {
  AppData({
    required this.entries,
    required this.fields,
    required this.goal,
    required this.unitSystem,
    this.startDate,
    this.body = BodyType.male,
    this.skinTone = SkinTone.light,
    this.heightCm,
    this.bmiRanges = BmiRanges.standard,
    this.healthShown = const {HealthAnalysis.bmi, HealthAnalysis.waistRatio, HealthAnalysis.waistHip},
  });

  /// Newest first.
  final List<Entry> entries;
  final List<MeasureField> fields;
  final Goal? goal;
  final UnitSystem unitSystem;

  /// Chosen starting point for "since start" and goals; null = first weigh-in.
  final DateTime? startDate;

  /// Figure drawn on the home screen.
  final BodyType body;

  /// Skin of that figure.
  final SkinTone skinTone;

  /// The picture drawn for [body] in [skinTone].
  Figure get figure => Figure.of(body, skinTone);

  /// The user's height, for BMI; null until set.
  final double? heightCm;

  /// Cut-offs for the BMI category.
  final BmiRanges bmiRanges;

  /// Analyses switched on for the Health screen.
  final Set<HealthAnalysis> healthShown;

  /// BMI from the latest weigh-in; null without a height or weight.
  double? get latestBmi {
    final h = heightCm, w = latestMain?.weightKg;
    return h == null || w == null ? null : bmi(w, h);
  }

  /// Latest waist divided by latest hips; null without either.
  double? get latestWaistHipRatio {
    final w = latestMeasurement('waist'), hips = latestMeasurement('hips');
    return w == null || hips == null ? null : w / hips;
  }

  /// Latest waist measurement divided by height; null without either.
  double? get latestWaistRatio {
    final h = heightCm, w = latestMeasurement('waist');
    return h == null || w == null ? null : w / h;
  }

  Units get units => Units(unitSystem);

  List<MeasureField> get visibleFields => fields.where((f) => !f.hidden).toList();

  /// The standard measurements, shown or not, in body order.
  List<MeasureField> get standardFields => fields.where((f) => f.builtIn).toList();

  /// One weight per date, newest first: the last one logged that day, at
  /// any time of day.
  late final List<Entry> mainWeights = () {
    final seen = <DateTime>{};
    return [
      for (final e in entries)
        if (e.weightKg != null && seen.add(e.date)) e,
    ];
  }();

  late final Set<int?> _mainIds = {for (final e in mainWeights) e.id};

  bool isMain(Entry e) => _mainIds.contains(e.id);

  Entry? get latestMain => mainWeights.firstOrNull;
  Entry? get firstMain => mainWeights.lastOrNull;

  /// The starting weigh-in: the first weigh-in on or after [startDate].
  Entry? get startMain {
    final d = startDate;
    if (d == null) return firstMain;
    return mainWeights.reversed.where((e) => !e.date.isBefore(d)).firstOrNull ?? firstMain;
  }

  /// Dates that have a weigh-in.
  late final Set<DateTime> mainDates = {for (final e in mainWeights) e.date};

  Entry? entryAt(DateTime date, int minutes) {
    final d = dateOnly(date);
    return entries.where((e) => e.date == d && e.minutes == minutes).firstOrNull;
  }

  GoalProgress? progress(DateTime today) {
    final g = goal, latest = latestMain;
    if (g == null || latest == null) return null;
    return GoalProgress(goal: g, currentKg: latest.weightKg!, today: today);
  }

  /// Average weight change per week (signed kg) from the start weigh-in to
  /// the latest; null until they're at least a week apart.
  double? get pacePerWeekKg {
    final start = startMain, latest = latestMain;
    if (start == null || latest == null) return null;
    final days = latest.date.difference(start.date).inDays;
    return days < 7 ? null : (latest.weightKg! - start.weightKg!) / (days / 7);
  }

  String labelFor(String key) =>
      fields.where((f) => f.key == key).firstOrNull?.label ?? key;

  /// Most recent value logged for a measurement field, in cm.
  double? latestMeasurement(String key) =>
      entries.where((e) => e.measurements.containsKey(key)).firstOrNull?.measurements[key];

  /// The day changes are measured from: the start weigh-in's date, or the
  /// chosen start date when there's no weigh-in yet. Null with neither.
  DateTime? get startDay => startMain?.date ?? startDate;

  /// A measurement's value at [startDay] (date, cm): the last one logged on
  /// or before it, else the first one after. With no start, the first ever.
  (DateTime, double)? measurementAtStart(String key) {
    final logged = [
      for (final e in entries.reversed)
        if (e.measurements[key] case final v?) (e.date, v),
    ];
    if (logged.isEmpty) return null;
    final start = startDay;
    if (start == null) return logged.first;
    return logged.lastWhere((m) => !m.$1.isAfter(start), orElse: () => logged.first);
  }

  AppData copyWith({UnitSystem? unitSystem, BodyType? body, SkinTone? skinTone, double? Function()? heightCm, BmiRanges? bmiRanges, Set<HealthAnalysis>? healthShown}) =>
      AppData(
        entries: entries,
        fields: fields,
        goal: goal,
        unitSystem: unitSystem ?? this.unitSystem,
        startDate: startDate,
        body: body ?? this.body,
        skinTone: skinTone ?? this.skinTone,
        heightCm: heightCm == null ? this.heightCm : heightCm(),
        bmiRanges: bmiRanges ?? this.bmiRanges,
        healthShown: healthShown ?? this.healthShown,
      );
}

Future<AppData> loadAppData(BodyLogDb db) async {
  final goalJson = await db.setting('goal');
  final start = await db.setting('start_date');
  return AppData(
    startDate: start == null ? null : DateTime.tryParse(start),
    body: (await db.setting('body')) == 'female' ? BodyType.female : BodyType.male,
    skinTone: SkinTone.decode(await db.setting('skin')),
    heightCm: double.tryParse(await db.setting('height_cm') ?? ''),
    bmiRanges: (await db.setting('bmi_ranges')) == 'asian' ? BmiRanges.asian : BmiRanges.standard,
    healthShown: HealthAnalysis.decode(await db.setting('health')),
    entries: await db.entries(),
    fields: await db.fields(),
    goal: goalJson == null ? null : Goal.fromJson(jsonDecode(goalJson) as Map<String, dynamic>),
    unitSystem: (await db.setting('units')) == 'imperial' ? UnitSystem.imperial : UnitSystem.metric,
  );
}

/// Both are opened/loaded in main() before the first frame.
final dbProvider = Provider<BodyLogDb>((ref) => throw UnimplementedError());
final initialDataProvider = Provider<AppData>((ref) => throw UnimplementedError());

final appProvider = NotifierProvider<AppController, AppData>(AppController.new);

class AppController extends Notifier<AppData> {
  BodyLogDb get _db => ref.read(dbProvider);

  @override
  AppData build() => ref.read(initialDataProvider);

  Future<void> _reload() async => state = await loadAppData(_db);

  Future<void> saveEntry(Entry e) async {
    await _db.saveEntry(e);
    await _reload();
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteEntry(id);
    await _reload();
  }

  Future<void> setUnits(UnitSystem system) async {
    state = state.copyWith(unitSystem: system);
    await _db.setSetting('units', system.name);
  }

  Future<void> setBody(BodyType body) async {
    state = state.copyWith(body: body);
    await _db.setSetting('body', body.name);
  }

  Future<void> setSkinTone(SkinTone tone) async {
    state = state.copyWith(skinTone: tone);
    await _db.setSetting('skin', tone.name);
  }

  /// Sets the height used for BMI; null clears it.
  Future<void> setHeight(double? cm) async {
    state = state.copyWith(heightCm: () => cm);
    await _db.setSetting('height_cm', cm?.toString());
  }

  Future<void> setBmiRanges(BmiRanges ranges) async {
    state = state.copyWith(bmiRanges: ranges);
    await _db.setSetting('bmi_ranges', ranges.name);
  }

  /// Switches one analysis on the Health screen on or off.
  Future<void> setHealthShown(HealthAnalysis analysis, bool on) async {
    final shown = {...state.healthShown};
    on ? shown.add(analysis) : shown.remove(analysis);
    state = state.copyWith(healthShown: shown);
    await _db.setSetting('health', HealthAnalysis.encode(shown));
  }

  Future<void> setFieldShown(String key, bool shown) async {
    await _db.setFieldShown(key, shown);
    await _reload();
  }

  Future<void> renameField(String key, String label) async {
    await _db.renameField(key, label);
    await _reload();
  }

  /// Sets the starting weigh-in ([date] null = first weigh-in). An existing
  /// goal moves its start weight to match.
  Future<void> setStartDate(DateTime? date) async {
    await _db.setSetting('start_date', date == null ? null : dateKey(date));
    final g = state.goal;
    final start = AppData(
      entries: state.entries,
      fields: state.fields,
      goal: g,
      unitSystem: state.unitSystem,
      startDate: date,
      body: state.body,
      heightCm: state.heightCm,
      bmiRanges: state.bmiRanges,
      healthShown: state.healthShown,
    ).startMain;
    if (g != null && start != null) {
      final moved = Goal(targetWeightKg: g.targetWeightKg, targetDate: g.targetDate, startWeightKg: start.weightKg!);
      await _db.setSetting('goal', jsonEncode(moved.toJson()));
    }
    await _reload();
  }

  /// Keeps the original start weight when editing. A new goal starts from the
  /// chosen start weigh-in, or the latest weigh-in when none is chosen.
  Future<void> setGoal(double targetKg, DateTime targetDate) async {
    final start = state.goal?.startWeightKg ??
        (state.startDate != null ? state.startMain : state.latestMain)?.weightKg;
    if (start == null) return;
    final goal = Goal(targetWeightKg: targetKg, targetDate: dateOnly(targetDate), startWeightKg: start);
    await _db.setSetting('goal', jsonEncode(goal.toJson()));
    await _reload();
  }

  Future<void> removeGoal() async {
    await _db.setSetting('goal', null);
    await _reload();
  }

  /// Merges a CSV export into the log: rows at a date + time that already
  /// exists update that entry (imported values win), others are added.
  /// Measurements that receive values are switched on.
  Future<ImportSummary> importCsv(String text) async {
    final parsed = parseCsvImport(text, state.fields);
    final merged = <Entry>[];
    var updated = 0;
    for (final e in parsed.entries) {
      final old = state.entryAt(e.date, e.minutes);
      if (old == null) {
        merged.add(e);
        continue;
      }
      updated++;
      merged.add(Entry(
        id: old.id,
        date: old.date,
        minutes: old.minutes,
        weightKg: e.weightKg ?? old.weightKg,
        measurements: {...old.measurements, ...e.measurements},
      ));
    }
    await _db.saveEntries(merged);
    final used = {for (final e in parsed.entries) ...e.measurements.keys};
    for (final f in state.fields) {
      if (f.builtIn && f.hidden && used.contains(f.key)) await _db.setFieldShown(f.key, true);
    }
    await _reload();
    return ImportSummary(
      added: merged.length - updated,
      updated: updated,
      skippedColumns: parsed.skippedColumns,
      badRows: parsed.badRows,
    );
  }
}

/// All entries (oldest first) and all fields, including removed ones,
/// in the current display units.
String buildCsv(AppData data) {
  final u = data.units;
  String q(String s) => RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  final header = [
    'date',
    'time',
    'weight_${u.weight}',
    for (final f in data.fields) '${f.label} (${u.length})',
  ];
  final rows = [
    header.map(q).join(','),
    for (final e in data.entries.reversed)
      [
        dateKey(e.date),
        hhmm(e.minutes),
        e.weightKg == null ? '' : u.fmtWeight(e.weightKg!),
        for (final f in data.fields)
          e.measurements[f.key] == null ? '' : u.fmtLength(e.measurements[f.key]!),
      ].join(','),
  ];
  return '${rows.join('\n')}\n';
}

class ImportSummary {
  const ImportSummary({required this.added, required this.updated, required this.skippedColumns, required this.badRows});

  final int added, updated;
  final List<String> skippedColumns;
  final List<int> badRows;
}
