import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'body_map.dart';
import 'db.dart';
import 'models.dart';
import 'screens/trend_screen.dart';
import 'screens/data_transfer.dart';
import 'screens/history_screen.dart';
import 'screens/log_screen.dart';
import 'screens/measure_sheet.dart';
import 'screens/quick_entry_sheet.dart';
import 'screens/settings_sheet.dart';
import 'screens/start_sheet.dart';
import 'state.dart';
import 'theme.dart';
import 'units.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await BodyLogDb.open();
  final initial = await loadAppData(db);
  runApp(ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(initial),
    ],
    child: const BodyLogApp(),
  ));
}

class BodyLogApp extends StatelessWidget {
  const BodyLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Body log',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

/// Home: weight at the top, the body map in the middle, navigation at the bottom.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Field whose size picker is open; highlighted on the body meanwhile.
  String? _selected;

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _measure(MeasureField f) async {
    setState(() => _selected = f.key);
    final showTrend = await showMeasureSheet(context, f);
    if (!mounted) return;
    setState(() => _selected = null);
    if (showTrend) _push(TrendScreen(initialMetric: f.key));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    String? valueText(MeasureField f) {
      final v = data.latestMeasurement(f.key);
      return v == null ? null : '${u.fmtLength(v)} ${u.length}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BODY LOG'),
        actions: [
          _UnitToggle(
            units: data.unitSystem,
            onTap: () => ref.read(appProvider.notifier).setUnits(
                data.unitSystem == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => showSettingsSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              _WeightHeader(
                data: data,
                onTap: () => data.latestMain == null ? showQuickEntry(context) : _push(const TrendScreen()),
                onLog: () => showQuickEntry(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: data.visibleFields.isEmpty
                    ? Center(
                        child: OutlinedButton.icon(
                          onPressed: () => showSettingsSheet(context),
                          icon: const Icon(Icons.tune),
                          label: const Text('CHOOSE MEASUREMENTS'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: brandOrange, width: 2),
                            textStyle: display(20, weight: FontWeight.w800),
                          ),
                        ),
                      )
                    : BodyMap(
                        fields: data.visibleFields,
                        valueText: valueText,
                        selectedKey: _selected,
                        onTap: _measure,
                        body: data.body,
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _NavTile(
                    icon: Icons.table_rows_rounded,
                    label: 'VIEW DATA',
                    onTap: () => _push(const ViewDataScreen()),
                  ),
                  const SizedBox(width: 10),
                  _NavTile(
                    icon: Icons.show_chart,
                    label: 'TREND',
                    onTap: () => _push(const TrendScreen()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightHeader extends StatelessWidget {
  const _WeightHeader({required this.data, required this.onTap, required this.onLog});

  final AppData data;

  /// Tapping the number opens the weight trend.
  final VoidCallback onTap;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final latest = data.latestMain, first = data.startMain;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Shown whenever there's more than one weigh-in, so the start can always be changed.
    final delta = latest != null && first != null && data.mainWeights.length > 1
        ? latest.weightKg! - first.weightKg!
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(latest == null ? '—' : u.fmtWeight(latest.weightKg!),
                    style: display(88, color: brandOrange, spacing: -2)),
                const SizedBox(width: 6),
                Text(u.weight.toUpperCase(), style: display(28, color: muted)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  latest == null
                      ? 'NO WEIGHT YET'
                      : '${DateFormat('EEE d MMM').format(latest.date)} · ${timeLabel(context, latest.minutes)}'
                          .toUpperCase(),
                  style: label(context),
                ),
                const SizedBox(width: 10),
                Material(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onLog,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text('+ LOG', style: display(16, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            if (delta != null)
              Builder(builder: (context) {
                final flat = delta.abs() < 0.05;
                final color = flat ? muted : (delta < 0 ? goodGreen : badRed);
                // Tap to choose the starting weigh-in.
                return InkWell(
                  onTap: () => showStartSheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(flat ? Icons.remove : (delta < 0 ? Icons.arrow_downward : Icons.arrow_upward),
                            size: 18, color: color),
                        const SizedBox(width: 2),
                        Text('${u.fmtWeight(delta.abs())} ${u.weight}', style: display(18, color: color)),
                        Text('  since ${DateFormat('d MMM').format(first!.date)}'.toUpperCase(),
                            style: label(context)),
                        const SizedBox(width: 2),
                        Icon(Icons.edit_calendar, size: 16, color: muted),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: brandGradient),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(height: 4),
                  FittedBox(child: Text(label, style: display(18, color: Colors.white, spacing: 0.5))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// History with an add button; entries open the full log form.
class ViewDataScreen extends StatelessWidget {
  const ViewDataScreen({super.key});

  static void openLog(BuildContext context, {Entry? editing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Consumer(builder: (context, ref, _) {
          final units = ref.watch(appProvider.select((d) => d.unitSystem));
          return Scaffold(
            appBar: AppBar(title: Text(editing == null ? 'NEW ENTRY' : 'EDIT ENTRY')),
            body: LogScreen(
              // Recreate the form when the units change.
              key: ValueKey(units),
              editing: editing,
              onSaved: () => Navigator.pop(context),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DATA'),
        actions: [
          Consumer(
            builder: (context, ref, _) => Row(
              children: [
                IconButton(
                  tooltip: 'Import CSV',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => importData(context, ref),
                ),
                IconButton(
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => exportData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: HistoryScreen(onEdit: (e) => openLog(context, editing: e)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openLog(context),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('ADD ENTRY', style: display(18, color: Colors.white)),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.units, required this.onTap});

  final UnitSystem units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget part(String text, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? brandOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: display(15, weight: FontWeight.w800, color: on ? Colors.white : scheme.onSurfaceVariant)),
        );
    return Tooltip(
      message: 'Switch units',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            part('KG', units == UnitSystem.metric),
            part('LB', units == UnitSystem.imperial),
          ]),
        ),
      ),
    );
  }
}
