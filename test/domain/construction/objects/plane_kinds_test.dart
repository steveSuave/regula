// Intent 004, milestone 2, stage B: the plane kinds and what planes give.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_plane_intersection_point.dart';
import 'package:regula/domain/construction/objects/line_point_plane.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/parallel_plane.dart';
import 'package:regula/domain/construction/objects/perpendicular_plane.dart';
import 'package:regula/domain/construction/objects/perpendicular_to_plane_line.dart';
import 'package:regula/domain/construction/objects/plane_intersection_line.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/point3.dart';

import '../../../kitchen_sink.dart';

FreePoint _p(String id, double x, double y, [double h = 0]) =>
    FreePoint(id: id, position: Vec2(x, y), height: h);

void _expectOrthonormal(GeoPlane plane) {
  final f = plane.frame!;
  expect(f.u.norm, closeTo(1, 1e-12));
  expect(f.v.norm, closeTo(1, 1e-12));
  expect(f.u.dot(f.v), closeTo(0, 1e-12));
  expect(plane.spacePlane!.contains(Point3.lift(f.origin), 1e-9), isTrue);
  expect(
    plane.spacePlane!.normal.cross(f.normal).norm /
        plane.spacePlane!.normal.norm,
    lessThan(1e-9),
    reason: 'the frame lies in the plane',
  );
}

