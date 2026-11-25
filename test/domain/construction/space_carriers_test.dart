// Intent 004, milestone 3, stage A: what solids rest on. A polygon and a
// translation follow their points into space, and a point can be glued
// to a line that has no value in any sheet.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/area_measurement.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/perpendicular_to_plane_line.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/polygon.dart';
import 'package:regula/domain/construction/objects/ray.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';

void main() {
  late Construction c;
  late FreePoint a;
  late FreePoint b;
  late FreePoint d;

  setUp(() {
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    b = FreePoint(id: 'b', position: const Vec2(4, 0));
    d = FreePoint(id: 'd', position: const Vec2(0, 3));
    c
      ..add(a)
      ..add(b)
      ..add(d);
  });

  group('a polygon over points of space', () {
    test('on one sheet it is the planar polygon, and its lift', () {
      final p = Polygon(id: 'p', vertices: [a, b, d]);
      c.add(p);
      expect(p.polygonVertices, const [Vec2(0, 0), Vec2(4, 0), Vec2(0, 3)]);
      expect(p.spaceVertices, const [
        Vec3(0, 0, 0),
        Vec3(4, 0, 0),
        Vec3(0, 3, 0),
      ]);
    });

    test('with a vertex lifted it has a space loop and no planar one', () {
      final p = Polygon(id: 'p', vertices: [a, b, d]);
      c
        ..add(p)
        ..setFreePointHeight('d', 5);
      expect(p.polygonVertices, isNull);
      expect(p.spaceVertices, const [
        Vec3(0, 0, 0),
        Vec3(4, 0, 0),
        Vec3(0, 3, 5),
      ]);
      expect(p.isDefined, isTrue);

      c.setFreePointHeight('d', 0);
      expect(p.polygonVertices, const [Vec2(0, 0), Vec2(4, 0), Vec2(0, 3)]);
    });

    test('its area is not read while it has no plane, and returns', () {
      final p = Polygon(id: 'p', vertices: [a, b, d]);
      final area = AreaMeasurement(id: 'm', subject: p);
      c
        ..add(p)
        ..add(area);
      expect(area.value, 6);
      c.setFreePointHeight('d', 5);
      expect(area.isDefined, isFalse);
      c.setFreePointHeight('d', 0);
      expect(area.value, 6);
    });

    test('vertices in two planes give a space loop', () {
      final floor = ThreePointPlane(id: 'w', point1: a, point2: b, point3: d);
      final f = FreePoint(id: 'f', position: const Vec2(1, 1), plane: floor);
      final p = Polygon(id: 'p', vertices: [a, b, f]);
      c
        ..add(floor)
        ..add(f)
        ..add(p);
      expect(p.polygonVertices, isNull);
      expect(
        p.spaceVertices![2].distanceTo(const Vec3(1, 1, 0)),
        lessThan(1e-12),
      );
    });
  });

  group('a translation in space', () {
    test('on one sheet it is the planar image, to the bit', () {
      final t = TranslatedPoint(id: 't', point: d, vectorFrom: a, vectorTo: b);
      c.add(t);
      expect(t.position, const Vec2(4, 3));
      expect(t.spacePosition, const Vec3(4, 3, 0));
    });

    test('by a vector to a lifted point it is the image in space', () {
      final t = TranslatedPoint(id: 't', point: d, vectorFrom: a, vectorTo: b);
      c
        ..add(t)
        ..setFreePointHeight('b', 2);
      expect(t.position, isNull);
      expect(t.spacePosition, const Vec3(4, 3, 2));
      expect(t.spacePoint!.toVec3(), const Vec3(4, 3, 2));
      expect(t.isDefined, isTrue);

      c.setFreePointHeight('b', 0);
      expect(t.position, const Vec2(4, 3));
    });
  });

  group('a point glued to a line of space', () {
    test('on a planar segment nothing changed', () {
      final s = Segment(id: 's', point1: a, point2: b);
      final g = PointOnObject(id: 'g', curve: s, parameter: 1);
      c
        ..add(s)
        ..add(g);
      expect(g.onSpaceLine, isFalse);
      expect(g.position, const Vec2(1, 0));
      expect(g.spacePosition, const Vec3(1, 0, 0));
      // The space frame is the planar parameterization, lifted.
      expect(s.spaceParameterOf(const Vec3(1, 0, 0)), 1);
    });

    test('it stays where it was when an end of its host leaves the plane by '
        'a hair, on the base sheet', () {
      for (final build in <Segment Function()>[
        () => Segment(id: 's', point1: a, point2: b),
        () => Segment(id: 's', point1: b, point2: a),
      ]) {
        c = Construction();
        a = FreePoint(id: 'a', position: const Vec2(1, 2));
        b = FreePoint(id: 'b', position: const Vec2(5, 4));
        final s = build();
        c
          ..add(a)
          ..add(b)
          ..add(s);
        final t = s.line!.parameterAt(const Vec2(3, 3));
        final g = PointOnObject(id: 'g', curve: s, parameter: t);
        c.add(g);
        final before = g.spacePosition!;
        c.setFreePointHeight('b', 1e-6);
        expect(g.onSpaceLine, isTrue);
        expect(g.position, isNull);
        expect(g.spacePosition!.distanceTo(before), lessThan(1e-5));
      }
    });

    test('and on a tilted plane\'s sheet', () {
      c.setFreePointHeight('d', 3);
      final wall = ThreePointPlane(id: 'w', point1: a, point2: b, point3: d);
      final f = FreePoint(id: 'f', position: const Vec2(1, 1), plane: wall);
      final h = FreePoint(id: 'h', position: const Vec2(3, 2), plane: wall);
      final s = Segment(id: 's', point1: f, point2: h);
      c
        ..add(wall)
        ..add(f)
        ..add(h)
        ..add(s);
      final g = PointOnObject(
        id: 'g',
        curve: s,
        parameter: s.line!.parameterAt(const Vec2(2, 1.5)),
      );
      c.add(g);
      final before = g.spacePosition!;
      c.setFreePointHeight('h', 1e-6);
      expect(g.onSpaceLine, isTrue);
      expect(g.spacePosition!.distanceTo(before), lessThan(1e-5));
    });

    test('for a line and a ray through two points as well', () {
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final ray = Ray(id: 'r', origin: b, through: d);
      c
        ..add(line)
        ..add(ray);
      final onLine = PointOnObject(
        id: 'g1',
        curve: line,
        parameter: line.line!.parameterAt(const Vec2(7, 0)),
      );
      final onRay = PointOnObject(
        id: 'g2',
        curve: ray,
        parameter: ray.line!.parameterAt(const Vec2(2, 1.5)),
      );
      c
        ..add(onLine)
        ..add(onRay);
      final before = (onLine.spacePosition!, onRay.spacePosition!);
      c.setFreePointHeight('b', 1e-6);
      expect(onLine.spacePosition!.distanceTo(before.$1), lessThan(1e-5));
      expect(onRay.spacePosition!.distanceTo(before.$2), lessThan(1e-5));
    });

    test('it is clamped to a segment\'s ends and a ray\'s origin', () {
      final s = Segment(id: 's', point1: a, point2: b);
      final r = Ray(id: 'r', origin: a, through: b);
      c
        ..add(s)
        ..add(r)
        ..setFreePointHeight('b', 3);
      final beyond = PointOnObject(id: 'g1', curve: s, parameter: 100);
      final before = PointOnObject(id: 'g2', curve: s, parameter: -100);
      final behind = PointOnObject(id: 'g3', curve: r, parameter: -100);
      final ahead = PointOnObject(id: 'g4', curve: r, parameter: 10);
      expect(
        beyond.spacePosition!.distanceTo(const Vec3(4, 0, 3)),
        lessThan(1e-12),
      );
      expect(before.spacePosition!.distanceTo(Vec3.zero), lessThan(1e-12));
      expect(behind.spacePosition!.distanceTo(Vec3.zero), lessThan(1e-12));
      expect(
        ahead.spacePosition!.distanceTo(const Vec3(8, 0, 6)),
        lessThan(1e-12),
      );
    });

    test('it keeps its arc length as the host moves', () {
      final s = Segment(id: 's', point1: a, point2: b);
      c
        ..add(s)
        ..setFreePointHeight('b', 3);
      final g = PointOnObject.onSpaceLine(
        id: 'g',
        curve: s,
        parameter: s.spaceParameterOf(const Vec3(2, 0, 1.5))!,
      );
      c.add(g);
      expect(
        g.spacePosition!.distanceTo(const Vec3(2, 0, 1.5)),
        lessThan(1e-12),
      );
      c.setFreePointHeight('b', 6);
      expect(g.spacePosition!.distanceTo(Vec3.zero), closeTo(2.5, 1e-12));
    });

    test('on a perpendicular to a plane the parameter is the height', () {
      final floor = ThreePointPlane(id: 'w', point1: a, point2: b, point3: d);
      final up = PerpendicularToPlaneLine(id: 'n', through: b, plane: floor);
      final g = PointOnObject(id: 'g', curve: up, parameter: 2.5);
      c
        ..add(floor)
        ..add(up)
        ..add(g);
      expect(g.onSpaceLine, isTrue);
      expect(
        g.spacePosition!.distanceTo(const Vec3(4, 0, 2.5)),
        lessThan(1e-12),
      );
      c.moveFreePoint('b', const Vec2(6, 1));
      expect(
        g.spacePosition!.distanceTo(const Vec3(6, 1, 2.5)),
        lessThan(1e-12),
      );
    });

    test('setting its parameter moves it, through the construction', () {
      final s = Segment(id: 's', point1: a, point2: b);
      c
        ..add(s)
        ..setFreePointHeight('b', 3);
      final g = PointOnObject(id: 'g', curve: s, parameter: 0);
      c
        ..add(g)
        ..setPointOnObjectParameter('g', 5);
      expect(g.spacePosition!.distanceTo(const Vec3(4, 0, 3)), lessThan(1e-12));
    });
  });
}
