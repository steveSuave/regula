import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/point_on_object.dart';
import 'package:fgex/domain/construction/objects/translated_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranslatedPoint', () {
    test('translates by the vector on construction', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 2));
      final from = FreePoint(id: 'f', position: const Vec2(0, 0));
      final to = FreePoint(id: 't', position: const Vec2(3, -1));
      final r = TranslatedPoint(
        id: 'r',
        point: p,
        vectorFrom: from,
        vectorTo: to,
      );
      expect(r.position, const Vec2(4, 1));
      expect(r.parents, [p, from, to]);
    });

    test('image minus point equals the vector, also after drags', () {
      final p = FreePoint(id: 'p', position: const Vec2(-2, 5));
      final from = FreePoint(id: 'f', position: const Vec2(1, 1));
      final to = FreePoint(id: 't', position: const Vec2(4, -2));
      final r = TranslatedPoint(
        id: 'r',
        point: p,
        vectorFrom: from,
        vectorTo: to,
      );
      expect(r.position! - p.position, to.position - from.position);

      to.position = const Vec2(-6, 3);
      r.recompute();
      expect(r.position! - p.position, to.position - from.position);

      p.position = const Vec2(9, 9);
      r.recompute();
      expect(r.position! - p.position, to.position - from.position);
    });

    test('coincident vector points give the zero translation', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 2));
      final from = FreePoint(id: 'f', position: const Vec2(3, 3));
      final to = FreePoint(id: 't', position: const Vec2(3, 3));
      final r = TranslatedPoint(
        id: 'r',
        point: p,
        vectorFrom: from,
        vectorTo: to,
      );
      expect(r.isDefined, isTrue);
      expect(r.position, const Vec2(1, 2));
    });

    test('undefined while a parent is, recovers after', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final onLine = PointOnObject(id: 'q', curve: line, parameter: 1);
      final p = FreePoint(id: 'p', position: const Vec2(1, 1));
      final from = FreePoint(id: 'f', position: const Vec2(0, 0));
      final r = TranslatedPoint(
        id: 'r',
        point: p,
        vectorFrom: from,
        vectorTo: onLine,
      );
      expect(r.isDefined, isFalse);

      b.position = const Vec2(0, 2); // onLine comes back at (0, 1)
      line.recompute();
      onLine.recompute();
      r.recompute();
      expect(r.isDefined, isTrue);
      expect(r.position, const Vec2(1, 2));
    });
  });
}
