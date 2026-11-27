import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'body_outline.dart';
import 'models.dart';
import 'theme.dart';

/// Where a body part is measured: a horizontal band across the figure in its
/// 200 x 440 design box, and which column its card sits in.
class BodyPart {
  const BodyPart(this.x1, this.x2, this.y, this.right, this.typicalCm, {this.axis});

  final double x1, x2, y;
  final bool right;

  /// Starting point for the size picker when nothing has been logged yet.
  final double typicalCm;

  /// Mirror line for this part when the picture's limbs aren't quite
  /// symmetrical; null uses the figure's centre.
  final double? axis;

  /// The same part on the other side of a body standing centred on [centre].
  BodyPart mirrored([double centre = 100]) {
    final a = axis ?? centre;
    return BodyPart(2 * a - x2, 2 * a - x1, y, !right, typicalCm, axis: axis);
  }
}

/// Each picture's centre line.
const _centres = {
  Figure.male: 100.0,
  Figure.female: 102.0,
  Figure.maleBrown: 98.0,
  Figure.femaleBrown: 101.5,
  Figure.maleDark: 100.0,
  Figure.femaleDark: 99.5,
};

const bodyImages = {
  Figure.male: 'images/body_log_male.png',
  Figure.female: 'images/body_log_female.png',
  Figure.maleBrown: 'images/body_log_male_brown_skin.png',
  Figure.femaleBrown: 'images/body_log_female_brown_skin.png',
  Figure.maleDark: 'images/body_log_male_dark_skin.png',
  Figure.femaleDark: 'images/body_log_female_dark_skin.png',
};

/// The fabric layer of a body picture, tinted with the outfit colour
/// (made by tool/clothes_mask.py).
String clothesImage(Figure f) => bodyImages[f]!.replaceFirst('images/', 'images/clothes/');

/// Where each body picture sits in the 200 x 440 box. The light pictures fill
/// the width; the others are framed differently, so they're scaled to the
/// same body height (or as tall as the outstretched hands allow) and centred
/// on the same spot.
const bodyImageRects = {
  Figure.male: Rect.fromLTWH(0, 38.37, 200, 363.27),
  Figure.female: Rect.fromLTWH(0, 29.25, 200, 381.5),
  Figure.maleBrown: Rect.fromLTWH(0.5, 39.39, 204.32, 363.24),
  Figure.femaleBrown: Rect.fromLTWH(-7.15, 34.34, 206.65, 373.22),
  Figure.maleDark: Rect.fromLTWH(-9.94, 43.22, 213.26, 356.25),
  Figure.femaleDark: Rect.fromLTWH(4.91, 24.51, 198.99, 391.86),
};

