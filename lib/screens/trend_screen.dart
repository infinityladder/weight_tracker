import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'goal_sheet.dart';
import 'measure_sheet.dart';
import 'quick_entry_sheet.dart';
import 'start_sheet.dart';

/// Trend chart (opening on [initialMetric]) followed by the analysis cards
/// for the chosen metric.
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key, this.initialMetric = 'weight'});

  /// 'weight' or a field key.
  final String initialMetric;

  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  late String _metric = widget.initialMetric;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final field = data.visibleFields.where((f) => f.key == _metric).firstOrNull;
    if (field == null) _metric = 'weight';
    return Scaffold(
      appBar: AppBar(
        title: const Text('TREND'),
        actions: [
          TextButton.icon(
            onPressed: () => field == null ? showQuickEntry(context) : showMeasureSheet(context, field),
            icon: const Icon(Icons.add),
            label: Text(
              field == null ? 'LOG WEIGHT' : 'LOG ${field.label.toUpperCase()}',
              style: display(17, color: brandOrange),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: readablePadding(context),
        children: [
          TrendCard(data: data, metric: _metric, onMetric: (m) => setState(() => _metric = m), chartHeight: 280),
          const SizedBox(height: 16),
          if (field == null) ...[
            Scoreboard(data: data, onLog: () => showQuickEntry(context)),
            const SizedBox(height: 16),
            GoalCard(data: data),
            const SizedBox(height: 16),
            StatsCard(data: data),
          ] else
            PartCard(data: data, field: field),
        ],
      ),
    );
  }
}

/// Latest value, change since first and range for one measurement.
class PartCard extends StatelessWidget {
  const PartCard({super.key, required this.data, required this.field});

  final AppData data;
  final MeasureField field;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Newest first.
    final logged = [
      for (final e in data.entries)
        if (e.measurements[field.key] != null) (e.date, u.lengthOut(e.measurements[field.key]!)),
    ];
    if (logged.isEmpty) {
      return SportCard(
        title: field.label,
        child: Text('Nothing logged yet', style: TextStyle(color: muted)),
      );
    }
    final values = [for (final (_, v) in logged) v];
    final (startDate, startCm) = data.measurementAtStart(field.key)!;
    final delta = values.first - u.lengthOut(startCm);
    final flat = delta.abs() < 0.05;
    final color = flat ? muted : (delta < 0 ? goodGreen : badRed);

    return SportCard(
      title: field.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(values.first.toStringAsFixed(1), style: display(64, color: brandOrange, spacing: -1)),
              const SizedBox(width: 4),
              Text(u.length.toUpperCase(), style: display(22, color: muted)),
              const Spacer(),
              Text(DateFormat('EEE d MMM').format(logged.first.$1).toUpperCase(), style: label(context)),
            ],
          ),
          if (logged.length > 1)
            _SinceRow(
              children: [
                Icon(
                  flat ? Icons.remove : (delta < 0 ? Icons.arrow_downward : Icons.arrow_upward),
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text('${delta.abs().toStringAsFixed(1)} ${u.length}', style: display(19, color: color)),
                Text('  since ${DateFormat('d MMM yyyy').format(startDate)}', style: label(context)),
                const SizedBox(width: 4),
                Icon(Icons.edit_calendar, size: 16, color: muted),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(value: values.reduce(math.min).toStringAsFixed(1), caption: 'lowest'),
              _Stat(value: values.reduce(math.max).toStringAsFixed(1), caption: 'highest'),
              _Stat(value: u.lengthOut(startCm).toStringAsFixed(1), caption: 'at start'),
              _Stat(value: '${values.length}', caption: 'logged'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Weight summary plus latest value and change since the start date for each measurement.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final weights = [for (final e in data.mainWeights) e.weightKg!];
    final weekAgo = dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    final lastWeek = [
      for (final e in data.mainWeights)
        if (!e.date.isBefore(weekAgo)) e.weightKg!,
    ];

    Widget change(double delta, String unit) {
      final flat = delta.abs() < 0.05;
      final color = flat ? muted : (delta < 0 ? goodGreen : badRed);
      return Text(
        '${flat ? '±' : (delta < 0 ? '−' : '+')}${delta.abs().toStringAsFixed(1)} $unit',
        style: display(20, color: color),
      );
    }

    final rows = <Widget>[];
    for (final f in data.visibleFields) {
      final latest = data.latestMeasurement(f.key);
      final start = data.measurementAtStart(f.key);
      if (latest == null || start == null) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(f.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Text('${u.fmtLength(latest)} ${u.length}', style: display(22, weight: FontWeight.w800)),
              const SizedBox(width: 14),
              SizedBox(
                width: 86,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: change(u.lengthOut(latest) - u.lengthOut(start.$2), u.length),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SportCard(
      title: 'Numbers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (weights.isEmpty)
            Text('No weigh-ins yet', style: TextStyle(color: muted))
          else
            Row(
              children: [
                _Stat(
                  value: lastWeek.isEmpty ? '—' : u.fmtWeight(lastWeek.reduce((a, b) => a + b) / lastWeek.length),
                  caption: '7-day avg',
                ),
                _Stat(value: u.fmtWeight(weights.reduce(math.min)), caption: 'lowest'),
                _Stat(value: u.fmtWeight(weights.reduce(math.max)), caption: 'highest'),
                _Stat(value: '${weights.length}', caption: 'weigh-ins'),
              ],
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('MEASUREMENTS', style: label(context))),
                _SinceRow(
                  children: [
                    Text(
                      data.startDay == null
                          ? 'SINCE FIRST'
                          : 'SINCE ${DateFormat('d MMM').format(data.startDay!).toUpperCase()}',
                      style: label(context),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_calendar, size: 16, color: muted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...rows,
          ],
        ],
      ),
    );
  }
}

class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key, required this.data, required this.onLog});

  final AppData data;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final latest = data.latestMain;
    final first = data.startMain;
    final white70 = Colors.white.withValues(alpha: 0.8);

    return Container(
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: brandOrange.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: latest == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LATEST WEIGH-IN', style: label(context, color: white70)),
                const SizedBox(height: 14),
                Text('NO WEIGH-IN YET', style: display(44, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Log a weight to start your scoreboard.',
                  style: TextStyle(color: white70, fontSize: 15),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onLog,
                  icon: const Icon(Icons.add),
                  label: const Text('LOG NOW'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    textStyle: display(18, weight: FontWeight.w800),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('LATEST WEIGH-IN', style: label(context, color: white70)),
                    ),
                    Text(
                      '${DateFormat('EEE d MMM').format(latest.date)}  ${timeLabel(context, latest.minutes)}'
                          .toUpperCase(),
                      style: label(context, color: white70),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(u.fmtWeight(latest.weightKg!), style: display(108, color: Colors.white, spacing: -2)),
                    const SizedBox(width: 6),
                    Text(u.weight.toUpperCase(), style: display(30, color: white70)),
                  ],
                ),
                if (first != null && data.mainWeights.length > 1) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => showStartSheet(context),
                    child: _ChangePill(
                      deltaKg: latest.weightKg! - first.weightKg!,
                      since: first.date,
                      unitsText: (kg) => '${u.fmtWeight(kg.abs())} ${u.weight}',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TapeMeasure(
                  values: [for (final e in data.mainWeights) u.weightOut(e.weightKg!)],
                  latest: u.weightOut(latest.weightKg!),
                ),
              ],
            ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.deltaKg, required this.since, required this.unitsText});

  final double deltaKg;
  final DateTime since;
  final String Function(double) unitsText;

  @override
  Widget build(BuildContext context) {
    final down = deltaKg < 0;
    final flat = deltaKg.abs() < 0.05;
    final color = flat ? Colors.black54 : (down ? goodGreen : badRed);
    final icon = flat ? Icons.remove : (down ? Icons.arrow_downward : Icons.arrow_upward);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(unitsText(deltaKg), style: display(19, color: color)),
          Text(
            '  since ${DateFormat('d MMM yyyy').format(since)}',
            style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_calendar, size: 15, color: Colors.black54),
        ],
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final goal = data.goal;
    final progress = data.progress(DateTime.now());

    if (goal == null) {
      return SportCard(
        title: 'Goal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              data.latestMain == null
                  ? 'Log a weight first, then set a target.'
                  : 'Set a target weight and date to track your progress.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: data.latestMain == null ? null : () => showGoalSheet(context),
              icon: const Icon(Icons.flag),
              label: const Text('SET GOAL'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: brandOrange, width: 2),
                textStyle: display(20, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    String sign(double kg) => kg < 0 ? '−' : '+';
    return SportCard(
      title: 'Goal',
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Edit goal',
        icon: const Icon(Icons.edit),
        onPressed: () => showGoalSheet(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(u.fmtWeight(goal.targetWeightKg), style: display(52)),
              const SizedBox(width: 4),
              Text(u.weight.toUpperCase(), style: display(22, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text('BY ${DateFormat('d MMM yyyy').format(goal.targetDate).toUpperCase()}', style: label(context)),
            ],
          ),
          const SizedBox(height: 12),
          if (progress != null && progress.reached)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(gradient: brandGradient, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text('GOAL REACHED', style: display(28, color: Colors.white)),
                ],
              ),
            )
          else if (progress != null) ...[
            StripedProgressBar(value: progress.fraction),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${u.fmtWeight(goal.startWeightKg)} ${u.weight}', style: label(context)),
                const Spacer(),
                Text('${u.fmtWeight(goal.targetWeightKg)} ${u.weight}', style: label(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stat(value: '${(progress.fraction * 100).round()}%', caption: 'complete'),
                _Stat(value: u.fmtWeight(progress.leftKg), caption: '${u.weight} left'),
                _Stat(
                  value: '${progress.daysLeft.abs()}',
                  caption: progress.daysLeft < 0
                      ? (progress.daysLeft == -1 ? 'day overdue' : 'days overdue')
                      : (progress.daysLeft == 1 ? 'day left' : 'days left'),
                ),
                // Still needed while there's time; afterwards, the pace so far.
                if (progress.perWeekKg case final need?)
                  _Stat(value: '${sign(need)}${u.fmtWeight(need.abs())}', caption: '${u.weight} / week')
                else
                  _Stat(
                    value: data.pacePerWeekKg == null
                        ? '—'
                        : '${sign(data.pacePerWeekKg!)}${u.fmtWeight(data.pacePerWeekKg!.abs())}',
                    caption: '${u.weight} / week\nso far',
                  ),
              ],
            ),
            if (progress.overdue) ...[
              const SizedBox(height: 16),
              _OverdueNote(percent: (progress.fraction * 100).round()),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shown once the target date has passed without reaching the target: how far
/// along you are and a quick way to pick a new date.
class _OverdueNote extends StatelessWidget {
  const _OverdueNote({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandOrange.withValues(alpha: 0.5)),
        color: brandOrange.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_repeat, color: brandOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Target date passed. You\'re $percent% of the way there. Set a new date to keep going.',
              style: TextStyle(color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => showGoalSheet(context),
            child: Text('NEW DATE', style: display(16, color: brandOrange)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(value, style: display(30, color: brandOrange)),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class TrendCard extends StatelessWidget {
  const TrendCard({
    super.key,
    required this.data,
    required this.metric,
    required this.onMetric,
    this.chartHeight = 220,
  });

  final AppData data;

  /// 'weight' or a field key.
  final String metric;
  final ValueChanged<String> onMetric;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final u = data.units;
    final fields = data.visibleFields;
    final isWeight = metric == 'weight';

    // One point per date, oldest first. Weight: the day's last weigh-in.
    // Measurements: the earliest entry that has a value that day.
    final byDate = <DateTime, double>{};
    for (final e in data.entries.reversed) {
      if (isWeight) {
        if (data.isMain(e)) byDate[e.date] = u.weightOut(e.weightKg!);
      } else {
        final v = e.measurements[metric];
        if (v != null) byDate.putIfAbsent(e.date, () => u.lengthOut(v));
      }
    }
    final goalY = isWeight && data.goal != null ? u.weightOut(data.goal!.targetWeightKg) : null;

    return SportCard(
      title: 'Trend',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (key, name) in [('weight', 'Weight'), for (final f in fields) (f.key, f.label)])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ScrollIntoView(
                      active: metric == key,
                      child: ChoiceChip(
                        label: Text(name.toUpperCase()),
                        selected: metric == key,
                        showCheckmark: false,
                        labelStyle: display(
                          17,
                          weight: FontWeight.w700,
                          color: metric == key ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        ),
                        onSelected: (_) => onMetric(key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            child: byDate.isEmpty
                ? Center(
                    child: Text(
                      'No ${isWeight ? 'weigh-ins' : data.labelFor(metric).toLowerCase()} logged yet',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )
                : _Chart(
                    points: byDate,
                    goalY: goalY,
                    unit: isWeight ? u.weight : u.length,
                    decimals: isWeight ? 2 : 1,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.goalY, required this.unit, required this.decimals});

  final int decimals;

  final Map<DateTime, double> points;
  final double? goalY;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dates = points.keys.toList()..sort();
    final origin = dates.first;
    double xOf(DateTime d) => d.difference(origin).inHours / 24.0;
    final spots = [for (final d in dates) FlSpot(xOf(d), points[d]!)];

    final ys = [...points.values, ?goalY];
    var minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final pad = math.max(0.5, (maxY - minY) * 0.12);
    minY = (minY - pad).floorToDouble();
    maxY = (maxY + pad).ceilToDouble();
    var maxX = spots.last.x;
    final minX = maxX == 0 ? -1.0 : 0.0;
    if (maxX == 0) maxX = 1;
    final xInterval = math.max(1.0, (maxX - minX) / 3.5).ceilToDouble();
    final grid = scheme.onSurface.withValues(alpha: 0.08);
    final axisStyle = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox.shrink()
                  : Text(meta.formattedValue, style: axisStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: xInterval,
              // fl_chart always labels the max; skip interval labels that would collide with it.
              getTitlesWidget: (v, meta) => v < 0 || v > maxX || (v != maxX && maxX - v < xInterval * 0.6)
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('d MMM').format(origin.add(Duration(days: v.round()))), style: axisStyle),
                    ),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goalY != null)
              HorizontalLine(
                y: goalY!,
                color: brandOrange.withValues(alpha: 0.8),
                strokeWidth: 2,
                dashArray: [8, 6],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'GOAL',
                  style: display(14, color: brandOrange),
                ),
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.toStringAsFixed(decimals)} $unit\n${DateFormat('d MMM').format(origin.add(Duration(days: s.x.round())))}',
                  TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: brandOrange,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 40,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3.5,
                color: brandOrange,
                strokeWidth: 2,
                strokeColor: scheme.surfaceContainerLowest,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [brandOrange.withValues(alpha: 0.28), brandOrange.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrolls its child into view when it first appears active, e.g. the chip
/// of the metric the screen was opened on.
class _ScrollIntoView extends StatefulWidget {
  const _ScrollIntoView({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_ScrollIntoView> createState() => _ScrollIntoViewState();
}

class _ScrollIntoViewState extends State<_ScrollIntoView> {
  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: 0.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A "since [date]" row; tapping it opens the start date calendar.
class _SinceRow extends StatelessWidget {
  const _SinceRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showStartSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
