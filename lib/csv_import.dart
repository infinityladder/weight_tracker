import 'models.dart';
import 'units.dart';

/// What a CSV file holds, ready to merge into the log.
class CsvImport {
  CsvImport({required this.entries, required this.skippedColumns, required this.badRows});

  /// One per data row, in kg and cm.
  final List<Entry> entries;

  /// Column headings that don't match any measurement.
  final List<String> skippedColumns;

  /// 1-based line numbers that couldn't be read.
  final List<int> badRows;
}

class CsvImportException implements Exception {
  CsvImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads a CSV in the format [buildCsv] writes: date, optional time, an
/// optional weight column ("weight_kg" / "weight_lb") and one column per
/// measurement ("Waist (cm)", "Waist (in)" or just "Waist"), matched to
/// [fields] by name. The main_weigh_in column is ignored; it's worked out
/// from the time.
CsvImport parseCsvImport(String text, List<MeasureField> fields) {
  final rows = _parseCsv(text.replaceFirst('﻿', ''));
  if (rows.isEmpty) throw CsvImportException('The file is empty.');
  final header = [for (final h in rows.first) h.trim()];
  final lower = [for (final h in header) h.toLowerCase()];

  final dateCol = lower.indexOf('date');
  if (dateCol < 0) throw CsvImportException('No "date" column found. Is this a Body log export?');
  final timeCol = lower.indexOf('time');

  int? weightCol;
  var weightUnit = UnitSystem.metric;
  final measureCols = <int, (String, UnitSystem)>{};
  final skipped = <String>[];
  final byLabel = {for (final f in fields) f.label.toLowerCase(): f.key};

  for (final (i, h) in lower.indexed) {
    if (i == dateCol || i == timeCol || h == 'main_weigh_in' || h.isEmpty) continue;
    final weight = RegExp(r'^weight(?:[ _(]+(kg|lb)\)?)?$').firstMatch(h);
    if (weight != null) {
      weightCol = i;
      weightUnit = weight.group(1) == 'lb' ? UnitSystem.imperial : UnitSystem.metric;
      continue;
    }
    final m = RegExp(r'^(.*?)\s*(?:\((cm|in)\))?$').firstMatch(h)!;
    final key = byLabel[m.group(1)!.trim()];
    if (key == null) {
      skipped.add(header[i]);
    } else {
      measureCols[i] = (key, m.group(2) == 'in' ? UnitSystem.imperial : UnitSystem.metric);
    }
  }

  final entries = <Entry>[];
  final bad = <int>[];
  for (final (n, row) in rows.indexed.skip(1)) {
    if (row.every((c) => c.trim().isEmpty)) continue;
    String cell(int i) => i < row.length ? row[i].trim() : '';
    final date = DateTime.tryParse(cell(dateCol));
    final minutes = timeCol < 0 || cell(timeCol).isEmpty ? 8 * 60 : _minutes(cell(timeCol));
    if (date == null || minutes == null) {
      bad.add(n + 1);
      continue;
    }
    final w = weightCol == null ? null : parseNumber(cell(weightCol));
    final measurements = <String, double>{
      for (final MapEntry(key: i, value: (key, unit)) in measureCols.entries)
        if (parseNumber(cell(i)) case final v?) key: Units(unit).lengthIn(v),
    };
    if (w == null && measurements.isEmpty) continue;
    entries.add(
      Entry(
        date: dateOnly(date),
        minutes: minutes,
        weightKg: w == null ? null : Units(weightUnit).weightIn(w),
        measurements: measurements,
      ),
    );
  }
  return CsvImport(entries: entries, skippedColumns: skipped, badRows: bad);
}

/// "07:05" -> 425; null if it isn't a 24h time.
int? _minutes(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

/// Minimal RFC 4180 reader: quoted fields may hold commas, quotes ("") and newlines.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