/// Keyword -> where it sits on each figure, most specific first ("forearm"
/// before "arm", "above knee" before "knee"). Positions are measured on each
/// picture as placed by [bodyImageRects], at the standard tape landmarks
/// (ISO 8559-1, WHO): neck below the Adam's apple; shoulders round the widest
/// part of the deltoids; chest at the nipples, bust at its fullest; upper arm
/// halfway from shoulder tip to elbow (or just below, where the arm first
/// clears the chest); forearm at its widest just below the elbow; wrist at the
/// crease; waist halfway between the lowest rib and the top of the hip bone;
/// belly at the navel; hips round the widest part of the buttocks; thigh just
/// below the buttock fold; above knee just over the kneecap; knee across the
/// middle of the kneecap; calf at its widest; ankle at its narrowest.
const _parts = <(String, Map<Figure, BodyPart>)>[
  ('neck', {
    Figure.male: BodyPart(87, 112, 90, false, 38),
    Figure.female: BodyPart(89, 106, 90, false, 33),
    Figure.maleBrown: BodyPart(85, 109, 99, false, 38),
    Figure.femaleBrown: BodyPart(92, 112, 100, false, 33),
    Figure.maleDark: BodyPart(88, 112, 98, false, 38),
    Figure.femaleDark: BodyPart(88, 106, 96, false, 33),
  }),
  ('shoulder', {
    Figure.male: BodyPart(48, 152, 124, true, 110),
    Figure.female: BodyPart(54, 147, 124, true, 100),
    Figure.maleBrown: BodyPart(45, 149, 130, true, 110),
    Figure.femaleBrown: BodyPart(57, 148, 132, true, 100),
    Figure.maleDark: BodyPart(50, 149, 125, true, 110),
    Figure.femaleDark: BodyPart(54, 141, 128, true, 100),
  }),
  ('chest', _chest),
  ('bust', _chest),
  ('forearm', {
    Figure.male: BodyPart(30, 53, 178, false, 27),
    Figure.female: BodyPart(36, 57, 178, false, 23),
    Figure.maleBrown: BodyPart(32, 53, 180, false, 27),
    Figure.femaleBrown: BodyPart(43, 61, 179, false, 23),
    Figure.maleDark: BodyPart(35, 57, 174, false, 27),
    Figure.femaleDark: BodyPart(44, 62, 176, false, 23),
  }),
  ('wrist', {
    Figure.male: BodyPart(17, 34, 200, false, 16),
    Figure.female: BodyPart(20, 35, 201, false, 15),
    Figure.maleBrown: BodyPart(18, 33, 208, false, 16),
    Figure.femaleBrown: BodyPart(26, 37, 205, false, 15),
    Figure.maleDark: BodyPart(20, 34, 205, false, 16),
    Figure.femaleDark: BodyPart(26, 38, 210, false, 15),
  }),
  ('bicep', _upperArm),
  ('arm', _upperArm),
  ('belly', _belly),
  ('abdom', _belly),
  ('stomach', _belly),
  ('waist', {
    Figure.male: BodyPart(72, 128, 172, true, 80),
    Figure.female: BodyPart(76, 125, 170, true, 72),
    Figure.maleBrown: BodyPart(70, 125, 179, true, 80),
    Figure.femaleBrown: BodyPart(78, 126, 180, true, 72),
    Figure.maleDark: BodyPart(72, 127, 174, true, 80),
    Figure.femaleDark: BodyPart(77, 121, 176, true, 72),
  }),
  ('hip', _hips),
  ('glute', _hips),
  ('above knee', {
    Figure.male: BodyPart(64, 91, 276, false, 42),
    Figure.female: BodyPart(65, 92, 276, false, 42),
    Figure.maleBrown: BodyPart(62, 89, 280, false, 42),
    Figure.femaleBrown: BodyPart(66, 91, 285, false, 42),
    Figure.maleDark: BodyPart(65, 90, 275, false, 42),
    Figure.femaleDark: BodyPart(67, 92, 280, false, 42),
  }),
  ('thigh', {
    Figure.male: BodyPart(61, 94, 258, false, 55),
    Figure.female: BodyPart(61, 95, 254, false, 57),
    Figure.maleBrown: BodyPart(59, 93, 263, false, 55),
    Figure.femaleBrown: BodyPart(61, 97, 256, false, 57),
    Figure.maleDark: BodyPart(63, 93, 258, false, 55),
    Figure.femaleDark: BodyPart(62, 96, 250, false, 57),
  }),
  ('knee', {
    Figure.male: BodyPart(65, 88, 292, false, 38),
    Figure.female: BodyPart(66, 89, 292, false, 37),
    Figure.maleBrown: BodyPart(63, 87, 293, false, 38),
    Figure.femaleBrown: BodyPart(66, 88, 299, false, 37),
    Figure.maleDark: BodyPart(65, 87, 289, false, 38),
    Figure.femaleDark: BodyPart(68, 90, 293, false, 37),
  }),
  ('calf', {
    Figure.male: BodyPart(114, 141, 322, true, 37),
    Figure.female: BodyPart(119, 146, 322, true, 35),
    Figure.maleBrown: BodyPart(114, 140, 320, true, 37),
    Figure.femaleBrown: BodyPart(117, 144, 324, true, 35),
    Figure.maleDark: BodyPart(116, 141, 315, true, 37),
    Figure.femaleDark: BodyPart(113, 138, 322, true, 35),
  }),
  ('ankle', {
    Figure.male: BodyPart(123, 135, 366, true, 22),
    Figure.female: BodyPart(130, 142, 366, true, 21),
    Figure.maleBrown: BodyPart(124, 135, 362, true, 22),
    Figure.femaleBrown: BodyPart(127, 138, 372, true, 21),
    Figure.maleDark: BodyPart(125, 134, 360, true, 22),
    Figure.femaleDark: BodyPart(125, 134, 372, true, 21, axis: 101.5),
  }),
];

