import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../body_map.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../units.dart';

/// Size picker for one measurement field, saved to the chosen date.
/// Returns true when the user asked to see the field's trend instead.
Future<bool> showMeasureSheet(BuildContext context, MeasureField field) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MeasureSheet(field: field),
    ) ??
    false;

class _MeasureSheet extends ConsumerStatefulWidget {
  const _MeasureSheet({required this.field});

  final MeasureField field;

  @override
  ConsumerState<_MeasureSheet> createState() => _MeasureSheetState();
}

class _MeasureSheetState extends ConsumerState<_MeasureSheet> {
  late double _value; // display units
  DateTime _date = dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    final data = ref.read(appProvider);
    final cm = data.latestMeasurement(widget.field.key) ?? partFor(widget.field, data.body)?.typicalCm ?? 50;
    _value = (data.units.lengthOut(cm) * 10).roundToDouble() / 10;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _type() async {
    final typed = await showDialog<double>(
      context: context,
      builder: (_) => _TypeValueDialog(
        label: widget.field.label,
        unit: ref.read(appProvider).units.length,
        initial: _value,
      ),
    );
    if (typed != null) setState(() => _value = typed);
  }

  Future<void> _confirm() async {
    final data = ref.read(appProvider);
    final cm = data.units.lengthIn(_value);
    // Join the latest entry on that date so one session stays one row.
    final latest = data.entries.where((e) => e.date == _date).firstOrNull;
    final entry = latest == null
        ? Entry(date: _date, minutes: minutesOf(DateTime.now()), measurements: {widget.field.key: cm})
        : Entry(
            id: latest.id,
            date: latest.date,
            minutes: latest.minutes,
            weightKg: latest.weightKg,
            measurements: {...latest.measurements, widget.field.key: cm},
          );
    await ref.read(appProvider.notifier).saveEntry(entry);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = ref.watch(appProvider.select((d) => d.units.length));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A slimmer drag handle than the built-in one.
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(child: Text(widget.field.label.toUpperCase(), style: display(21))),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: Text('TREND', style: display(15, color: brandOrange)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      onTap: _type,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: _value.toStringAsFixed(1), style: display(34)),
                          TextSpan(text: ' $unit', style: display(16, color: scheme.onSurfaceVariant)),
                        ])),
                      ),
                    ),
                  ),
                  RulerPicker(value: _value, onChanged: (v) => setState(() => _value = v)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('d MMM yyyy').format(_date), style: display(17, weight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: scheme.outlineVariant, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      textStyle: display(20, weight: FontWeight.w800, spacing: 1),
                    ),
                    child: const Text('CONFIRM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal tape ruler in 0.1 steps: drag or fling to change the value,
/// which snaps to the nearest 0.1 when it settles.
class RulerPicker extends StatefulWidget {
  const RulerPicker({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 300});

  final double value;
  final ValueChanged<double> onChanged;
  final double min, max;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> with SingleTickerProviderStateMixin {
  static const _pxPerUnit = 110.0;

  late final AnimationController _ctrl = AnimationController.unbounded(vsync: this, value: widget.value)
    ..addListener(_tick);
  double _lastEmitted = double.nan;

  @override
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    // Value set from outside (typed in): jump there.
    if (!_ctrl.isAnimating && (widget.value - _snap(_ctrl.value)).abs() > 1e-6) {
      _ctrl.value = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _snap(double v) => ((v * 10).roundToDouble() / 10).clamp(widget.min, widget.max);

  void _tick() {
    if (_ctrl.value < widget.min || _ctrl.value > widget.max) {
      _ctrl.stop();
      _ctrl.value = _ctrl.value.clamp(widget.min, widget.max);
    }
    final snapped = _snap(_ctrl.value);
    if (snapped != _lastEmitted) {
      _lastEmitted = snapped;
      HapticFeedback.selectionClick();
      widget.onChanged(snapped);
    }
  }

  void _settle() => _ctrl.animateTo(_snap(_ctrl.value),
      duration: const Duration(milliseconds: 160), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: (_) => _ctrl.stop(),
      onHorizontalDragCancel: _settle,
      onHorizontalDragUpdate: (d) => _ctrl.value -= d.delta.dx / _pxPerUnit,
      onHorizontalDragEnd: (d) {
        final velocity = -d.velocity.pixelsPerSecond.dx / _pxPerUnit;
        if (velocity.abs() < 0.5) return _settle();
        _ctrl.animateWith(FrictionSimulation(0.02, _ctrl.value, velocity)).whenComplete(_settle);
      },
      child: SizedBox(
        height: 72,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: _RulerPainter(
              value: _ctrl.value,
              pxPerUnit: _pxPerUnit,
              tick: scheme.onSurfaceVariant,
              text: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.value, required this.pxPerUnit, required this.tick, required this.text});

  final double value, pxPerUnit;
  final Color tick, text;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const baseY = 42.0;
    final half = cx / pxPerUnit + 0.2;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = ((value - half) * 10).floor(); i <= ((value + half) * 10).ceil(); i++) {
      if (i < 0) continue;
      final x = cx + (i / 10 - value) * pxPerUnit;
      // Fade ticks towards the edges.
      final fade = (1 - ((x - cx).abs() / cx)).clamp(0.15, 1.0);
      final major = i % 10 == 0, mid = i % 5 == 0;
      final len = major ? 30.0 : (mid ? 21.0 : 13.0);
      paint
        ..color = tick.withValues(alpha: 0.6 * fade)
        ..strokeWidth = major ? 2.5 : 1.6;
      canvas.drawLine(Offset(x, baseY - len), Offset(x, baseY), paint);
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
              text: '${i ~/ 10}', style: display(15, weight: FontWeight.w700, color: text.withValues(alpha: fade))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baseY + 11));
      }
    }
    // Centre indicator.
    canvas.drawLine(
        Offset(cx, baseY - 38),
        Offset(cx, baseY + 2),
        Paint()
          ..color = brandOrange
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(cx - 6, baseY + 9)
          ..lineTo(cx + 6, baseY + 9)
          ..lineTo(cx, baseY + 2)
          ..close(),
        Paint()..color = brandOrange);
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.value != value || old.tick != tick;
}

/// Box for typing a value instead of using the ruler. Owns its controller so
/// it's disposed only after the closing animation.
class _TypeValueDialog extends StatefulWidget {
  const _TypeValueDialog({required this.label, required this.unit, required this.initial});

  final String label, unit;
  final double initial;

  @override
  State<_TypeValueDialog> createState() => _TypeValueDialogState();
}

class _TypeValueDialogState extends State<_TypeValueDialog> {
  // Selected so typing replaces it.
  late final _ctrl = TextEditingController(text: widget.initial.toStringAsFixed(1))
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.toStringAsFixed(1).length);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: widget.unit),
        onSubmitted: (t) => Navigator.pop(context, parseNumber(t)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, parseNumber(_ctrl.text)), child: const Text('OK')),
      ],
    );
  }
}
