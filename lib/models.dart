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

  /// One of the standard measurements users can switch on. Fields from older
  /// versions that aren't standard stay hidden but keep their values.
  final bool builtIn;

  /// Switched off; past values are kept.
  final bool hidden;
  final int sortOrder;

  /// One of the measurements the user names; never placed on the body.
  bool get custom => customMeasureKeys.contains(key);
}

/// Keys of the user-named measurements, in order.
const customMeasureKeys = ['c_custom_1', 'c_custom_2', 'c_custom_3'];

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

/// Body mass index from a weight and height.
double bmi(double kg, double heightCm) => kg / ((heightCm / 100) * (heightCm / 100));

/// Which BMI cut-offs to use. [asian] lowers the overweight and obese
/// thresholds to 23 and 27.5 (WHO 2004 expert consultation; NICE uses them
/// for people of Asian, Middle Eastern, Black African and African-Caribbean
/// family background), since health risks start at a lower BMI.
enum BmiRanges { standard, asian }

/// Adult BMI category (WHO).
String bmiCategory(double bmi, [BmiRanges ranges = BmiRanges.standard]) {
  final asian = ranges == BmiRanges.asian;
  if (bmi < 18.5) return 'Underweight';
  if (bmi < (asian ? 23 : 25)) return 'Healthy';
  if (bmi < (asian ? 27.5 : 30)) return 'Overweight';
  return 'Obese';
}

/// NICE category for a waist-to-height ratio. Under 0.4 isn't graded by
/// NICE; it's shown as low.
String waistRatioCategory(double ratio) => ratio < 0.4
    ? 'Low'
    : ratio < 0.5
        ? 'Healthy'
        : ratio < 0.6
            ? 'Increased risk'
            : 'High risk';

/// WHO (2008) waist-to-hip limit above which health risk is substantially
/// increased: 0.90 for men, 0.85 for women.
double waistHipLimit(BodyType body) => body == BodyType.male ? 0.90 : 0.85;

/// WHO category for a waist-to-hip ratio.
String waistHipCategory(double ratio, BodyType body) => ratio < waistHipLimit(body) ? 'Healthy' : 'Increased risk';

/// Analyses the Health screen can show; the user picks which in Settings.
enum HealthAnalysis {
  bmi,
  waistRatio,
  waistHip;

  /// Needs the user's height.
  bool get usesHeight => this != waistHip;

  /// Stored as a comma list; unknown names are ignored. Null (never set)
  /// means all of them.
  static Set<HealthAnalysis> decode(String? s) => s == null
      ? values.toSet()
      : {for (final n in s.split(',')) ...values.where((a) => a.name == n)};

  static String encode(Set<HealthAnalysis> shown) => [for (final a in values) if (shown.contains(a)) a.name].join(',');
}

/// Which figure the body map draws.
enum BodyType { male, female }

/// Skin colour of the body figure, lightest first. [light] is the original
/// picture; the others are made by tool/skin_tones.py.
enum SkinTone {
  light,
  medium,
  tan,
  brown,
  deep;

  static SkinTone decode(String? name) => values.firstWhere((t) => t.name == name, orElse: () => light);
}
