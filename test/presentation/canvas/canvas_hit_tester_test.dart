import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/geo_object.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/arc.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/ray.dart';
import 'package:fgex/domain/construction/objects/sector.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/construction/objects/vertex_angle.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/presentation/canvas/canvas_hit_tester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tester = CanvasHitTester();
  const threshold = 0.5;

  GeoObject? hit(Construction construction, Vec2 point) =>
      tester.hitTest(construction.objects, point, threshold);

  group('CanvasHitTester', () {
    test('returns null on an empty construction or when nothing is near', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));

      expect(hit(Construction(), Vec2.zero), isNull);
      expect(hit(construction, const Vec2(10, 10)), isNull);
    });

    test('picks the closest point within the threshold', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero))
        ..add(FreePoint(id: 'b', position: const Vec2(0.6, 0)));

      expect(hit(construction, const Vec2(0.4, 0))?.id, 'b');
      expect(hit(construction, const Vec2(0.1, 0))?.id, 'a');
    });

    test('a point in range beats a closer line', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(10, 0));
      construction
        ..add(a)
        ..add(b)
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: b))
        ..add(FreePoint(id: 'p', position: const Vec2(5, 0.4)));

      // Tap sits on the line (distance 0) and 0.4 from the point: the
      // point still wins on priority.
      expect(hit(construction, const Vec2(5, 0))?.id, 'p');
    });

    test('infinite line is hit far beyond its defining points', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(1, 0));
      construction
        ..add(a)
        ..add(b)
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: b));

      expect(hit(construction, const Vec2(100, 0.3))?.id, 'l');
    });

    test('segment is only hit within its extent', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(1, 0));
      construction
        ..add(a)
        ..add(b)
        ..add(Segment(id: 's', point1: a, point2: b));

      expect(hit(construction, const Vec2(0.5, 0.3))?.id, 's');
      expect(hit(construction, const Vec2(3, 0.3)), isNull,
          reason: 'past the endpoint the carrier line must not count');
    });

    test('ray is hit beyond its through point but not behind its origin',
        () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(1, 0));
      construction
        ..add(a)
        ..add(b)
        ..add(Ray(id: 'r', origin: a, through: b));

      expect(hit(construction, const Vec2(100, 0.3))?.id, 'r',
          reason: 'a ray extends past its through point');
      expect(hit(construction, const Vec2(-3, 0.3)), isNull,
          reason: 'behind the origin the carrier line must not count');
    });

    test('arc is only hit on its branch of the carrier', () {
      // The defining points are hidden so they can't win on priority —
      // this test is about the arc's own distance logic.
      const hidden = ObjectAttributes(visible: false);
      final construction = Construction();
      final s = FreePoint(id: 's', position: const Vec2(1, 0), attributes: hidden);
      final v = FreePoint(id: 'v', position: const Vec2(0, 1), attributes: hidden);
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0), attributes: hidden);
      construction
        ..add(s)
        ..add(v)
        ..add(e)
        ..add(Arc(id: 'arc', start: s, via: v, end: e));

      expect(hit(construction, const Vec2(0, 1.3))?.id, 'arc');
      expect(hit(construction, const Vec2(0, -1.3)), isNull,
          reason: 'the far branch of the carrier must not count');
      expect(hit(construction, const Vec2(-1, -0.4))?.id, 'arc',
          reason: 'just past an endpoint the endpoint distance rules');
      expect(hit(construction, const Vec2(-1.2, -1.2)), isNull,
          reason: 'far from both the branch and the endpoints');
    });

    test('sector is hit on its outline: arc branch and both radius edges',
        () {
      // Hidden defining points, as in the arc test: outline logic only.
      const hidden = ObjectAttributes(visible: false);
      final construction = Construction();
      final c =
          FreePoint(id: 'c', position: Vec2.zero, attributes: hidden);
      final s =
          FreePoint(id: 's', position: const Vec2(2, 0), attributes: hidden);
      final e =
          FreePoint(id: 'e', position: const Vec2(0, 5), attributes: hidden);
      construction
        ..add(c)
        ..add(s)
        ..add(e)
        // Quarter wedge of radius 2 in the first quadrant.
        ..add(Sector(id: 'w', center: c, start: s, end: e));

      expect(hit(construction, const Vec2(1.7, 1.7))?.id, 'w',
          reason: 'near the arc branch');
      expect(hit(construction, const Vec2(1, 0.3))?.id, 'w',
          reason: 'near the start radius edge');
      expect(hit(construction, const Vec2(0.3, 1))?.id, 'w',
          reason: 'near the end radius edge — at radius 2, not at end');
      expect(hit(construction, const Vec2(0.7, 0.7)), isNull,
          reason: 'inside the pie but far from the outline');
      expect(hit(construction, const Vec2(1.4, -1.4)), isNull,
          reason: 'on the carrier but outside the sweep');
    });

    test('circle is hit near its boundary, not near its center', () {
      final construction = Construction();
      final center = FreePoint(id: 'c', position: Vec2.zero);
      final rim = FreePoint(id: 'r', position: const Vec2(5, 0));
      construction
        ..add(center)
        ..add(rim)
        ..add(CircleCenterPoint(id: 'k', center: center, onCircle: rim));

      expect(hit(construction, const Vec2(0, 5.2))?.id, 'k');
      expect(hit(construction, const Vec2(2, 2)), isNull,
          reason: 'inside the disc but far from the boundary');
    });

    test('angle is picked at its vertex, and anything else there wins', () {
      const hidden = ObjectAttributes(visible: false);
      final construction = Construction();
      final a =
          FreePoint(id: 'a', position: const Vec2(3, 0), attributes: hidden);
      final v = FreePoint(id: 'v', position: Vec2.zero, attributes: hidden);
      final b =
          FreePoint(id: 'b', position: const Vec2(0, 3), attributes: hidden);
      construction
        ..add(a)
        ..add(v)
        ..add(b)
        ..add(VertexAngle(id: 'g', arm1: a, vertex: v, arm2: b));

      expect(hit(construction, const Vec2(0.2, 0.2))?.id, 'g');
      expect(hit(construction, const Vec2(1.5, 1.5)), isNull,
          reason: 'only the vertex is pickable');

      construction.add(FreePoint(id: 'p', position: Vec2.zero));
      expect(hit(construction, const Vec2(0.2, 0.2))?.id, 'p',
          reason: 'angles have the lowest priority');
    });

    test('invisible and undefined objects are never hit', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(
        id: 'b',
        position: Vec2.zero, // coincides with a → line undefined
      );
      final hidden = FreePoint(
        id: 'h',
        position: const Vec2(3, 3),
        attributes: const ObjectAttributes(visible: false),
      );
      construction
        ..add(a)
        ..add(b)
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: b))
        ..add(hidden);

      expect(hit(construction, const Vec2(3, 3)), isNull);
      expect(hit(construction, const Vec2(0.2, 0)), isNot(hasId('l')));
    });

    test('coincident points: the later (topmost) one wins', () {
      final construction = Construction()
        ..add(FreePoint(id: 'under', position: Vec2.zero))
        ..add(FreePoint(id: 'over', position: Vec2.zero));

      expect(hit(construction, const Vec2(0.1, 0))?.id, 'over');
    });
  });
}

Matcher hasId(String id) =>
    isA<GeoObject>().having((o) => o.id, 'id', id);
