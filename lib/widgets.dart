import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Minutes since midnight in the device's 12/24h format.
String timeLabel(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

/// Widest a column of cards, rows or fields gets; tablets centre it.
const readableWidth = 720.0;

/// List padding that keeps the content [readableWidth] wide at most and
/// centred, while the whole screen still scrolls.
EdgeInsets readablePadding(BuildContext context, {double top = 4, double bottom = 24}) {
  final side = math.max(16.0, (MediaQuery.sizeOf(context).width - readableWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Rounded card with a section label and optional trailing action.
class SportCard extends StatelessWidget {
  const SportCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(title!.toUpperCase(), style: label(context))),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Parallelogram progress bar with diagonal stripes.
class StripedProgressBar extends StatelessWidget {
  const StripedProgressBar({super.key, required this.value, this.height = 24});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _StripedBarPainter(value.clamp(0, 1), track)),
    );
  }
}

class _StripedBarPainter extends CustomPainter {
  _StripedBarPainter(this.value, this.track);

  final double value;
  final Color track;

  Path _slanted(double width, double h, double skew) => Path()
    ..moveTo(skew, 0)
    ..lineTo(width, 0)
    ..lineTo(width - skew, h)
    ..lineTo(0, h)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final skew = size.height * 0.5;
    canvas.drawPath(_slanted(size.width, size.height, skew), Paint()..color = track);
    if (value <= 0) return;

    final fillWidth = skew + (size.width - skew) * value;
    final fill = _slanted(fillWidth, size.height, skew);
    canvas.save();
    canvas.clipPath(fill);
    canvas.drawRect(Offset.zero & Size(fillWidth, size.height),
        Paint()..shader = brandGradient.createShader(Offset.zero & size));
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = size.height * 0.28;
    for (double x = -size.height; x < fillWidth + size.height; x += size.height * 0.75) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripedBarPainter old) => old.value != value || old.track != track;
}

/// Tape-measure strip: ticks across the range of past weights, small marks for
/// each past weight and a pointer at the latest one. Values are in display units.
class TapeMeasure extends StatelessWidget {
  const TapeMeasure({super.key, required this.values, required this.latest});

  final List<double> values;
  final double latest;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: CustomPaint(painter: _TapePainter(values, latest)),
    );
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.values, this.latest);

  final List<double> values;
  final double latest;

  static const _steps = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0];

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max(1.0, (hi - lo) * 0.15);
    lo -= pad;
    hi += pad;
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    double xOf(double v) => (v - lo) / (hi - lo) * size.width;

    const tapeTop = 14.0, tapeH = 36.0;
    final tape = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, tapeTop, size.width, tapeH), const Radius.circular(8));
    canvas.drawRRect(tape, Paint()..color = Colors.white.withValues(alpha: 0.16));

    final minor = _steps.firstWhere((s) => (hi - lo) / s <= 60, orElse: () => 50);
    final majorEvery = minor == 0.2 || minor == 2 || minor == 20 ? 5 : 10;
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.clipRRect(tape);
    for (var i = (lo / minor).ceil(); i * minor <= hi; i++) {
      final x = xOf(i * minor);
      final major = i % majorEvery == 0;
      final half = !major && majorEvery == 10 && i % 5 == 0;
      final len = major ? 16.0 : (half ? 11.0 : 6.0);
      canvas.drawLine(Offset(x, tapeTop), Offset(x, tapeTop + len), tick..strokeWidth = major ? 2 : 1.2);
      if (major) {
        final v = i * minor;
        final tp = TextPainter(
          text: TextSpan(
              text: v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
              style: display(13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tapeTop + tapeH - tp.height - 3));
      }
    }
    canvas.restore();

    // Past weights as small marks above the tape.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (final v in values) {
      canvas.drawCircle(Offset(xOf(v), tapeTop - 6), 2.6, dot);
    }

    // Latest: pointer and line across the tape.
    final x = xOf(latest);
    final marker = Paint()..color = Colors.white;
    canvas.drawPath(
        Path()
          ..moveTo(x - 7, 0)
          ..lineTo(x + 7, 0)
          ..lineTo(x, 11)
          ..close(),
        marker);
    canvas.drawRect(Rect.fromLTWH(x - 1.5, tapeTop, 3, tapeH), marker);
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.latest != latest || old.values != values;
}
