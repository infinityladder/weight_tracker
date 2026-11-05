import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import 'start_sheet.dart';

Future<void> showGoalSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _GoalSheet(),
);

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet();

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final TextEditingController _target;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final data = ref.read(appProvider);
    final goal = data.goal;
    _target = TextEditingController(text: goal == null ? '' : data.units.fmtWeight(goal.targetWeightKg));
    _date = goal?.targetDate ?? dateOnly(DateTime.now()).add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final value = parseNumber(_target.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a target weight')));
      return;
    }
    final units = ref.read(appProvider).units;
    await ref.read(appProvider.notifier).setGoal(units.weightIn(value), _date);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    await ref.read(appProvider.notifier).removeGoal();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    final start = data.goal?.startWeightKg ?? (data.startDate != null ? data.startMain : data.latestMain)?.weightKg;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(data.goal == null ? 'SET GOAL' : 'EDIT GOAL', style: display(32)),
          if (start != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Starting from ${u.fmtWeight(start)} ${u.weight}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showStartSheet(context),
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Pick from history'),
                ),
              ],
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _target,
            autofocus: data.goal == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: display(28, weight: FontWeight.w800),
            decoration: InputDecoration(labelText: 'Target weight', suffixText: u.weight),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Target date', suffixIcon: Icon(Icons.calendar_today)),
              child: Text(DateFormat('EEE d MMM yyyy').format(_date), style: display(24, weight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('SAVE GOAL')),
          if (data.goal != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _remove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove goal'),
              style: TextButton.styleFrom(foregroundColor: badRed),
            ),
          ],
        ],
      ),
    );
  }
}