void main() {
  group('ThreePointPlane', () {
    test('passes through its points, origin at the first, u to the second', () {
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final o = _p('o', 2, 2, 3);
      final plane = ThreePointPlane(id: 'p', point1: o, point2: a, point3: b);
      _expectOrthonormal(plane);
      for (final p in [a, b, o]) {
        expect(plane.spacePlane!.contains(p.spacePoint!, 1e-9), isTrue);
      }
      expect(plane.frame!.origin, const Vec3(2, 2, 3));
      expect(
        plane.frame!.u.cross(const Vec3(-2, -2, -3)).norm,
        lessThan(1e-12),
      );
      expect(plane.labelAnchor, const Vec3(2, 2 / 3, 1));
      expect(plane.sheetFrame, isNull);
      expect(plane.isDefined, isTrue);
    });

    test('three base points give the base plane with the normal up', () {
      final plane = ThreePointPlane(
        id: 'p',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('c', 0, 4),
      );
      expect(plane.frame!.normal, const Vec3(0, 0, 1));
      expect(plane.frame!.u, const Vec3(1, 0, 0));
      expect(plane.frame!.v, const Vec3(0, 1, 0));
    });

    test('is undefined exactly when the points are collinear', () {
      final c = Construction();
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final x = _p('x', 8, 0);
      final plane = ThreePointPlane(id: 'p', point1: a, point2: b, point3: x);
      c
        ..add(a)
        ..add(b)
        ..add(x)
        ..add(plane);
      expect(plane.spacePlane, isNull);
      expect(plane.isDefined, isFalse);

      c.setFreePointHeight('x', 1e-9);
      expect(plane.isDefined, isTrue, reason: 'near-collinear is a plane');
      _expectOrthonormal(plane);
      c.setFreePointHeight('x', 0);
      expect(plane.isDefined, isFalse);
    });

    test('its frame moves continuously with a defining point', () {
      final c = Construction();
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final o = _p('o', 2, 2, 3);
      final plane = ThreePointPlane(id: 'p', point1: a, point2: b, point3: o);
      c
        ..add(a)
        ..add(b)
        ..add(o)
        ..add(plane);
      final before = plane.frame!;
      c.moveFreePoint('o', const Vec2(2.001, 2));
      final after = plane.frame!;
      expect(after.u.distanceTo(before.u), lessThan(1e-2));
      expect(after.v.distanceTo(before.v), lessThan(1e-2));
    });
  });

  group('LinePointPlane', () {
    test('contains the line and the point; the line is its x-axis', () {
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final o = _p('o', 1, 3, 4);
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final plane = LinePointPlane(id: 'p', line: line, point: o);
      _expectOrthonormal(plane);
      expect(line.spaceLine!.liesIn(plane.spacePlane!), isTrue);
      expect(plane.spacePlane!.contains(o.spacePoint!, 1e-9), isTrue);
      expect(plane.frame!.origin, const Vec3(1, 0, 0));
      expect(plane.frame!.u, const Vec3(1, 0, 0));
      // The point sits on the positive y-axis of the frame.
      final at = plane.frame!.pull(const Vec3(1, 3, 4));
      expect(at.x, closeTo(0, 1e-12));
      expect(at.y, closeTo(5, 1e-12));
    });

    test('takes a segment in space as its line', () {
      final a = _p('a', 0, 0);
      final o = _p('o', 0, 0, 5);
      final q = _p('q', 3, 0);
      final edge = Segment(id: 's', point1: a, point2: o);
      final plane = LinePointPlane(id: 'p', line: edge, point: q);
      expect(plane.spacePlane!.contains(const Point3(1, 0, 2), 1e-9), isTrue);
    });

    test('is undefined exactly when the point is on the line', () {
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      expect(
        LinePointPlane(id: 'p', line: line, point: _p('x', 9, 0)).isDefined,
        isFalse,
      );
      expect(
        LinePointPlane(
          id: 'p',
          line: line,
          point: _p('x', 9, 0, 1e-9),
        ).isDefined,
        isTrue,
      );
    });
  });

  group('PerpendicularPlane', () {
    test('has the line as its normal and passes through the point', () {
      final a = _p('a', 0, 0);
      final o = _p('o', 0, 0, 5);
      final axis = Segment(id: 's', point1: a, point2: o);
      final through = _p('t', 2, 1, 3);
      final plane = PerpendicularPlane(id: 'p', through: through, line: axis);
      _expectOrthonormal(plane);
      expect(plane.frame!.origin, const Vec3(2, 1, 3));
      expect(plane.frame!.normal, const Vec3(0, 0, 1));
      // Horizontal: the base axes.
      expect(plane.frame!.u, const Vec3(1, 0, 0));
      expect(plane.spacePlane!.contains(const Point3(-7, 9, 3)), isTrue);
    });

    test('a vertical one reads level and up', () {
      final a = _p('a', 0, 0);
      final b = _p('b', 0, 4);
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final plane = PerpendicularPlane(id: 'p', through: a, line: line);
      expect(plane.frame!.v.z.abs(), closeTo(1, 1e-12));
      expect(plane.frame!.u.z, closeTo(0, 1e-12));
    });
  });

  group('ParallelPlane', () {
    test('keeps the reference frame, moved to the point', () {
      final base = ThreePointPlane(
        id: 'b',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('o', 2, 2, 3),
      );
      final through = _p('t', 1, 1, 7);
      final plane = ParallelPlane(id: 'p', through: through, reference: base);
      _expectOrthonormal(plane);
      expect(plane.frame!.origin, const Vec3(1, 1, 7));
      expect(plane.frame!.u, base.frame!.u);
      expect(plane.frame!.v, base.frame!.v);
      expect(plane.spacePlane!.meet(base.spacePlane!).isFinite(), isFalse);
    });
  });

  group('PerpendicularToPlaneLine', () {
    test('runs along the normal through the point, with no planar value', () {
      final base = ThreePointPlane(
        id: 'b',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('c', 0, 4),
      );
      final o = _p('o', 2, 2, 3);
      final line = PerpendicularToPlaneLine(id: 'h', through: o, plane: base);
      expect(line.projLine, isNull);
      expect(line.line, isNull);
      expect(line.sheetFrame, isNull);
      expect(line.isDefined, isTrue);
      expect(line.hasSpaceExtent, isTrue);
      expect(line.spaceLine!.contains(const Point3(2, 2, -9)), isTrue);
      // Oriented along the plane's normal.
      expect(line.spaceLine!.direction.dot(base.frame!.normal), greaterThan(0));
    });
  });

  group('LinePlaneIntersectionPoint', () {
    late ThreePointPlane base;
    setUp(() {
      base = ThreePointPlane(
        id: 'b',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('c', 0, 4),
      );
    });

    test('is the foot of a height', () {
      final o = _p('o', 2, 2, 3);
      final height = PerpendicularToPlaneLine(id: 'h', through: o, plane: base);
      final foot = LinePlaneIntersectionPoint(
        id: 'f',
        line: height,
        plane: base,
      );
      expect(
        foot.spacePosition!.distanceTo(const Vec3(2, 2, 0)),
        lessThan(1e-12),
      );
      expect(foot.position, isNull);
      expect(foot.projPoint, isNull);
      expect(foot.isDefined, isTrue);
    });

    test('a line parallel to the plane meets it at infinity: a value, not a '
        'position', () {
      final p = _p('p', 0, 0, 2);
      final q = _p('q', 5, 1, 2);
      final line = LineThroughTwoPoints(id: 'l', point1: p, point2: q);
      final x = LinePlaneIntersectionPoint(id: 'x', line: line, plane: base);
      expect(x.spacePoint, isNotNull);
      expect(x.spacePoint!.w, 0);
      expect(x.spacePosition, isNull);
      expect(x.isDefined, isFalse);
    });

    test('a line in the plane meets it nowhere in particular', () {
      final p = _p('p', 1, 1);
      final q = _p('q', 5, 2);
      final line = LineThroughTwoPoints(id: 'l', point1: p, point2: q);
      final x = LinePlaneIntersectionPoint(id: 'x', line: line, plane: base);
      expect(x.spacePoint, isNull);
    });

    test('a nearly parallel line meets it far away, for real', () {
      final p = _p('p', 0, 0, 2);
      final q = _p('q', 5, 0, 2 - 1e-6);
      final line = LineThroughTwoPoints(id: 'l', point1: p, point2: q);
      final x = LinePlaneIntersectionPoint(id: 'x', line: line, plane: base);
      expect(x.spacePosition!.x, closeTo(1e7, 1));
    });
  });

  group('PlaneIntersectionLine', () {
    test('is the edge two faces share', () {
      final a = _p('a', 0, 0);
      final b = _p('b', 4, 0);
      final c = _p('c', 4, 4);
      final o = _p('o', 2, 2, 3);
      final oab = ThreePointPlane(id: 'p', point1: o, point2: a, point3: b);
      final obc = ThreePointPlane(id: 'q', point1: o, point2: b, point3: c);
      final edge = PlaneIntersectionLine(id: 'e', plane1: oab, plane2: obc);
      expect(edge.isDefined, isTrue);
      expect(edge.spaceLine!.contains(o.spacePoint!, 1e-9), isTrue);
      expect(edge.spaceLine!.contains(b.spacePoint!, 1e-9), isTrue);
      expect(edge.line, isNull);
    });

    test('parallel planes share a line at infinity, which draws nothing', () {
      final base = ThreePointPlane(
        id: 'b',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('c', 0, 4),
      );
      final lid = ParallelPlane(
        id: 'l',
        through: _p('t', 0, 0, 2),
        reference: base,
      );
      final edge = PlaneIntersectionLine(id: 'e', plane1: base, plane2: lid);
      expect(edge.spaceLine, isNotNull);
      expect(edge.isDefined, isFalse);
    });

    test('a plane with itself shares no line', () {
      final base = ThreePointPlane(
        id: 'b',
        point1: _p('a', 0, 0),
        point2: _p('b', 4, 0),
        point3: _p('c', 0, 4),
      );
      final edge = PlaneIntersectionLine(id: 'e', plane1: base, plane2: base);
      expect(edge.spaceLine, isNull);
    });
  });

  group('the pyramid', () {
    test('every space kind in the sink is defined and survives a drag', () {
      final c = buildSpaceKinds();
      for (final object in c.objects) {
        expect(object.isDefined, isTrue, reason: object.id);
      }
      final foot = c.byId('sfoot')! as GeoPoint;
      expect(
        foot.spacePosition!.distanceTo(const Vec3(2, 2, 0)),
        lessThan(1e-12),
      );

      // Tilt the base: lift a base vertex. The height still stands on it.
      c.setFreePointHeight('sc', 2);
      final base = c.byId('sbase')! as GeoPlane;
      final height = c.byId('sh')! as GeoLine;
      expect(base.spacePlane!.contains(foot.spacePoint!, 1e-9), isTrue);
      expect(
        height.spaceLine!.direction.cross(base.spacePlane!.normal).norm,
        lessThan(1e-9),
      );
      final apex = (c.byId('so')! as GeoPoint).spacePosition!;
      expect(
        foot.spacePosition!.distanceTo(apex),
        closeTo(base.spacePlane!.signedDistance(apex)!.abs(), 1e-9),
      );
    });
  });
}
