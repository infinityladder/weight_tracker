import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Where a body part is measured: a horizontal band across the figure in its
/// 200 x 440 design box, and which column its card sits in.
class BodyPart {
  const BodyPart(this.x1, this.x2, this.y, this.right, this.typicalCm);

  final double x1, x2, y;
  final bool right;

  /// Starting point for the size picker when nothing has been logged yet.
  final double typicalCm;

  BodyPart mirrored() => BodyPart(200 - x2, 200 - x1, y, !right, typicalCm);
}

/// Keyword -> where it sits on the male and female figures, most specific
/// first ("forearm" before "arm", "above knee" before "knee").
const _parts = <(String, BodyPart, BodyPart)>[
  ('neck', BodyPart(88, 112, 62, false, 38), BodyPart(91, 109, 62, false, 33)),
  ('shoulder', BodyPart(47, 153, 90, true, 110), BodyPart(53, 147, 92, true, 100)),
  ('chest', BodyPart(51, 149, 122, false, 95), BodyPart(55, 145, 124, false, 90)),
  ('bust', BodyPart(51, 149, 122, false, 95), BodyPart(55, 145, 124, false, 90)),
  ('forearm', BodyPart(25, 47, 225, false, 27), BodyPart(33, 49, 225, false, 23)),
  ('wrist', BodyPart(20, 40, 262, false, 16), BodyPart(30, 44, 262, false, 15)),
  ('bicep', BodyPart(32, 60, 140, false, 30), BodyPart(41, 61, 140, false, 27)),
  ('arm', BodyPart(32, 60, 140, false, 30), BodyPart(41, 61, 140, false, 27)),
  ('belly', BodyPart(61, 139, 172, false, 85), BodyPart(66, 134, 172, false, 78)),
  ('abdom', BodyPart(61, 139, 172, false, 85), BodyPart(66, 134, 172, false, 78)),
  ('stomach', BodyPart(61, 139, 172, false, 85), BodyPart(66, 134, 172, false, 78)),
  ('waist', BodyPart(66, 134, 200, true, 80), BodyPart(72, 128, 200, true, 72)),
  ('hip', BodyPart(56, 144, 248, true, 98), BodyPart(53, 147, 246, true, 100)),
  ('glute', BodyPart(56, 144, 248, true, 98), BodyPart(53, 147, 246, true, 100)),
  ('above knee', BodyPart(61, 94, 334, false, 42), BodyPart(61, 93, 334, false, 42)),
  ('thigh', BodyPart(59, 98, 290, false, 55), BodyPart(56, 97, 290, false, 57)),
  ('knee', BodyPart(63, 90, 352, false, 38), BodyPart(64, 90, 352, false, 37)),
  ('calf', BodyPart(109, 137, 385, true, 37), BodyPart(112, 134, 385, true, 35)),
  ('ankle', BodyPart(113, 135, 418, true, 22), BodyPart(114, 134, 418, true, 21)),
];

/// The part a field measures on [body], matched by name. "L-"/"left" and
/// "R-"/"right" pick the side; null when the name isn't a known body part.
BodyPart? partFor(MeasureField f, [BodyType body = BodyType.male]) {
  final name = f.label.toLowerCase();
  final left = name.startsWith('l-') || name.startsWith('l ') || name.contains('left');
  final right = name.startsWith('r-') || name.startsWith('r ') || name.contains('right');
  final words = name.replaceAll(RegExp(r'[-_]'), ' ');
  for (final (keyword, male, female) in _parts) {
    if (!words.contains(keyword)) continue;
    final part = body == BodyType.female ? female : male;
    if ((left && part.right) || (right && !part.right)) return part.mirrored();
    return part;
  }
  return null;
}

