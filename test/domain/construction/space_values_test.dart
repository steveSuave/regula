// Intent 004, milestone 2, stage A: every point and line has a value in
// space, a free point can be lifted off its sheet, and the kinds that
// need no plane follow it there.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/compass_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/parallel_line.dart';
import 'package:regula/domain/construction/objects/ray.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/point3.dart';

import '../../kitchen_sink.dart';

void main() {
  group('planar objects in space', () {
    for (final (name, build) in [
      ('kitchen sink', buildKitchenSink),
      ('post-v1 kinds', buildPostV1Kinds),
    ]) {
      test('$name: every point sits at its position with z = 0', () {
        for (final object in build().objects.whereType<GeoPoint>()) {
          final position = object.position;
          if (position == null) {
            expect(object.spacePosition, isNull, reason: object.id);
            continue;
          }
          expect(
            object.spacePosition,
            Vec3(position.x, position.y, 0),
            reason: object.id,
          );
          expect(
            object.spacePoint!.toVec3()!.distanceTo(Vec3.base(position)),
            lessThan(1e-9),
            reason: object.id,
          );
        }
      });

      test('$name: every line lifts to a line through its own points', () {
        for (final object in build().objects.whereType<GeoLine>()) {
          final line = object.line;
          if (line == null) {
            continue;
          }
          final space = object.spaceLine!;
          final on = line.pointOnLine;
          final along = on + line.direction * 3;
          expect(space.contains(Point3(on.x, on.y, 0)), isTrue);
          expect(space.contains(Point3(along.x, along.y, 0)), isTrue);
          expect(space.contains(Point3(on.x, on.y, 1)), isFalse);
          expect(object.hasSpaceExtent, isFalse, reason: object.id);
        }
      });
    }
  });

  group('a lifted free point', () {
    test('has no value in its sheet and a position in space', () {
      final p = FreePoint(id: 'p', position: const Vec2(2, 3), height: 4);
      expect(p.isLifted, isTrue);
      expect(p.projPoint, isNull);
      expect(p.position, isNull);
      expect(p.chartPosition, const Vec2(2, 3));
      expect(p.spacePosition, const Vec3(2, 3, 4));
      expect(p.spacePoint!.toVec3(), const Vec3(2, 3, 4));
      expect(p.isDefined, isTrue);
    });

    test('at height exactly 0 is the planar point', () {
      final p = FreePoint(id: 'p', position: const Vec2(2, 3));
      expect(p.isLifted, isFalse);
      expect(p.position, const Vec2(2, 3));
      expect(p.projPoint, isNotNull);
      expect(p.spacePosition, const Vec3(2, 3, 0));
    });

    test('only an exactly zero height is in the sheet', () {
      final p = FreePoint(id: 'p', position: Vec2.zero, height: 1e-300);
      expect(p.position, isNull);
      expect(p.spacePosition, const Vec3(0, 0, 1e-300));
    });
  });

  group('Construction.setFreePointHeight', () {
    test('recomputes dependents and notifies once', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m);
      var notified = 0;
      c.addListener(() => notified++);

      c.setFreePointHeight('a', 6);

      expect(notified, 1);
      expect(m.position, isNull);
      expect(m.spacePosition, const Vec3(2, 0, 3));
    });

    test('refuses a derived point and a non-finite height', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b)
        ..add(Midpoint(id: 'm', point1: a, point2: b));
      expect(() => c.setFreePointHeight('m', 1), throwsArgumentError);
      expect(() => c.setFreePointHeight('a', double.nan), throwsArgumentError);
    });
  });

  group('kinds that need no plane follow a lifted point', () {
    late Construction c;
    late FreePoint a;
    late FreePoint b;

    setUp(() {
      c = Construction();
      a = FreePoint(id: 'a', position: Vec2.zero);
      b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b);
    });

    test('a segment keeps its ends and loses its planar carrier', () {
      final s = Segment(id: 's', point1: a, point2: b);
      c.add(s);
      final planar = s.projLine;
      expect(s.hasSpaceExtent, isFalse);

      c.setFreePointHeight('b', 3);

      expect(s.projLine, isNull);
      expect(s.line, isNull);
      expect(s.isDefined, isTrue);
      expect(s.hasSpaceExtent, isTrue);
      expect(s.spaceStart, Vec3.zero);
      expect(s.spaceEnd, const Vec3(4, 0, 3));
      expect(s.spaceLine!.contains(const Point3(2, 0, 1.5)), isTrue);
      expect(s.parameterExtent, isNull);

      c.setFreePointHeight('b', 0);

      expect(s.projLine, planar);
      expect(s.hasSpaceExtent, isFalse);
    });

    test('a line through two points is their join in space', () {
      final l = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      c
        ..add(l)
        ..setFreePointHeight('a', 2);
      expect(l.line, isNull);
      expect(l.isDefined, isTrue);
      expect(l.spaceLine!.contains(const Point3(8, 0, -2)), isTrue);
    });

    test('a ray keeps its origin and direction', () {
      final r = Ray(id: 'r', origin: a, through: b);
      c
        ..add(r)
        ..setFreePointHeight('b', 4);
      expect(r.isDefined, isTrue);
      expect(r.spaceStart, Vec3.zero);
      expect(r.spaceThrough, const Vec3(4, 0, 4));
      expect(r.parameterExtent, isNull);
    });

    test('a midpoint of two lifted points is between them', () {
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(m)
        ..setFreePointHeight('a', 2)
        ..setFreePointHeight('b', 6);
      expect(m.projPoint, isNull);
      expect(m.spacePosition, const Vec3(2, 0, 4));
      expect(m.isDefined, isTrue);
    });

    test('a parallel through a lifted point keeps the direction', () {
      final base = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 5));
      final parallel = ParallelLine(id: 'q', through: p, reference: base);
      c
        ..add(base)
        ..add(p)
        ..add(parallel)
        ..setFreePointHeight('p', 2);
      expect(parallel.line, isNull);
      expect(parallel.isDefined, isTrue);
      final space = parallel.spaceLine!;
      expect(space.contains(const Point3(1, 5, 2)), isTrue);
      expect(space.contains(const Point3(9, 5, 2)), isTrue);
    });

    test('coincident planar points stay undefined: a planar degeneracy is '
        'not a space value', () {
      final twin = FreePoint(id: 't', position: Vec2.zero);
      final s = Segment(id: 's', point1: a, point2: twin);
      final l = LineThroughTwoPoints(id: 'l', point1: a, point2: twin);
      c
        ..add(twin)
        ..add(s)
        ..add(l);
      expect(s.isDefined, isFalse);
      expect(l.isDefined, isFalse);
    });

    test('a segment between coincident lifted points is undefined', () {
      final twin = FreePoint(id: 't', position: Vec2.zero, height: 1);
      final s = Segment(id: 's', point1: a, point2: twin);
      c
        ..add(twin)
        ..add(s)
        ..setFreePointHeight('a', 1);
      expect(s.isDefined, isFalse);
    });
  });

  test('a construction that needs the plane is undefined while its point is '
      'lifted, and returns with it', () {
    final c = Construction();
    final a = FreePoint(id: 'a', position: Vec2.zero);
    final b = FreePoint(id: 'b', position: const Vec2(4, 0));
    final circle = CompassCircle(
      id: 'k',
      radiusPoint1: a,
      radiusPoint2: b,
      center: a,
    );
    c
      ..add(a)
      ..add(b)
      ..add(circle);
    final before = circle.circle!;

    c.setFreePointHeight('a', 0.001);
    expect(circle.isDefined, isFalse);
    expect(circle.conic, isNull);

    c.setFreePointHeight('a', 0);
    expect(circle.circle!.center, before.center);
    expect(circle.circle!.radius, before.radius);
  });
}
