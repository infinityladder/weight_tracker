import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';
import 'data_transfer.dart';

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
  Widget _dataButton(IconData icon, String text, VoidCallback onPressed) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(text),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      side: const BorderSide(color: brandOrange, width: 2),
      textStyle: display(20, weight: FontWeight.w800),
    ),
  );

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

    return _PinnedDoneSheet(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
          Text(
            'Weights logged in this time range are your main record (headline, chart, goal). '
            'Others are notes.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _timeButton(data.window.start, 'From', (m) => WeighWindow(m, data.window.end))),
              const SizedBox(width: 12),
              Expanded(child: _timeButton(data.window.end, 'To', (m) => WeighWindow(data.window.start, m))),
            ],
          ),
          const SizedBox(height: 24),
          Text('BODY', style: label(context)),
          const SizedBox(height: 8),
          BodyTypePicker(data: data),
          const SizedBox(height: 24),
          Text('MEASUREMENTS', style: label(context)),
          const SizedBox(height: 4),
          Text(
            'Pick what shows on your body. Switching one off keeps its past values.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          MeasurePicker(data: data),
          const SizedBox(height: 24),
          Text('CUSTOM', style: label(context)),
          const SizedBox(height: 4),
          Text(
            'Three measurements of your own. They show in a row under the body.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final f in data.fields.where((f) => f.custom))
            Padding(padding: const EdgeInsets.only(bottom: 10), child: CustomMeasureRow(field: f)),
          const SizedBox(height: 14),
          Text('DATA', style: label(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dataButton(Icons.file_download_outlined, 'IMPORT', () => importData(context, ref))),
              const SizedBox(width: 12),
              Expanded(child: _dataButton(Icons.ios_share, 'EXPORT', () => exportData(context, ref))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sheet body that scrolls above a DONE button that always stays in view,
/// clear of the system navigation bar.
class _PinnedDoneSheet extends StatelessWidget {
  const _PinnedDoneSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('DONE')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips for the standard measurements; tap to show or hide one.
class MeasurePicker extends ConsumerWidget {
  const MeasurePicker({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in data.standardFields.where((f) => !f.custom))
          FilterChip(
            label: Text(f.label.toUpperCase()),
            selected: !f.hidden,
            showCheckmark: true,
            checkmarkColor: Colors.white,
            labelStyle: display(17, weight: FontWeight.w700, color: f.hidden ? scheme.onSurface : Colors.white),
            onSelected: (on) => ref.read(appProvider.notifier).setFieldShown(f.key, on),
          ),
      ],
    );
  }
}

/// Name box and on/off switch for one custom measurement. The name is saved as
/// it's typed; an empty box keeps the previous name.
class CustomMeasureRow extends ConsumerStatefulWidget {
  const CustomMeasureRow({super.key, required this.field});

  final MeasureField field;

  @override
  ConsumerState<CustomMeasureRow> createState() => _CustomMeasureRowState();
}

class _CustomMeasureRowState extends ConsumerState<CustomMeasureRow> {
  late final _name = TextEditingController(text: widget.field.label);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Name', counterText: ''),
            onChanged: (t) => notifier.renameField(widget.field.key, t),
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: !widget.field.hidden,
          activeTrackColor: brandOrange,
          onChanged: (on) => notifier.setFieldShown(widget.field.key, on),
        ),
      ],
    );
  }
}

/// Male / female figure toggle.
class BodyTypePicker extends ConsumerWidget {
  const BodyTypePicker({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<BodyType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: BodyType.male, icon: Icon(Icons.male), label: Text('MALE')),
        ButtonSegment(value: BodyType.female, icon: Icon(Icons.female), label: Text('FEMALE')),
      ],
      selected: {data.body},
      onSelectionChanged: (s) => ref.read(appProvider.notifier).setBody(s.first),
    );
  }
}
