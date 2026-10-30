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
  const AppData({
    required this.entries,
    required this.fields,
    required this.goal,
    required this.unitSystem,
  });

  /// Newest first.
  final List<Entry> entries;
  final List<MeasureField> fields;
  final Goal? goal;
  final UnitSystem unitSystem;

  Units get units => Units(unitSystem);

  List<MeasureField> get visibleFields => fields.where((f) => !f.hidden).toList();

  /// Morning entries that have a weight, newest first. These are the main record.
  List<Entry> get morningWeights =>
      entries.where((e) => e.isMorning && e.weightKg != null).toList();

  Entry? get latestMorning => morningWeights.firstOrNull;
  Entry? get firstMorning => morningWeights.lastOrNull;

  Entry? entryFor(DateTime date, TimeSlot slot) {
    final d = dateOnly(date);
    return entries.where((e) => e.date == d && e.slot == slot).firstOrNull;
  }

  /// Lunch/dinner weights logged on [day], in slot order.
  List<Entry> notesFor(DateTime day) {
    final d = dateOnly(day);
    return entries.where((e) => e.date == d && !e.isMorning && e.weightKg != null).toList()
      ..sort((a, b) => a.slot.index.compareTo(b.slot.index));
  }

  GoalProgress? progress(DateTime today) {
    final g = goal, latest = latestMorning;
    if (g == null || latest == null) return null;
    return GoalProgress(goal: g, currentKg: latest.weightKg!, today: today);
  }

  String labelFor(String key) =>
      fields.where((f) => f.key == key).firstOrNull?.label ?? key;

  AppData copyWith({UnitSystem? unitSystem}) => AppData(
        entries: entries,
        fields: fields,
        goal: goal,
        unitSystem: unitSystem ?? this.unitSystem,
      );
}

Future<AppData> loadAppData(BodyLogDb db) async {
  final goalJson = await db.setting('goal');
  return AppData(
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

  Future<void> addField(String label) async {
    await _db.addField(label);
    await _reload();
  }

  Future<void> removeField(String key) async {
    await _db.hideField(key);
    await _reload();
  }

  /// Keeps the original start weight when editing; uses the latest morning
  /// weight when setting a new goal.
  Future<void> setGoal(double targetKg, DateTime targetDate) async {
    final start = state.goal?.startWeightKg ?? state.latestMorning?.weightKg;
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
    'time_slot',
    'weight_${u.weight}',
    for (final f in data.fields) '${f.label} (${u.length})',
  ];
  final rows = [
    header.map(q).join(','),
    for (final e in data.entries.reversed)
      [
        dateKey(e.date),
        e.slot.name,
        e.weightKg == null ? '' : u.fmtWeight(e.weightKg!),
        for (final f in data.fields)
          e.measurements[f.key] == null ? '' : u.fmtLength(e.measurements[f.key]!),
      ].join(','),
  ];
  return '${rows.join('\n')}\n';
}
