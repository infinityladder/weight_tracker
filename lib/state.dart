import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'db.dart';
import 'models.dart';
import 'units.dart';

class AppData {
  AppData({
    required this.entries,
    required this.fields,
    required this.goal,
    required this.unitSystem,
    this.window = WeighWindow.defaultWindow,
    this.startDate,
    this.body = BodyType.male,
  });

  /// Newest first.
  final List<Entry> entries;
  final List<MeasureField> fields;
  final Goal? goal;
  final UnitSystem unitSystem;

  /// Weights logged inside this window are the main record.
  final WeighWindow window;

  /// Chosen starting point for "since start" and goals; null = first weigh-in.
  final DateTime? startDate;

  /// Figure drawn on the home screen.
  final BodyType body;

  Units get units => Units(unitSystem);

  List<MeasureField> get visibleFields => fields.where((f) => !f.hidden).toList();

  /// The standard measurements, shown or not, in body order.
  List<MeasureField> get standardFields => fields.where((f) => f.builtIn).toList();

  /// The main record, newest first: per date, the earliest weight logged
  /// inside the main window. Every other weight is a note.
  late final List<Entry> mainWeights = () {
    final seen = <DateTime>{};
    final out = [
      for (final e in entries.reversed)
        if (e.weightKg != null && window.contains(e.minutes) && seen.add(e.date)) e,
    ];
    return out.reversed.toList();
  }();

  late final Set<int?> _mainIds = {for (final e in mainWeights) e.id};

  bool isMain(Entry e) => _mainIds.contains(e.id);

  Entry? get latestMain => mainWeights.firstOrNull;
  Entry? get firstMain => mainWeights.lastOrNull;

  /// The starting weigh-in: the first main weigh-in on or after [startDate].
  Entry? get startMain {
    final d = startDate;
    if (d == null) return firstMain;
    return mainWeights.reversed.where((e) => !e.date.isBefore(d)).firstOrNull ?? firstMain;
  }

  /// Dates that have a main weigh-in.
  late final Set<DateTime> mainDates = {for (final e in mainWeights) e.date};

  Entry? entryAt(DateTime date, int minutes) {
    final d = dateOnly(date);
    return entries.where((e) => e.date == d && e.minutes == minutes).firstOrNull;
  }

  /// Weights logged on [day] that aren't the main weigh-in, earliest first.
  List<Entry> notesFor(DateTime day) {
    final d = dateOnly(day);
    return entries.where((e) => e.date == d && e.weightKg != null && !isMain(e)).toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
  }

  GoalProgress? progress(DateTime today) {
    final g = goal, latest = latestMain;
    if (g == null || latest == null) return null;
    return GoalProgress(goal: g, currentKg: latest.weightKg!, today: today);
  }

  String labelFor(String key) =>
      fields.where((f) => f.key == key).firstOrNull?.label ?? key;

  /// Most recent value logged for a measurement field, in cm.
  double? latestMeasurement(String key) =>
      entries.where((e) => e.measurements.containsKey(key)).firstOrNull?.measurements[key];

  AppData copyWith({UnitSystem? unitSystem, WeighWindow? window, BodyType? body}) => AppData(
        entries: entries,
        fields: fields,
        goal: goal,
        unitSystem: unitSystem ?? this.unitSystem,
        window: window ?? this.window,
        startDate: startDate,
        body: body ?? this.body,
      );
}

Future<AppData> loadAppData(BodyLogDb db) async {
  final goalJson = await db.setting('goal');
  final start = await db.setting('start_date');
  return AppData(
    startDate: start == null ? null : DateTime.tryParse(start),
    body: (await db.setting('body')) == 'female' ? BodyType.female : BodyType.male,
    entries: await db.entries(),
    fields: await db.fields(),
    goal: goalJson == null ? null : Goal.fromJson(jsonDecode(goalJson) as Map<String, dynamic>),
    unitSystem: (await db.setting('units')) == 'imperial' ? UnitSystem.imperial : UnitSystem.metric,
    window: WeighWindow.decode(await db.setting('window')),
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

  Future<void> setWindow(WeighWindow window) async {
    state = state.copyWith(window: window);
    await _db.setSetting('window', window.encode());
  }

  Future<void> setBody(BodyType body) async {
    state = state.copyWith(body: body);
    await _db.setSetting('body', body.name);
  }

  Future<void> setFieldShown(String key, bool shown) async {
    await _db.setFieldShown(key, shown);
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
      window: state.window,
      startDate: date,
      body: state.body,
    ).startMain;
    if (g != null && start != null) {
      final moved = Goal(targetWeightKg: g.targetWeightKg, targetDate: g.targetDate, startWeightKg: start.weightKg!);
      await _db.setSetting('goal', jsonEncode(moved.toJson()));
    }
    await _reload();
  }

  /// Keeps the original start weight when editing. A new goal starts from the
  /// chosen start weigh-in, or the latest main weigh-in when none is chosen.
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

  Future<void> exportCsv() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'body_log_${dateKey(DateTime.now())}.csv'));
    await file.writeAsString(buildCsv(state));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Body log export',
    ));
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
    'main_weigh_in',
    'weight_${u.weight}',
    for (final f in data.fields) '${f.label} (${u.length})',
  ];
  final rows = [
    header.map(q).join(','),
    for (final e in data.entries.reversed)
      [
        dateKey(e.date),
        hhmm(e.minutes),
        data.isMain(e) ? 'yes' : 'no',
        e.weightKg == null ? '' : u.fmtWeight(e.weightKg!),
        for (final f in data.fields)
          e.measurements[f.key] == null ? '' : u.fmtLength(e.measurements[f.key]!),
      ].join(','),
  ];
  return '${rows.join('\n')}\n';
}
