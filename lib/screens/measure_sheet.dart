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
      showDragHandle: true,
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
    final ctrl = TextEditingController(text: _value.toStringAsFixed(1));
    final unit = ref.read(appProvider).units.length;
    final typed = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(widget.field.label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit),
          onSubmitted: (t) => Navigator.pop(d, parseNumber(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, parseNumber(ctrl.text)), child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.field.label.toUpperCase(), style: display(26))),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.show_chart),
                  label: Text('TREND', style: display(17, color: brandOrange)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
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
                          TextSpan(text: _value.toStringAsFixed(1), style: display(44)),
                          TextSpan(text: ' $unit', style: display(20, color: scheme.onSurfaceVariant)),
                        ])),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  RulerPicker(value: _value, onChanged: (v) => setState(() => _value = v)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: Text(DateFormat('d MMM yyyy').format(_date), style: display(20, weight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: scheme.outlineVariant, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _confirm, child: const Text('CONFIRM'))),
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
        height: 90,
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
    const baseY = 56.0;
    final half = cx / pxPerUnit + 0.2;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = ((value - half) * 10).floor(); i <= ((value + half) * 10).ceil(); i++) {
      if (i < 0) continue;
      final x = cx + (i / 10 - value) * pxPerUnit;
      // Fade ticks towards the edges.
      final fade = (1 - ((x - cx).abs() / cx)).clamp(0.15, 1.0);
      final major = i % 10 == 0, mid = i % 5 == 0;
      final len = major ? 40.0 : (mid ? 28.0 : 18.0);
      paint
        ..color = tick.withValues(alpha: 0.6 * fade)
        ..strokeWidth = major ? 2.5 : 1.6;
      canvas.drawLine(Offset(x, baseY - len), Offset(x, baseY), paint);
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
              text: '${i ~/ 10}', style: display(18, weight: FontWeight.w700, color: text.withValues(alpha: fade))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baseY + 15));
      }
    }
    // Centre indicator.
    canvas.drawLine(
        Offset(cx, baseY - 50),
        Offset(cx, baseY + 2),
        Paint()
          ..color = brandOrange
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(cx - 8, baseY + 12)
          ..lineTo(cx + 8, baseY + 12)
          ..lineTo(cx, baseY + 3)
          ..close(),
        Paint()..color = brandOrange);
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.value != value || old.tick != tick;
}