/// Body figure between two columns of measurement cards. The selected field's
/// part is highlighted on the body and joined to its card by a dashed line.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.fields,
    required this.valueText,
    required this.onTap,
    this.selectedKey,
    this.body = BodyType.male,
  });

  final List<MeasureField> fields;
  final BodyType body;

  /// Display text for a field's latest value, or null when never logged.
  final String? Function(MeasureField f) valueText;
  final void Function(MeasureField f) onTap;
  final String? selectedKey;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Split into columns, each ordered top to bottom on the body; fields that
    // aren't a known part go at the end of the shorter column.
    final left = <(MeasureField, BodyPart?)>[], right = <(MeasureField, BodyPart?)>[];
    final unplaced = <MeasureField>[];
    for (final f in fields) {
      final part = partFor(f, body);
      if (part == null) {
        unplaced.add(f);
      } else {
        (part.right ? right : left).add((f, part));
      }
    }
    left.sort((a, b) => a.$2!.y.compareTo(b.$2!.y));
    right.sort((a, b) => a.$2!.y.compareTo(b.$2!.y));
    for (final f in unplaced) {
      (left.length <= right.length ? left : right).add((f, null));
    }

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final rows = math.max(1, math.max(left.length, right.length));
      final cardW = math.min(132.0, (w - 24) * 0.34);
      final cardH = ((c.maxHeight - _gap * (rows - 1)) / rows).clamp(56.0, 76.0);
      final h = math.max(c.maxHeight, rows * cardH + (rows - 1) * _gap);

      // Figure fills the middle; the arms may tuck slightly under the cards.
      final s = math.min(h / 450, math.max(0.4, (w - 2 * cardW - 4) / 150));
      final ox = (w - 200 * s) / 2, oy = (h - 440 * s) / 2;
      Offset toCanvas(double x, double y) => Offset(ox + x * s, oy + y * s);

      // Each card sits level with its part, pushed down just enough to clear the
      // card above, then pulled back up if the column runs off the bottom.
      List<double> topsFor(List<(MeasureField, BodyPart?)> column) {
        final tops = <double>[];
        var next = 0.0;
        for (final (_, part) in column) {
          final want = part == null ? next : part.y * s + oy - cardH / 2;
          tops.add(math.max(want, next));
          next = tops.last + cardH + _gap;
        }
        var limit = h - cardH;
        for (var i = tops.length - 1; i >= 0; i--) {
          tops[i] = math.min(tops[i], limit);
          limit = tops[i] - cardH - _gap;
        }
        return tops;
      }

      final columnTops = {false: topsFor(left), true: topsFor(right)};

      (Offset, Offset, Offset, Offset)? highlight;
      var shift = 0.0;
      for (final (isRight, column) in [(false, left), (true, right)]) {
        for (final (i, (f, part)) in column.indexed) {
          if (f.key != selectedKey || part == null) continue;
          highlight = (
            toCanvas(part.x1, part.y),
            toCanvas(part.x2, part.y),
            isRight ? toCanvas(part.x2, part.y) : toCanvas(part.x1, part.y),
            Offset(isRight ? w - cardW : cardW, columnTops[isRight]![i] + cardH / 2),
          );
          // The size picker sheet covers roughly the lower 60%: slide the
          // map up so both the card and the highlighted part stay visible.
          final lowest = math.max(columnTops[isRight]![i] + cardH, part.y * s + oy + 12);
          shift = math.max(0.0, lowest - c.maxHeight * 0.38);
        }
      }

      final stack = SizedBox(
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BodyPainter(
                  origin: Offset(ox, oy),
                  scale: s,
                  fill: scheme.onSurface,
                  ringColor: scheme.surface,
                  highlight: highlight,
                  body: body,
                ),
              ),
            ),
            for (final (isRight, column) in [(false, left), (true, right)])
              for (final (i, (f, _)) in column.indexed)
                Positioned(
                  top: columnTops[isRight]![i],
                  left: isRight ? null : 0,
                  right: isRight ? 0 : null,
                  width: cardW,
                  height: cardH,
                  child: _PartCard(
                    field: f,
                    value: valueText(f),
                    selected: f.key == selectedKey,
                    onTap: () => onTap(f),
                  ),
                ),
          ],
        ),
      );
      final shifted = ClipRect(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: shift),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, dy, child) => Transform.translate(offset: Offset(0, -dy), child: child),
          child: stack,
        ),
      );
      return h > c.maxHeight ? SingleChildScrollView(child: shifted) : shifted;
    });
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.field, required this.value, required this.selected, required this.onTap});

  final MeasureField field;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : scheme.onSurface;
    final muted = selected ? Colors.white.withValues(alpha: 0.8) : scheme.onSurfaceVariant;
    final parts = value?.split(' ');
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLowest,
      child: Ink(
        decoration: BoxDecoration(
          gradient: selected ? brandGradient : null,
          borderRadius: BorderRadius.circular(16),
          border: selected ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
                const SizedBox(height: 2),
                FittedBox(
                  child: parts == null
                      ? Text('+ ADD', style: display(22, color: selected ? Colors.white : brandOrange))
                      : Text.rich(TextSpan(children: [
                          TextSpan(text: parts.first, style: display(26, color: fg)),
                          TextSpan(text: ' ${parts.skip(1).join(' ')}', style: display(15, color: muted)),
                        ])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.origin,
    required this.scale,
    required this.fill,
    required this.ringColor,
    required this.highlight,
    required this.body,
  });

  final BodyType body;
  final Offset origin;
  final double scale;
  final Color fill, ringColor;

  /// Selected part: band start, band end, leader anchor, card edge (canvas coordinates).
  final (Offset, Offset, Offset, Offset)? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    body == BodyType.female ? _paintFemale(canvas) : _paintFigure(canvas);
    canvas.restore();

    final hl = highlight;
    if (hl == null) return;
    final (a, b, anchor, card) = hl;
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = brandOrange
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);

    // Dashed elbow: out of the card, along to just beside the anchor, then in.
    final dir = anchor.dx < card.dx ? 1.0 : -1.0;
    final elbowX = anchor.dx + dir * 14;
    final dash = Paint()
      ..color = brandOrange
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final (p, q) in [
      (card, Offset(elbowX, card.dy)),
      (Offset(elbowX, card.dy), Offset(elbowX, anchor.dy)),
      (Offset(elbowX, anchor.dy), anchor),
    ]) {
      _dashed(canvas, p, q, dash);
    }
    canvas.drawCircle(anchor, 8, Paint()..color = ringColor);
    canvas.drawCircle(anchor, 6, Paint()..color = brandOrange);
    canvas.drawCircle(anchor, 2.5, Paint()..color = ringColor);
  }

  static void _dashed(Canvas canvas, Offset p, Offset q, Paint paint) {
    final len = (q - p).distance;
    if (len == 0) return;
    final step = (q - p) / len;
    for (double d = 0; d < len; d += 9) {
      canvas.drawLine(p + step * d, p + step * math.min(d + 4.5, len), paint);
    }
  }

  Paint get _fillPaint => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [fill.withValues(alpha: 0.16), fill.withValues(alpha: 0.08)],
    ).createShader(const Rect.fromLTWH(0, 0, 200, 440));

  static Paint _limb(Paint fill, double width) => Paint()
    ..shader = fill.shader
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;

  /// Male silhouette in a 200 x 440 box, built from overlapping filled shapes.
  void _paintFigure(Canvas canvas) {
    final paint = _fillPaint;
    Paint limb(double width) => _limb(paint, width);

    // Head and neck.
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 32), width: 44, height: 54), paint);
    canvas.drawRRect(RRect.fromLTRBR(88, 50, 112, 76, const Radius.circular(8)), paint);

    // Torso: left half traced top to bottom, right half mirrored back up.
    final torso = Path()
      ..moveTo(88, 70)
      ..quadraticBezierTo(62, 72, 52, 90)
      ..cubicTo(46, 104, 50, 132, 56, 150)
      ..cubicTo(61, 170, 67, 185, 67, 200)
      ..cubicTo(65, 216, 57, 232, 58, 256)
      ..lineTo(142, 256)
      ..cubicTo(143, 232, 135, 216, 133, 200)
      ..cubicTo(133, 185, 139, 170, 144, 150)
      ..cubicTo(150, 132, 154, 104, 148, 90)
      ..quadraticBezierTo(138, 72, 112, 70)
      ..close();
    canvas.drawPath(torso, paint);

    for (final mirror in [false, true]) {
      Offset m(double x, double y) => Offset(mirror ? 200 - x : x, y);
      // Arms.
      canvas.drawLine(m(53, 96), m(40, 182), limb(25));
      canvas.drawLine(m(40, 184), m(31, 262), limb(19));
      canvas.drawOval(Rect.fromCenter(center: m(29, 280), width: 18, height: 26), paint);
      // Legs: tapered thigh, then calf.
      final leg = Path()
        ..moveTo(m(58, 250).dx, 250)
        ..lineTo(m(101, 250).dx, 250)
        ..lineTo(m(93, 350).dx, 350)
        ..lineTo(m(61, 350).dx, 350)
        ..close();
      canvas.drawPath(leg, paint);
      canvas.drawLine(m(77, 352), m(76, 418), limb(27));
      canvas.drawOval(Rect.fromCenter(center: m(73, 430), width: 30, height: 14), paint);
    }
  }

  /// Female silhouette in the same box: hair, narrower shoulders and waist,
  /// fuller bust and hips, slimmer limbs.
  void _paintFemale(Canvas canvas) {
    final paint = _fillPaint;
    Paint limb(double width) => _limb(paint, width);

    // Hair behind the head, then head and neck.
    canvas.drawPath(
      Path()
        ..moveTo(74, 34)
        ..cubicTo(72, 2, 128, 2, 126, 34)
        ..cubicTo(127, 52, 130, 70, 124, 80)
        ..lineTo(76, 80)
        ..cubicTo(70, 70, 73, 52, 74, 34)
        ..close(),
      paint,
    );
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 34), width: 40, height: 50), paint);
    canvas.drawRRect(RRect.fromLTRBR(91, 52, 109, 76, const Radius.circular(7)), paint);

    // Torso: hourglass, traced like the male one.
    final torso = Path()
      ..moveTo(91, 70)
      ..quadraticBezierTo(62, 74, 56, 92)
      ..cubicTo(52, 108, 54, 126, 58, 142)
      ..cubicTo(63, 162, 72, 182, 72, 200)
      ..cubicTo(71, 218, 53, 232, 54, 256)
      ..lineTo(146, 256)
      ..cubicTo(147, 232, 129, 218, 128, 200)
      ..cubicTo(128, 182, 137, 162, 142, 142)
      ..cubicTo(146, 126, 148, 108, 144, 92)
      ..quadraticBezierTo(138, 74, 109, 70)
      ..close();
    canvas.drawPath(torso, paint);
    for (final x in [82.0, 118.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 128), width: 32, height: 24), paint);
    }

    for (final mirror in [false, true]) {
      Offset m(double x, double y) => Offset(mirror ? 200 - x : x, y);
      // Arms.
      canvas.drawLine(m(57, 98), m(46, 182), limb(20));
      canvas.drawLine(m(46, 184), m(38, 262), limb(15));
      canvas.drawOval(Rect.fromCenter(center: m(36, 277), width: 15, height: 22), paint);
      // Legs: wider at the hip, tapering to the knee, then calf.
      final leg = Path()
        ..moveTo(m(54, 250).dx, 250)
        ..lineTo(m(101, 250).dx, 250)
        ..lineTo(m(92, 350).dx, 350)
        ..lineTo(m(62, 350).dx, 350)
        ..close();
      canvas.drawPath(leg, paint);
      canvas.drawLine(m(77, 352), m(77, 418), limb(23));
      canvas.drawOval(Rect.fromCenter(center: m(75, 428), width: 24, height: 12), paint);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.origin != origin ||
      old.scale != scale ||
      old.fill != fill ||
      old.highlight != highlight ||
      old.body != body;
}
