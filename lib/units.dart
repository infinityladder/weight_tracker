enum UnitSystem { metric, imperial }

/// Values are stored in kg / cm and converted only for display and input.
class Units {
  const Units(this.system);

  static const kgPerLb = 0.45359237;
  static const cmPerIn = 2.54;

  final UnitSystem system;

  bool get metric => system == UnitSystem.metric;
  String get weight => metric ? 'kg' : 'lb';
  String get length => metric ? 'cm' : 'in';

  double weightOut(double kg) => metric ? kg : kg / kgPerLb;
  double weightIn(double value) => metric ? value : value * kgPerLb;
  double lengthOut(double cm) => metric ? cm : cm / cmPerIn;
  double lengthIn(double value) => metric ? value : value * cmPerIn;

  String fmtWeight(double kg) => weightOut(kg).toStringAsFixed(1);
  String fmtLength(double cm) => lengthOut(cm).toStringAsFixed(1);
}

/// Parses user input, accepting a comma as decimal separator.
double? parseNumber(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return v != null && v > 0 ? v : null;
}
