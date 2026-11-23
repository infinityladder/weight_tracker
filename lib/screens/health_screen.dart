import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';
import 'measure_sheet.dart';
import 'settings_sheet.dart';

/// The health analyses the user switched on in Settings, each with where its
/// numbers come from and the ranges it's judged against.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final shown = data.healthShown;

    Widget settingsButton(String text) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.settings, size: 18),
            label: Text(text, style: display(16, color: brandOrange)),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('HEALTH')),
      body: ListView(
        padding: readablePadding(context),
        children: [
          if (shown.isEmpty)
            SportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No analyses switched on.', style: TextStyle(color: muted)),
                  settingsButton('CHOOSE IN SETTINGS'),
                ],
              ),
            ),
          if (shown.any((a) => a.usesHeight) && data.heightCm == null)
            SportCard(
              title: 'Height needed',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your height to see these analyses.', style: TextStyle(color: muted)),
                  settingsButton('ADD HEIGHT'),
                ],
              ),
            ),
          if (shown.contains(HealthAnalysis.bmi)) _BmiCard(data: data),
          if (shown.contains(HealthAnalysis.waistRatio)) _WaistRatioCard(data: data),
          if (shown.contains(HealthAnalysis.waistHip)) _WaistHipCard(data: data),
          const SizedBox(height: 8),
          Text(
            'These are general screening guides for adults, not a diagnosis. '
            'They don\'t suit children, pregnancy or very muscular builds.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _heightText(Units u, double cm) {
  if (u.metric) return '${cm.toStringAsFixed(cm % 1 == 0 ? 0 : 1)} cm';
  final inches = (cm / Units.cmPerIn).round();
  return '${inches ~/ 12} ft ${inches % 12} in';
}

