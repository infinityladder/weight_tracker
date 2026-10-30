import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import 'settings_sheet.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key, this.initialDate, this.initialSlot, required this.onSaved});

  final DateTime? initialDate;
  final TimeSlot? initialSlot;
  final VoidCallback onSaved;

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  late DateTime _date;
  late TimeSlot _slot;
  final _weight = TextEditingController();
  final _fields = <String, TextEditingController>{};
  bool _saving = false;

  TextEditingController _ctrl(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = dateOnly(widget.initialDate ?? now);
    _slot = widget.initialSlot ?? TimeSlot.forTime(now);
    _fill();
  }

  @override
  void dispose() {
    _weight.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Loads the existing entry for the selected date + slot, or clears the form.
  void _fill() {
    final data = ref.read(appProvider);
    final u = data.units;
    final e = data.entryFor(_date, _slot);
    _weight.text = e?.weightKg == null ? '' : u.fmtWeight(e!.weightKg!);
    for (final f in data.fields) {
      final v = e?.measurements[f.key];
      _ctrl(f.key).text = v == null ? '' : u.fmtLength(v);
    }
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _date = dateOnly(picked);
        _fill();
      });
    }
  }

  Future<void> _save() async {
    final data = ref.read(appProvider);
    final u = data.units;
    final weight = parseNumber(_weight.text);
    // Start from the existing values so removed (hidden) fields keep their data.
    final measurements = {...?data.entryFor(_date, _slot)?.measurements};
    for (final f in data.visibleFields) {
      final v = parseNumber(_ctrl(f.key).text);
      if (v == null) {
        measurements.remove(f.key);
      } else {
        measurements[f.key] = u.lengthIn(v);
      }
    }
    if (weight == null && measurements.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a weight or at least one measurement')));
      return;
    }
    setState(() => _saving = true);
    final existed = data.entryFor(_date, _slot) != null;
    await ref.read(appProvider.notifier).saveEntry(Entry(
          date: _date,
          slot: _slot,
          weightKg: weight == null ? null : u.weightIn(weight),
          measurements: measurements,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(existed ? 'Entry updated' : 'Entry saved'),
    ));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    final scheme = Theme.of(context).colorScheme;
    final existing = data.entryFor(_date, _slot) != null;
    final fields = data.visibleFields;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today)),
            child: Text(DateFormat('EEEE d MMM yyyy').format(_date),
                style: display(24, weight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<TimeSlot>(
          showSelectedIcon: false,
          segments: [
            for (final s in TimeSlot.values) ButtonSegment(value: s, label: Text(s.label.toUpperCase())),
          ],
          selected: {_slot},
          onSelectionChanged: (s) => setState(() {
            _slot = s.first;
            _fill();
          }),
        ),
        if (existing)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20, color: brandOrange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Editing the existing ${_slot.label.toLowerCase()} entry for this date',
                      style: const TextStyle(color: brandOrange, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('WEIGHT', style: label(context)),
        const SizedBox(height: 8),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: display(40),
          decoration: InputDecoration(
            hintText: '0.0',
            suffixText: u.weight,
            suffixStyle: display(24, color: scheme.onSurfaceVariant),
            helperMaxLines: 2,
            helperText: _slot == TimeSlot.morning
                ? 'Morning weight is your main record'
                : 'Lunch/dinner weights are notes only – not used for your trend or goal',
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('MEASUREMENTS (${u.length.toUpperCase()})', style: label(context))),
            TextButton.icon(
              onPressed: () => showSettingsSheet(context),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Fields'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in fields)
                  SizedBox(
                    width: w,
                    child: TextField(
                      controller: _ctrl(f.key),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: display(26, weight: FontWeight.w800),
                      decoration: InputDecoration(labelText: f.label, suffixText: u.length),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(existing ? 'UPDATE ENTRY' : 'SAVE ENTRY'),
        ),
      ],
    );
  }
}
