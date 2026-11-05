import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../csv_import.dart';
import '../state.dart';

/// Shares the whole log as a CSV file.
Future<void> exportData(BuildContext context, WidgetRef ref) async {
  if (ref.read(appProvider).entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
    return;
  }
  await ref.read(appProvider.notifier).exportCsv();
}

/// Picks a CSV (a Body log export), merges it into the log and reports what happened.
Future<void> importData(BuildContext context, WidgetRef ref) async {
  final file = await FilePicker.pickFile(dialogTitle: 'Import a Body log CSV');
  if (file == null || !context.mounted) return;

  String title;
  final lines = <String>[];
  try {
    final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final r = await ref.read(appProvider.notifier).importCsv(text);
    title = r.added + r.updated == 0 ? 'Nothing imported' : 'Import done';
    lines.add('${r.added} new ${r.added == 1 ? 'entry' : 'entries'} added, ${r.updated} updated.');
    if (r.skippedColumns.isNotEmpty) {
      lines.add('Skipped columns that aren\'t measurements here: ${r.skippedColumns.join(', ')}.');
    }
    if (r.badRows.isNotEmpty) {
      final shown = r.badRows.take(8).join(', ');
      lines.add(
        'Couldn\'t read line${r.badRows.length == 1 ? '' : 's'} $shown'
        '${r.badRows.length > 8 ? ' and ${r.badRows.length - 8} more' : ''} (date should be YYYY-MM-DD, time HH:MM).',
      );
    }
  } on CsvImportException catch (e) {
    title = 'Couldn\'t import';
    lines.add(e.message);
  } on FormatException {
    title = 'Couldn\'t import';
    lines.add('That file isn\'t a readable CSV.');
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(lines.join('\n\n')),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
    ),
  );
}