const _chest = {
  Figure.male: BodyPart(60, 140, 138, false, 95),
  Figure.female: BodyPart(70, 131, 135, false, 90),
  Figure.maleBrown: BodyPart(57, 139, 146, false, 95),
  Figure.femaleBrown: BodyPart(72, 132, 140, false, 90),
  Figure.maleDark: BodyPart(60, 140, 141, false, 95),
  Figure.femaleDark: BodyPart(68, 131, 142, false, 90),
};
const _upperArm = {
  Figure.male: BodyPart(43, 65, 148, false, 30),
  Figure.female: BodyPart(54, 69, 148, false, 27),
  Figure.maleBrown: BodyPart(40, 62, 160, false, 30, axis: 97),
  Figure.femaleBrown: BodyPart(54, 69, 158, false, 27),
  Figure.maleDark: BodyPart(45, 65, 154, false, 30),
  Figure.femaleDark: BodyPart(55, 69, 150, false, 27),
};
const _belly = {
  Figure.male: BodyPart(71, 129, 178, false, 85),
  Figure.female: BodyPart(72, 130, 178, false, 78),
  Figure.maleBrown: BodyPart(69, 126, 185, false, 85),
  Figure.femaleBrown: BodyPart(75, 129, 187, false, 78),
  Figure.maleDark: BodyPart(71, 128, 180, false, 85),
  Figure.femaleDark: BodyPart(74, 125, 184, false, 78),
};
const _hips = {
  Figure.male: BodyPart(62, 138, 214, true, 98),
  Figure.female: BodyPart(60, 144, 214, true, 100),
  Figure.maleBrown: BodyPart(60, 136, 215, true, 98),
  Figure.femaleBrown: BodyPart(62, 141, 215, true, 100),
  Figure.maleDark: BodyPart(62, 137, 215, true, 98),
  Figure.femaleDark: BodyPart(61, 137, 215, true, 100),
};

