import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models.dart';
import '../state.dart';
import '../theme.dart';

/// Calendar of weigh-ins; the chosen day becomes the starting point for
/// "since start" and the goal. Does nothing when there are no weigh-ins.
Future<void> showStartSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(appProvider).mainWeights.isEmpty) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _StartSheet(),
  );
}

class _StartSheet extends ConsumerStatefulWidget {
  const _StartSheet();

  @override
  ConsumerState<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends ConsumerState<_StartSheet> {
  late DateTime _picked = ref.read(appProvider).startMain!.date;

  Future<void> _save(DateTime? date) async {
    await ref.read(appProvider.notifier).setStartDate(date);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final u = data.units;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final first = data.firstMain!.date, last = data.latestMain!.date;
    final picked = data.mainWeights.firstWhere((e) => e.date == _picked);
    final fmt = DateFormat('d MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('START WEIGH-IN', textAlign: TextAlign.center, style: display(26)),
            const SizedBox(height: 2),
            Text('Weigh-ins from ${fmt.format(first)} to ${fmt.format(last)}',
                textAlign: TextAlign.center, style: TextStyle(color: muted)),
            CalendarDatePicker(
              initialDate: _picked,
              firstDate: first,
              lastDate: last,
              selectableDayPredicate: (d) => data.mainDates.contains(dateOnly(d)),
              onDateChanged: (d) => setState(() => _picked = dateOnly(d)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(u.fmtWeight(picked.weightKg!), style: display(44, color: brandOrange)),
                const SizedBox(width: 4),
                Text(u.weight.toUpperCase(), style: display(20, color: muted)),
                const SizedBox(width: 12),
                Text(DateFormat('EEE d MMM').format(picked.date).toUpperCase(), style: label(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _save(null),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      side: const BorderSide(color: brandOrange, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: display(18, weight: FontWeight.w800),
                    ),
                    child: const Text('FIRST WEIGH-IN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => _save(_picked), child: const Text('USE AS START'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
