import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';
import 'models.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_sheet.dart';
import 'state.dart';
import 'theme.dart';
import 'units.dart';

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
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  /// Set when editing an entry from history; cleared when leaving the Log tab.
  Entry? _editing;

  void _go(int tab) => setState(() {
        _tab = tab;
        if (tab != 1) _editing = null;
      });

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(appProvider.select((d) => d.unitSystem));
    final body = switch (_tab) {
      0 => DashboardScreen(onLog: () => _go(1)),
      1 => LogScreen(
          // Recreate the form when the target entry or the units change.
          key: ValueKey((_editing?.id, units)),
          editing: _editing,
          onSaved: () => _go(0),
        ),
      _ => HistoryScreen(onEdit: (e) => setState(() {
            _editing = e;
            _tab = 1;
          })),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('BODY LOG'),
        actions: [
          _UnitToggle(
            units: units,
            onTap: () => ref.read(appProvider.notifier).setUnits(
                units == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => showSettingsSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed), label: 'TODAY'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'LOG'),
          NavigationDestination(icon: Icon(Icons.history), label: 'HISTORY'),
        ],
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
