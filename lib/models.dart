enum TimeSlot {
  morning('Morning'),
  afterLunch('After lunch'),
  afterDinner('After dinner');

  const TimeSlot(this.label);
  final String label;

  /// Before 12:00 = morning, before 17:00 = after lunch, otherwise after dinner.
  static TimeSlot forTime(DateTime t) =>
      t.hour < 12 ? morning : (t.hour < 17 ? afterLunch : afterDinner);

  static TimeSlot parse(String s) =>
      values.firstWhere((v) => v.name == s, orElse: () => morning);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Entry {
  const Entry({
    this.id,
    required this.date,
    required this.slot,
    this.weightKg,
    this.measurements = const {},
  });

  final int? id;
  final DateTime date;
  final TimeSlot slot;
  final double? weightKg;

  /// Field key -> centimetres.
  final Map<String, double> measurements;

  bool get isMorning => slot == TimeSlot.morning;

  /// Newest first: later date, then later slot.
  static int newestFirst(Entry a, Entry b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.slot.index.compareTo(a.slot.index);
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

  /// Latest morning weight at the time the goal was set.
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
