import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_log/body_map.dart';
import 'package:body_log/db.dart';
import 'package:body_log/models.dart';
import 'package:flutter_test/flutter_test.dart';

MeasureField _field(String label) => MeasureField(key: label, label: label, builtIn: true, hidden: false, sortOrder: 0);

/// Top-to-bottom order the bands must follow on every body.
const _torsoAndLegs = ['Neck', 'Shoulders', 'Chest', 'Waist', 'Abdomen', 'Hips', 'L-Thigh', 'L-Above Knee', 'L-Calf'];
const _arm = ['L-Bicep', 'L-Forearm'];

void main() {
  for (final body in BodyType.values) {
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

      double y(String label) => partFor(_field(label), body)!.y;
      for (final order in [_torsoAndLegs, _arm]) {
        for (var i = 1; i < order.length; i++) {
          expect(y(order[i]), greaterThan(y(order[i - 1])), reason: '${order[i]} below ${order[i - 1]}');
        }
      }
    });
  }
}
