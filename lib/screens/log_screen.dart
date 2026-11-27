import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';
import 'settings_sheet.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key, this.editing, required this.onSaved});

  /// Entry opened from history; null for a new entry.
  final Entry? editing;
  final VoidCallback onSaved;

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  late DateTime _date;
  late int _minutes;
  final _weight = TextEditingController();
  final _fields = <String, TextEditingController>{};
  bool _saving = false;

  TextEditingController _ctrl(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final e = widget.editing;
    _date = e?.date ?? dateOnly(now);
    _minutes = e?.minutes ?? minutesOf(now);
    if (e != null) _fill(e);
  }

  @override
  void dispose() {
    _weight.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Entry e) {
    final data = ref.read(appProvider);
    final u = data.units;
    _weight.text = e.weightKg == null ? '' : u.fmtWeight(e.weightKg!);
    for (final f in data.fields) {
      final v = e.measurements[f.key];
      _ctrl(f.key).text = v == null ? '' : u.fmtLength(v);
    }
  }

  /// For a new entry, landing on an existing entry's date + time loads it,
  /// since saving will update that entry.
  void _moved() {
    if (widget.editing != null) return;
    final existing = ref.read(appProvider).entryAt(_date, _minutes);
    if (existing != null) _fill(existing);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _date = dateOnly(picked);
        _moved();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
    );
    if (picked != null) {
      setState(() {
        _minutes = picked.hour * 60 + picked.minute;
        _moved();
      });
    }
  }

  /// Another entry already at the selected date + time (not the one being edited).
  Entry? _clash(AppData data) {
    final e = data.entryAt(_date, _minutes);
    return e != null && e.id != widget.editing?.id ? e : null;
  }

  Future<void> _save() async {
    final data = ref.read(appProvider);
    final u = data.units;
    final weight = parseNumber(_weight.text);
    final base = widget.editing ?? _clash(data);
    // Start from the existing values so removed (hidden) fields keep their data.
    final measurements = {...?base?.measurements};
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
    await ref.read(appProvider.notifier).saveEntry(Entry(
          id: widget.editing?.id,
          date: _date,
          minutes: _minutes,
          weightKg: weight == null ? null : u.weightIn(weight),
          measurements: measurements,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(base != null ? 'Entry updated' : 'Entry saved'),
    ));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    final scheme = Theme.of(context).colorScheme;
    final clash = _clash(data);
    final updating = widget.editing != null || clash != null;
    final fields = data.visibleFields;

    return ListView(
      padding: readablePadding(context),
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(DateFormat('EEE d MMM yyyy').format(_date),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: display(24, weight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Time'),
                  child: Text(timeLabel(context, _minutes),
                      maxLines: 1, style: display(24, weight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
        if (updating)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(clash != null && widget.editing != null ? Icons.warning_amber : Icons.edit_note,
                    size: 20, color: brandOrange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    clash != null && widget.editing != null
                        ? 'Another entry exists at this date and time – saving replaces it'
                        : 'Editing the existing entry at this date and time',
                    style: const TextStyle(color: brandOrange, fontWeight: FontWeight.w600),
                  ),
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
          child: Text(updating ? 'UPDATE ENTRY' : 'SAVE ENTRY'),
        ),
      ],
    );
  }
}