Color _categoryColor(String category) => switch (category) {
      'Healthy' => goodGreen,
      'Obese' || 'High risk' => badRed,
      _ => brandOrange,
    };

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final u = data.units;
    final bmi = data.latestBmi, latest = data.latestMain, h = data.heightCm;
    final asian = data.bmiRanges == BmiRanges.asian;
    final (over, obese) = asian ? (23.0, 27.5) : (25.0, 30.0);

    return SportCard(
      title: 'BMI',
      child: bmi == null
          ? Text(latest == null ? 'Log a weight to see your BMI.' : 'Add your height to see your BMI.',
              style: TextStyle(color: muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Headline(value: bmi.toStringAsFixed(1), category: bmiCategory(bmi, data.bmiRanges)),
                const SizedBox(height: 14),
                _RangeBar(
                  value: bmi,
                  min: 15,
                  max: 35,
                  bands: [
                    (18.5, brandOrange.withValues(alpha: 0.6)),
                    (over, goodGreen),
                    (obese, brandOrange),
                    (35, badRed),
                  ],
                  format: (v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                ),
                const SizedBox(height: 14),
                Text(
                  'From ${u.fmtWeight(latest!.weightKg!)} ${u.weight} on ${DateFormat('EEE d MMM').format(latest.date)} '
                  'and a height of ${_heightText(u, h!)}.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  asian
                      ? 'Asian ranges (WHO 2004, NICE): under 18.5 underweight, 18.5–22.9 healthy, '
                          '23–27.4 overweight, 27.5+ obese.'
                      : 'WHO ranges: under 18.5 underweight, 18.5–24.9 healthy, 25–29.9 overweight, 30+ obese.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

class _WaistRatioCard extends StatelessWidget {
  const _WaistRatioCard({required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final u = data.units;
    final ratio = data.latestWaistRatio, h = data.heightCm;
    final waist = data.fields.where((f) => f.key == 'waist').firstOrNull;
    final waistCm = data.latestMeasurement('waist');

    return SportCard(
      title: 'Waist-to-height ratio',
      child: ratio == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waistCm == null ? 'Log your waist to see this.' : 'Add your height to see this.',
                  style: TextStyle(color: muted),
                ),
                if (waistCm == null && waist != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showMeasureSheet(context, waist),
                      icon: const Icon(Icons.straighten, size: 18),
                      label: Text('LOG WAIST', style: display(16, color: brandOrange)),
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Headline(value: ratio.toStringAsFixed(2), category: waistRatioCategory(ratio)),
                const SizedBox(height: 14),
                _RangeBar(
                  value: ratio,
                  min: 0.35,
                  max: 0.7,
                  bands: [
                    (0.4, brandOrange.withValues(alpha: 0.6)),
                    (0.5, goodGreen),
                    (0.6, brandOrange),
                    (0.7, badRed),
                  ],
                  format: (v) => v.toStringAsFixed(1),
                ),
                const SizedBox(height: 14),
                Text(
                  'Waist ${u.fmtLength(waistCm!)} ${u.length} ÷ height ${_heightText(u, h!)}. '
                  'It shows fat around the middle, which BMI can miss.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'NICE ranges (all backgrounds): 0.4–0.49 healthy, 0.5–0.59 increased risk, 0.6+ high risk.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

class _WaistHipCard extends StatelessWidget {
  const _WaistHipCard({required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final u = data.units;
    final ratio = data.latestWaistHipRatio;
    final limit = waistHipLimit(data.body);
    final missing = [
      for (final key in ['waist', 'hips'])
        if (data.latestMeasurement(key) == null) ...data.fields.where((f) => f.key == key),
    ];

    return SportCard(
      title: 'Waist-to-hip ratio',
      child: ratio == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log your ${missing.map((f) => f.label.toLowerCase()).join(' and ')} to see this.',
                    style: TextStyle(color: muted)),
                Wrap(
                  children: [
                    for (final f in missing)
                      TextButton.icon(
                        onPressed: () => showMeasureSheet(context, f),
                        icon: const Icon(Icons.straighten, size: 18),
                        label: Text('LOG ${f.label.toUpperCase()}', style: display(16, color: brandOrange)),
                      ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Headline(value: ratio.toStringAsFixed(2), category: waistHipCategory(ratio, data.body)),
                const SizedBox(height: 14),
                _RangeBar(
                  value: ratio,
                  min: limit - 0.2,
                  max: limit + 0.2,
                  bands: [(limit, goodGreen), (limit + 0.2, brandOrange)],
                  format: (v) => v.toStringAsFixed(2),
                ),
                const SizedBox(height: 14),
                Text(
                  'Waist ${u.fmtLength(data.latestMeasurement('waist')!)} ${u.length} ÷ '
                  'hips ${u.fmtLength(data.latestMeasurement('hips')!)} ${u.length}.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'WHO (2008): risk is substantially increased from 0.90 for men and 0.85 for women. '
                  'Uses the ${data.body == BodyType.male ? 'men\'s' : 'women\'s'} limit, from the body chosen in Settings.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

/// Big value with its category beside it.
class _Headline extends StatelessWidget {
  const _Headline({required this.value, required this.category});

  final String value, category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: numberStyle(38, color: color)),
        const SizedBox(width: 14),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(category.toUpperCase(), style: display(15, weight: FontWeight.w700, color: color)),
          ),
        ),
      ],
    );
  }
}

/// Coloured bands from [min] to [max] (each band ends at its value) with a
/// marker at [value] and the boundaries labelled underneath.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.value,
    required this.min,
    required this.max,
    required this.bands,
    required this.format,
  });

  final double value, min, max;
  final List<(double, Color)> bands;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double x(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0) * w;
      final marker = x(value);
      return SizedBox(
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    for (final (i, (end, color)) in bands.indexed)
                      Container(
                        width: x(end) - x(i == 0 ? min : bands[i - 1].$1),
                        height: 12,
                        color: color,
                      ),
                  ],
                ),
              ),
            ),
            // Marker: a ringed dot on the bar.
            Positioned(
              left: marker - 9,
              top: 9,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surfaceContainerLowest, width: 3),
                ),
              ),
            ),
            for (final (end, _) in bands.take(bands.length - 1))
              Positioned(
                left: x(end) - 20,
                width: 40,
                top: 28,
                child: Text(format(end),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
      );
    });
  }
}
