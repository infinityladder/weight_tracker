import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.onEdit});

  final void Function(Entry entry) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    if (data.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text('NO ENTRIES YET', style: display(28)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: readablePadding(context),
      itemCount: data.entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = data.entries[i];
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(color: badRed, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          // Delete here and keep the tile; the list rebuilds without it.
          confirmDismiss: (_) async {
            await confirmDelete(context, ref, e);
            return false;
          },
          child: _EntryTile(entry: e, data: data, onTap: () => _showActions(context, ref, e)),
        );
      },
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, Entry e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(DateFormat('EEEE d MMM yyyy').format(e.date).toUpperCase(), style: display(26)),
              Text(timeLabel(sheet, e.minutes), style: label(sheet)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  onEdit(e);
                },
                icon: const Icon(Icons.edit),
                label: const Text('EDIT'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await confirmDelete(context, ref, e);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('DELETE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: badRed,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: badRed, width: 2),
                  textStyle: display(20, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmDelete(BuildContext context, WidgetRef ref, Entry e) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Delete entry?'),
      content: Text(
          '${DateFormat('d MMM yyyy').format(e.date)}, ${timeLabel(context, e.minutes)}. This can\'t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          style: TextButton.styleFrom(foregroundColor: badRed),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true && e.id != null) await ref.read(appProvider.notifier).deleteEntry(e.id!);
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.data, required this.onTap});

  final Entry entry;
  final AppData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = data.units;
    final e = entry;
    final muted = scheme.onSurfaceVariant;
    final measures = [
      for (final f in data.fields)
        if (e.measurements[f.key] != null) '${f.label} ${u.fmtLength(e.measurements[f.key]!)}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEE d MMM yyyy').format(e.date).toUpperCase(), style: display(21)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(timeLabel(context, e.minutes),
                          style: display(13, weight: FontWeight.w700, color: muted)),
                    ),
                    if (measures.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${measures.join('  ·  ')} ${u.length}',
                          style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (e.weightKg != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: u.fmtWeight(e.weightKg!)),
                        TextSpan(text: ' ${u.weight}', style: display(16, color: muted)),
                      ]),
                      style: display(34),
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
