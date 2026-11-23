import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../csv_import.dart';
import '../models.dart';
import '../state.dart';

/// Saves the whole log as a CSV file wherever the user picks (Downloads, a
/// folder, Drive...).
Future<void> exportData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = ref.read(appProvider);
  if (data.entries.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
    return;
  }
  final name = 'body_log_${dateKey(DateTime.now())}.csv';
  try {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save your Body log',
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(buildCsv(data))),
      mimeType: 'text/csv',
    );
    if (saved != null) messenger.showSnackBar(SnackBar(content: Text('Saved $name')));
  } on Exception {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t save the file. Try another folder.')));
  }
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
