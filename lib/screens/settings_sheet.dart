import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SettingsSheet(),
    );

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _newField = TextEditingController();

  @override
  void dispose() {
    _newField.dispose();
    super.dispose();
  }

  Future<void> _addField() async {
    final name = _newField.text.trim();
    if (name.isEmpty) return;
    final taken = ref
        .read(appProvider)
        .visibleFields
        .any((f) => f.label.toLowerCase() == name.toLowerCase());
    if (taken) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$name" is already a field')));
      return;
    }
    await ref.read(appProvider.notifier).addField(name);
    _newField.clear();
  }

  Future<void> _removeField(String key, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: const Text('It will be hidden from logging and charts. Past values are kept '
            'and still included in CSV exports. Add it again to bring it back.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await ref.read(appProvider.notifier).removeField(key);
  }

  Widget _timeButton(int minutes, String caption, WeighWindow Function(int) update) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (picked != null) {
          await ref.read(appProvider.notifier).setWindow(update(picked.hour * 60 + picked.minute));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: caption),
        child: Text(timeLabel(context, minutes), style: display(24, weight: FontWeight.w800)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('SETTINGS', style: display(32)),
            const SizedBox(height: 18),
            Text('UNITS', style: label(context)),
            const SizedBox(height: 8),
            SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: UnitSystem.metric, label: Text('KG / CM')),
                ButtonSegment(value: UnitSystem.imperial, label: Text('LB / IN')),
              ],
              selected: {data.unitSystem},
              onSelectionChanged: (s) => ref.read(appProvider.notifier).setUnits(s.first),
            ),
            const SizedBox(height: 24),
            Text('MAIN WEIGH-IN WINDOW', style: label(context)),
            const SizedBox(height: 4),
            Text('Weights logged in this time range are your main record (headline, chart, goal). '
                'Others are notes.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _timeButton(data.window.start, 'From', (m) => WeighWindow(m, data.window.end))),
                const SizedBox(width: 12),
                Expanded(child: _timeButton(data.window.end, 'To', (m) => WeighWindow(data.window.start, m))),
              ],
            ),
            const SizedBox(height: 24),
            Text('MEASUREMENT FIELDS', style: label(context)),
            const SizedBox(height: 4),
            for (final f in data.visibleFields)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                trailing: f.builtIn
                    ? Text('built in', style: TextStyle(color: scheme.onSurfaceVariant))
                    : IconButton(
                        tooltip: 'Remove field',
                        icon: const Icon(Icons.remove_circle_outline, color: badRed),
                        onPressed: () => _removeField(f.key, f.label),
                      ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newField,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'New field (e.g. Chest, Neck, Arm)'),
                    onSubmitted: (_) => _addField(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _addField,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: brandOrange,
                    minimumSize: const Size(58, 58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('DATA', style: label(context)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: data.entries.isEmpty ? null : () => ref.read(appProvider.notifier).exportCsv(),
              icon: const Icon(Icons.ios_share),
              label: const Text('EXPORT CSV'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: brandOrange, width: 2),
                textStyle: display(20, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
