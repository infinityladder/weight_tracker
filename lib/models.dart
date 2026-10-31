DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Minutes since midnight as 24h "HH:mm".
String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

int minutesOf(DateTime t) => t.hour * 60 + t.minute;

/// Time of day range whose weights count as the main record. Inclusive at both
/// ends; may wrap past midnight (e.g. 22:00–02:00).
class WeighWindow {
  const WeighWindow(this.start, this.end);

  static const defaultWindow = WeighWindow(6 * 60, 10 * 60);

  final int start;
  final int end;

  bool contains(int minutes) =>
      start <= end ? minutes >= start && minutes <= end : minutes >= start || minutes <= end;

  String encode() => '$start-$end';

  static WeighWindow decode(String? s) {
    final parts = s?.split('-');
    if (parts == null || parts.length != 2) return defaultWindow;
    final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
    return a == null || b == null ? defaultWindow : WeighWindow(a, b);
  }

  @override
  bool operator ==(Object other) => other is WeighWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class Entry {
  const Entry({
    this.id,
    required this.date,
    required this.minutes,
    this.weightKg,
    this.measurements = const {},
  });

  final int? id;
  final DateTime date;

  /// Time of day the entry was logged, in minutes since midnight.
  final int minutes;
  final double? weightKg;

  /// Field key -> centimetres.
  final Map<String, double> measurements;

  /// Newest first: later date, then later time.
  static int newestFirst(Entry a, Entry b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.minutes.compareTo(a.minutes);
  }
}

class MeasureField {
  const MeasureField({
    required this.key,
    required this.label,
    required this.builtIn,
    required this.hidden,
    required this.sortOrder,
  });

  final String key;
  final String label;
  final bool builtIn;

  /// Removed custom fields are hidden, so their past values are kept.
  final bool hidden;
  final int sortOrder;
}

class Goal {
  const Goal({
    required this.targetWeightKg,
    required this.targetDate,
    required this.startWeightKg,
  });

  final double targetWeightKg;
  final DateTime targetDate;

  /// Latest main weigh-in at the time the goal was set.
  final double startWeightKg;

  Map<String, Object> toJson() => {
        'targetWeightKg': targetWeightKg,
        'targetDate': dateKey(targetDate),
        'startWeightKg': startWeightKg,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        targetWeightKg: (j['targetWeightKg'] as num).toDouble(),
        targetDate: DateTime.parse(j['targetDate'] as String),
        startWeightKg: (j['startWeightKg'] as num).toDouble(),
      );
}

class GoalProgress {
  GoalProgress({
    required this.goal,
    required this.currentKg,
    required DateTime today,
  }) : daysLeft = dateOnly(goal.targetDate).difference(dateOnly(today)).inDays;

  final Goal goal;
  final double currentKg;
  final int daysLeft;

  double get start => goal.startWeightKg;
  double get target => goal.targetWeightKg;
  bool get losing => target < start;

  bool get reached => losing ? currentKg <= target : currentKg >= target;

  /// 0..1 of the way from start to target.
  double get fraction {
    final total = start - target;
    if (total == 0) return 1;
    return ((start - currentKg) / total).clamp(0.0, 1.0);
  }

  double get leftKg => reached ? 0 : (currentKg - target).abs();

  /// Signed kg per week still needed (negative = lose). Null when no time left.
  double? get perWeekKg =>
      daysLeft > 0 && !reached ? (target - currentKg) / (daysLeft / 7) : null;
}
