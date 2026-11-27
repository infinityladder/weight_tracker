import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:body_log/body_map.dart';
import 'package:body_log/body_outline.dart';
import 'package:body_log/db.dart';
import 'package:body_log/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MeasureField _field(String label) => MeasureField(key: label, label: label, builtIn: true, hidden: false, sortOrder: 0);

/// Top-to-bottom order the bands must follow on every body.
const _torsoAndLegs = ['Neck', 'Shoulders', 'Chest', 'Waist', 'Abdomen', 'Hips', 'L-Thigh', 'L-Above Knee', 'L-Calf'];
const _arm = ['L-Bicep', 'L-Forearm'];

void main() {
  for (final body in Figure.values) {
    testWidgets('the ${body.name} outfit layer lines up with its picture', (tester) async {
      Future<(int, int, ByteData)> load(String path) async {
        final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        return (image.width, image.height, (await image.toByteData())!);
      }

      final (pic, clothes) = (await tester.runAsync(() async => (
            await load(bodyImages[body]!),
            await load(clothesImage(body)),
          )))!;
      // Same size, so it overlays the picture exactly.
      expect((clothes.$1, clothes.$2), (pic.$1, pic.$2));
      // It covers some fabric, but well under half the figure, and only where
      // the picture is solid.
      var fabric = 0, solid = 0, stray = 0;
      for (var i = 0; i < pic.$1 * pic.$2; i++) {
        final onPic = pic.$3.getUint8(i * 4 + 3) > 128;
        final onCloth = clothes.$3.getUint8(i * 4 + 3) > 128;
        if (onPic) solid++;
        if (onCloth) fabric++;
        if (onCloth && !onPic) stray++;
      }
      expect(fabric, greaterThan(solid * 0.04));
      expect(fabric, lessThan(solid * 0.4));
      expect(stray, lessThan(fabric * 0.01));
    });


    testWidgets('every standard measure sits on the ${body.name} picture', (tester) async {
      final (width, height, pixels) = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(File(bodyImages[body]!).readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        final data = await image.toByteData();
        return (image.width, image.height, data!);
      }))!;
      final rect = bodyImageRects[body]!;

      // Whether the picture is solid body (not background) at a point in the
      // 200 x 440 box.
      bool onBody(double x, double y) {
        final px = ((x - rect.left) / rect.width * width).floor();
        final py = ((y - rect.top) / rect.height * height).floor();
        if (px < 0 || py < 0 || px >= width || py >= height) return false;
        return pixels.getUint8((py * width + px) * 4 + 3) > 128;
      }

      // Both ends, just inside, and the middle are on the body: the band
      // spans the part rather than hanging off into the background.
      final off = [
        for (final (key, label) in BodyLogDb.measures)
          if (!customMeasureKeys.contains(key))
            for (final part in [partFor(_field(label), body)!])
              for (final x in [part.x1 + 3, (part.x1 + part.x2) / 2, part.x2 - 3])
                if (!onBody(x, part.y)) '$label at ($x, ${part.y})',
      ];
      expect(off, isEmpty);

      // The outline the layout uses matches the picture (regenerate with
      // tool/body_outline.py after changing one).
      final outline = bodyOutlines[body]!;
      final wrong = [
        for (final (i, row) in outline.indexed)
          if (row != null)
            for (final x in [row.$1 + 1.0, row.$2 - 1.0])
              if (!_anyOnBody(onBody, x, i * outlineStep.toDouble())) 'row $i at $x',
      ];
      expect(wrong, isEmpty);

      double y(String label) => partFor(_field(label), body)!.y;
      for (final order in [_torsoAndLegs, _arm]) {
        for (var i = 1; i < order.length; i++) {
          expect(y(order[i]), greaterThan(y(order[i - 1])), reason: '${order[i]} below ${order[i - 1]}');
        }
      }
    });
  }

  // Cards never cover the body, on small and large screens, with a few or all
  // measurements switched on.
  for (final body in Figure.values) {
    for (final all in [false, true]) {
      for (final size in const [Size(328, 560), Size(352, 448), Size(352, 640), Size(379, 700), Size(768, 1000)]) {
        testWidgets('${body.name}, ${all ? 'all' : 'default'} measurements, $size: no card covers the body',
            (tester) async {
          // Room for the biggest size (the default test screen is 800 x 600).
          tester.view.physicalSize = const Size(1000, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final fields = [
            for (final (key, label) in BodyLogDb.measures)
              if (all || const {'c_chest', 'waist', 'hips', 'c_l_thigh', 'c_r_thigh', 'c_l_calf', 'c_r_calf'}.contains(key))
                MeasureField(key: key, label: label, builtIn: true, hidden: false, sortOrder: 0),
          ];
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: size,
                  child: BodyMap(fields: fields, valueText: (_) => null, onTap: (_) {}, figure: body),
                ),
              ),
            ),
          ));
          final image = tester.getRect(find.byType(Image));
          final rect = bodyImageRects[body]!;
          final s = image.width / rect.width;
          final (ox, oy) = (image.left - rect.left * s, image.top - rect.top * s);
          final outline = bodyOutlines[body]!;
          final covered = <String>[];
          for (final f in fields.where((f) => !f.custom)) {
            final card = tester.getRect(find.ancestor(of: find.text(f.label), matching: find.byType(Positioned)).first);
            for (var y = card.top; y <= card.bottom; y += 1) {
              final i = ((y - oy) / s / outlineStep).floor();
              if (i < 0 || i >= outline.length || outline[i] == null) continue;
              final (lo, hi) = outline[i]!;
              final (bodyLeft, bodyRight) = (ox + lo * s, ox + hi * s);
              if (bodyRight > card.left + 1 && bodyLeft < card.right - 1) {
                covered.add('${f.label} at y $y');
                break;
              }
            }
          }
          expect(covered, isEmpty);
          // Big when only a few measurements leave room beside it; about half
          // the height when all of them fill both columns.
          expect(image.height, greaterThan(size.height * (all ? 0.45 : 0.95)), reason: 'body still a good size');
        });
      }
    }
  }
}

/// Whether the picture is solid anywhere within one outline row of (x, y),
/// give or take a unit sideways.
bool _anyOnBody(bool Function(double, double) onBody, double x, double y) => [
      for (var dy = -0.5; dy <= outlineStep + 0.5; dy += 0.25)
        for (final dx in [-1.0, -0.5, 0.0, 0.5, 1.0]) onBody(x + dx, y + dy),
    ].any((v) => v);
