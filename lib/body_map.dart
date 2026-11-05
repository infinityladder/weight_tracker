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

const _images = {BodyType.male: 'images/male.png', BodyType.female: 'images/female.png'};

/// Where the body picture sits in the 200 x 440 box: full width, centred
/// vertically. Both pictures are about 0.524 wide for each unit of height.
const _imageRect = Rect.fromLTWH(0, 29.25, 200, 381.5);

/// Keyword -> where it sits on the male and female figures, most specific
/// first ("forearm" before "arm", "above knee" before "knee"). Positions are
/// measured on each body's picture as placed by [_imageRect].
const _parts = <(String, BodyPart, BodyPart)>[
  ('neck', BodyPart(86, 110, 78, false, 38), BodyPart(89, 105, 96, false, 33)),
  ('shoulder', BodyPart(49, 149, 109, true, 110), BodyPart(55, 145, 115, true, 100)),
  ('chest', BodyPart(59, 140, 129, false, 95), BodyPart(70, 131, 135, false, 90)),
  ('bust', BodyPart(59, 140, 129, false, 95), BodyPart(70, 131, 135, false, 90)),
  ('forearm', BodyPart(26, 46, 181, false, 27), BodyPart(31, 49, 188, false, 23)),
  ('wrist', BodyPart(17, 33, 195, false, 16), BodyPart(20, 35, 201, false, 15)),
  ('bicep', BodyPart(40, 61, 150, false, 30), BodyPart(50, 68, 153, false, 27)),
  ('arm', BodyPart(40, 61, 150, false, 30), BodyPart(50, 68, 153, false, 27)),
  ('belly', BodyPart(70, 128, 162, false, 85), BodyPart(72, 130, 179, false, 78)),
  ('abdom', BodyPart(70, 128, 162, false, 85), BodyPart(72, 130, 179, false, 78)),
  ('stomach', BodyPart(70, 128, 162, false, 85), BodyPart(72, 130, 179, false, 78)),
  ('waist', BodyPart(69, 129, 176, true, 80), BodyPart(76, 124, 164, true, 72)),
  ('hip', BodyPart(60, 139, 215, true, 98), BodyPart(59, 144, 214, true, 100)),
  ('glute', BodyPart(60, 139, 215, true, 98), BodyPart(59, 144, 214, true, 100)),
  ('above knee', BodyPart(65, 90, 283, false, 42), BodyPart(66, 91, 280, false, 42)),
  ('thigh', BodyPart(61, 94, 259, false, 55), BodyPart(61, 95, 254, false, 57)),
  ('knee', BodyPart(65, 86, 302, false, 38), BodyPart(66, 89, 294, false, 37)),
  ('calf', BodyPart(114, 140, 329, true, 37), BodyPart(119, 146, 322, true, 35)),
  ('ankle', BodyPart(122, 135, 377, true, 22), BodyPart(130, 142, 366, true, 21)),
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

      // Figure fills the middle; the outstretched hands may tuck slightly
      // under the cards.
      final s = math.min(h / 450, math.max(0.4, (w - 2 * cardW - 4) / 185));
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
            Positioned(
              left: ox + _imageRect.left * s,
              top: oy + _imageRect.top * s,
              width: _imageRect.width * s,
              height: _imageRect.height * s,
              child: Image.asset(_images[body]!, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _HighlightPainter(ringColor: scheme.surface, highlight: highlight),
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

/// The selected part's band, a dashed leader to its card and a ringed dot.
class _HighlightPainter extends CustomPainter {
  _HighlightPainter({required this.ringColor, required this.highlight});

  final Color ringColor;

  /// Selected part: band start, band end, leader anchor, card edge (canvas coordinates).
  final (Offset, Offset, Offset, Offset)? highlight;

  @override
  void paint(Canvas canvas, Size size) {
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

  @override
  bool shouldRepaint(_HighlightPainter old) => old.highlight != highlight || old.ringColor != ringColor;
}
