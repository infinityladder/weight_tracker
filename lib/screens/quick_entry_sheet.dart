import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

/// Logs a weight at a chosen date + time (defaults to now).
Future<void> showQuickEntry(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WeightSheet(),
    );

class _WeightSheet extends ConsumerStatefulWidget {
  const _WeightSheet();

  @override
  ConsumerState<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<_WeightSheet> {
  final _value = TextEditingController();
  late DateTime _date;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = dateOnly(now);
    _minutes = minutesOf(now);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
    );
    if (picked != null) setState(() => _minutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    final value = parseNumber(_value.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a weight')));
      return;
    }
    final data = ref.read(appProvider);
    // Keep any measurements already logged at that exact time.
    final existing = data.entryAt(_date, _minutes);
    await ref.read(appProvider.notifier).saveEntry(Entry(
          id: existing?.id,
          date: _date,
          minutes: _minutes,
          weightKg: data.units.weightIn(value),
          measurements: existing?.measurements ?? const {},
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    final scheme = Theme.of(context).colorScheme;
    final last = data.latestMain?.weightKg;
    final inWindow = data.window.contains(_minutes);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('WEIGHT', style: display(34)),
          if (last != null)
            Text('Last: ${u.fmtWeight(last)} ${u.weight}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: display(56),
            decoration: InputDecoration(
              hintText: '0.00',
              suffixText: u.weight,
              suffixStyle: display(26, color: scheme.onSurfaceVariant),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('EEE d MMM').format(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(timeLabel(context, _minutes)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inWindow ? 'Main weigh-in' : 'Outside main window – saved as a note',
            textAlign: TextAlign.center,
            style: TextStyle(color: inWindow ? brandOrange : scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
    );
  }
}
