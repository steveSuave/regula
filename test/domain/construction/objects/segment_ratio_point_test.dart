import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/segment_ratio_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('SegmentRatioPoint', () {
    test('interpolates at the ratio on construction', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 2));
      final p = SegmentRatioPoint(id: 'p', point1: a, point2: b, ratio: 0.25);
      expect(p.position, const Vec2(1, 0.5));
      expect(p.parents, [a, b]);
    });

    test('ratio 0 and 1 sit on the endpoints, 0.5 is the midpoint', () {
      final a = FreePoint(id: 'a', position: const Vec2(-2, 1));
      final b = FreePoint(id: 'b', position: const Vec2(6, 5));
      expect(
        SegmentRatioPoint(id: 'p0', point1: a, point2: b, ratio: 0).position,
        a.position,
      );
      expect(
        SegmentRatioPoint(id: 'p1', point1: a, point2: b, ratio: 1).position,
        b.position,
      );
      expect(
        SegmentRatioPoint(id: 'ph', point1: a, point2: b, ratio: 0.5).position,
        const Vec2(2, 3),
      );
    });

    test('ratios outside [0, 1] extrapolate beyond the endpoints', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(3, 1));
      expect(
        SegmentRatioPoint(id: 'p2', point1: a, point2: b, ratio: 2).position,
        const Vec2(5, 1),
      );
      expect(
        SegmentRatioPoint(id: 'pm', point1: a, point2: b, ratio: -1).position,
        const Vec2(-1, 1),
      );
    });

    test('tracks a moved parent after recompute', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final p = SegmentRatioPoint(id: 'p', point1: a, point2: b, ratio: 0.75);
      b.position = const Vec2(0, 8);
      p.recompute();
      expect(p.position, const Vec2(0, 6));
    });

    test('coincident parents are not degenerate', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final p = SegmentRatioPoint(id: 'p', point1: a, point2: b, ratio: 3);
      expect(p.isDefined, isTrue);
      expect(p.position, const Vec2(1, 1));
    });

    test('undefined while a parent is, recovers after', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final onLine = PointOnObject(id: 'q', curve: line, parameter: 1);
      final anchor = FreePoint(id: 'c', position: const Vec2(0, 2));
      final p = SegmentRatioPoint(
        id: 'p',
        point1: anchor,
        point2: onLine,
        ratio: 0.5,
      );
      expect(p.isDefined, isFalse);

      b.position = const Vec2(2, 0); // line (and onLine) come back
      line.recompute();
      onLine.recompute(); // arc-length parameter 1 → (1, 0)
      p.recompute();
      expect(p.isDefined, isTrue);
      expect(p.position, const Vec2(0.5, 1));
    });
  });
}