/// The part a field measures on [figure], matched by name. "L-"/"left" and
/// "R-"/"right" pick the side; null when the name isn't a known body part.
BodyPart? partFor(MeasureField f, [Figure figure = Figure.male]) {
  if (f.custom) return null;
  final name = f.label.toLowerCase();
  final left = name.startsWith('l-') || name.startsWith('l ') || name.contains('left');
  final right = name.startsWith('r-') || name.startsWith('r ') || name.contains('right');
  final words = name.replaceAll(RegExp(r'[-_]'), ' ');
  for (final (keyword, positions) in _parts) {
    if (!words.contains(keyword)) continue;
    final part = positions[figure]!;
    if ((left && part.right) || (right && !part.right)) return part.mirrored(_centres[figure]!);
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
    this.figure = Figure.male,
    this.outfit = Outfit.black,
  });

  final List<MeasureField> fields;
  final Figure figure;
  final Outfit outfit;

  /// Display text for a field's latest value, or null when never logged.
  final String? Function(MeasureField f) valueText;
  final void Function(MeasureField f) onTap;
  final String? selectedKey;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Split into columns, each ordered top to bottom on the body; fields that
    // aren't a known part go at the end of the shorter column.
    final left = <(MeasureField, BodyPart?)>[], right = <(MeasureField, BodyPart?)>[];
    final unplaced = <MeasureField>[], custom = <MeasureField>[];
    for (final f in fields) {
      final part = partFor(f, figure);
      if (f.custom) {
        custom.add(f);
      } else if (part == null) {
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

    final map = LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final rows = math.max(1, math.max(left.length, right.length));
      // Narrow enough to leave the body room; values like "104.5 cm" still fit.
      final cardW = ((w - 24) * 0.25).clamp(86.0, 120.0);
      final cardH = ((c.maxHeight - _gap * (rows - 1)) / rows).clamp(52.0, 58.0);
      final h = math.max(c.maxHeight, rows * cardH + (rows - 1) * _gap);

      final pic = bodyImageRects[figure]!, outline = bodyOutlines[figure]!;
      const clear = 6.0; // space kept between a card and the body

      // The body's leftmost and rightmost points between two heights in the
      // 200 x 440 box; null where there's no body.
      (int, int)? extent(double y0, double y1) {
        final i0 = math.max(0, (y0 / outlineStep).floor());
        final i1 = math.min(outline.length - 1, (y1 / outlineStep).ceil());
        int? lo, hi;
        for (var i = i0; i <= i1; i++) {
          final row = outline[i];
          if (row == null) continue;
          lo = lo == null ? row.$1 : math.min(lo, row.$1);
          hi = hi == null ? row.$2 : math.max(hi, row.$2);
        }
        return lo == null ? null : (lo, hi!);
      }

      // Cards at scale [s]: each sits level with its part, slides down past
      // any of the body it would cover, clears the card above, and the column
      // is pulled back up if it runs off the bottom. Null if a card still
      // covers the body.
      ({double ox, double oy, Map<bool, List<double>> tops})? layout(double s, {bool check = true}) {
        final ox = (w - 200 * s) / 2, oy = (h - pic.height * s) / 2 - pic.top * s;
        bool covers(bool isRight, double top) {
          if (!check) return false;
          final e = extent((top - oy) / s, (top + cardH - oy) / s);
          if (e == null) return false;
          return isRight ? ox + e.$2 * s > w - cardW - clear : ox + e.$1 * s < cardW + clear;
        }

        List<double>? topsFor(bool isRight, List<(MeasureField, BodyPart?)> column) {
          final tops = <double>[];
          var next = 0.0;
          for (final (_, part) in column) {
            final want = math.max(part == null ? next : part.y * s + oy - cardH / 2, next);
            // The nearest free spot, below or (not past the card above) above.
            var top = want;
            for (var d = 0.0; covers(isRight, top) && d < h; d += 4) {
              if (!covers(isRight, want + d)) {
                top = want + d;
              } else if (want - d >= next && !covers(isRight, want - d)) {
                top = want - d;
              }
            }
            tops.add(top);
            next = top + cardH + _gap;
          }
          var limit = h - cardH;
          for (var i = tops.length - 1; i >= 0; i--) {
            tops[i] = math.min(tops[i], limit);
            limit = tops[i] - cardH - _gap;
          }
          return tops.any((t) => covers(isRight, t)) ? null : tops;
        }

        final l = topsFor(false, left), r = topsFor(true, right);
        return l == null || r == null ? null : (ox: ox, oy: oy, tops: {false: l, true: r});
      }

      // The biggest body no card covers: from filling the height down to the
      // size that fits between the columns at every height.
      final sFull = (h - 8) / pic.height;
      final sBeside = math.max(0.3, (w - 2 * cardW - 2 * clear) / 200);
      var s = sFull;
      var placed = layout(s);
      while (placed == null && s > sBeside) {
        s = math.max(sBeside, s - 0.02);
        placed = layout(s);
      }
      placed ??= layout(s, check: false)!;
      final (ox, oy, columnTops) = (placed.ox, placed.oy, placed.tops);
      Offset toCanvas(double x, double y) => Offset(ox + x * s, oy + y * s);

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
          // The size picker sheet covers roughly the lower half: slide the
          // map up so both the card and the highlighted part stay visible,
          // but never so far that the top of either slides out of view.
          final top = math.min(columnTops[isRight]![i], part.y * s + oy - 12);
          final lowest = math.max(columnTops[isRight]![i] + cardH, part.y * s + oy + 12);
          shift = (lowest - c.maxHeight * 0.48).clamp(0.0, math.max(0.0, top - 8));
        }
      }

      final stack = SizedBox(
        height: h,
        child: Stack(
          children: [
            Positioned(
              left: ox + pic.left * s,
              top: oy + pic.top * s,
              width: pic.width * s,
              height: pic.height * s,
              child: Image.asset(bodyImages[figure]!, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
            ),
            if (outfit.tint case final tint?)
              Positioned(
                left: ox + pic.left * s,
                top: oy + pic.top * s,
                width: pic.width * s,
                height: pic.height * s,
                child: Image.asset(
                  clothesImage(figure),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  color: Color(tint),
                  colorBlendMode: BlendMode.modulate,
                ),
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
    if (custom.isEmpty) return map;

    // Custom measurements aren't on the body: a row of cards underneath.
    return Column(
      children: [
        Expanded(child: map),
        const SizedBox(height: _gap),
        SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (i, f) in custom.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  child: _PartCard(
                    field: f,
                    value: valueText(f),
                    selected: f.key == selectedKey,
                    onTap: () => onTap(f),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
                          TextSpan(text: parts.first, style: numberStyle(21, color: fg)),
                          TextSpan(
                              text: ' ${parts.skip(1).join(' ')}',
                              style: numberStyle(13, color: muted, weight: FontWeight.w500)),
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
