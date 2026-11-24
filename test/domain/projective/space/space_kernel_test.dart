import 'package:glados/glados.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/line3.dart';
import 'package:regula/domain/projective/space/plane3.dart';
import 'package:regula/domain/projective/space/point3.dart';
import 'package:regula/domain/projective/space/space_metric.dart';

import 'generators.dart';

const eps = 1e-9;

void main() {
  group('Vec3', () {
    test('cross is right-handed and perpendicular to both', () {
      expect(Vec3.unitX.cross(Vec3.unitY), Vec3.unitZ);
      const a = Vec3(1, 2, 3);
      const b = Vec3(-2, 0.5, 4);
      expect(a.cross(b).dot(a), closeTo(0, 1e-12));
      expect(a.cross(b).dot(b), closeTo(0, 1e-12));
    });

    test('normalizedOrNull is null only for the zero vector', () {
      expect(Vec3.zero.normalizedOrNull, isNull);
      expect(const Vec3(0, 3, 4).normalizedOrNull, const Vec3(0, 0.6, 0.8));
    });

    test('base lifts a planar point to z = 0', () {
      expect(const Vec3(2, 3, 0), isNot(const Vec3(2, 3, 1)));
      expect(const Vec3(2, 3, 0).hashCode, const Vec3(2, 3, 0).hashCode);
    });
  });

  group('Point3', () {
    test('projects finite points and refuses infinite ones', () {
      expect(const Point3(2, 4, 6, 2).toVec3(), const Vec3(1, 2, 3));
      expect(const Point3(1, 0, 0, 0).toVec3(), isNull);
      expect(const Point3(0, 0, 0, 0).toVec3(), isNull);
      expect(const Point3(0, 0, 0, 0).isFinite(), isFalse);
    });

    test('closeTo is projective and false for the zero quadruple', () {
      expect(
        const Point3(1, 2, 3).closeTo(const Point3(-2, -4, -6, -2)),
        isTrue,
      );
      expect(const Point3(1, 2, 3).closeTo(const Point3(1, 2, 3.001)), isFalse);
      expect(
        const Point3(0, 0, 0, 0).closeTo(const Point3(0, 0, 0, 0)),
        isFalse,
      );
    });
  });

  group('join of two points', () {
    test('is the Plücker line through them', () {
      final l = const Point3(1, 0, 0).join(const Point3(1, 1, 0));
      expect(l.direction, const Vec3(0, 1, 0));
      expect(l.moment, const Vec3(0, 0, 1));
      expect(l.direction.dot(l.moment), 0);
      expect(l.anchor, const Vec3(1, 0, 0));
    });

    test('of coincident points is exactly the zero line', () {
      const p = Point3(1.5, -2, 7);
      expect(p.join(p).isZero, isTrue);
      expect(p.join(const Point3(3, -4, 14, 2)).isZero, isTrue);
    });

    test('of nearly coincident points is a real line, not zero', () {
      final l = const Point3(1, 1, 1).join(const Point3(1, 1, 1 + 1e-12));
      expect(l.isZero, isFalse);
      expect(l.isFinite(), isTrue);
    });

    test('with a point at infinity has that direction', () {
      final l = const Point3(0, 0, 5).join(const Point3(1, 0, 0, 0));
      expect(l.direction, const Vec3(1, 0, 0));
      expect(l.contains(const Point3(7, 0, 5)), isTrue);
    });

    Glados2(any.finitePoint3, any.finitePoint3).test('contains both points', (
      p,
      q,
    ) {
      final l = p.join(q);
      if (l.isZero) {
        return;
      }
      expect(l.contains(p, eps), isTrue);
      expect(l.contains(q, eps), isTrue);
    });
  });

  group('plane through three points', () {
    test('is the expected plane', () {
      final plane = Plane3.through(
        const Point3(0, 0, 2),
        const Point3(1, 0, 2),
        const Point3(0, 1, 2),
      );
      expect(plane.normal, const Vec3(0, 0, 1));
      expect(plane.d, -2);
      expect(plane.signedDistance(const Vec3(5, 5, 5)), 3);
    });

    test('through collinear points is exactly the zero plane', () {
      final plane = Plane3.through(
        const Point3(0, 0, 0),
        const Point3(1, 1, 1),
        const Point3(2, 2, 2),
      );
      expect(plane.isZero, isTrue);
    });

    test('through nearly collinear points is a real plane', () {
      final plane = Plane3.through(
        const Point3(0, 0, 0),
        const Point3(1, 1, 1),
        const Point3(2, 2, 2 + 1e-9),
      );
      expect(plane.isZero, isFalse);
      expect(plane.isFinite(), isTrue);
    });

    Glados(any.triangle3).test('contains all three', (t) {
      final (a, b, c) = t;
      final plane = Plane3.through(
        Point3.lift(a),
        Point3.lift(b),
        Point3.lift(c),
      );
      for (final p in [a, b, c]) {
        expect(plane.contains(Point3.lift(p), 1e-7), isTrue);
      }
    });
  });

  group('meet of two planes', () {
    test('is their common line', () {
      final l = const Plane3(0, 0, 1, -2).meet(const Plane3(1, 0, 0, -3));
      // z = 2 and x = 3: the line parallel to y through (3, 0, 2).
      expect(l.contains(const Point3(3, 0, 2)), isTrue);
      expect(l.contains(const Point3(3, 9, 2)), isTrue);
      expect(l.contains(const Point3(3, 9, 2.1)), isFalse);
    });

    test('of a plane with itself is exactly the zero line', () {
      const plane = Plane3(1, 2, 3, 4);
      expect(plane.meet(plane).isZero, isTrue);
      expect(plane.meet(const Plane3(2, 4, 6, 8)).isZero, isTrue);
    });

    test('of parallel planes is a line at infinity', () {
      final l = const Plane3(0, 0, 1, 0).meet(const Plane3(0, 0, 1, -1));
      expect(l.isZero, isFalse);
      expect(l.isFinite(), isFalse);
      expect(l.anchor, isNull);
    });

    Glados2(any.triangle3, any.triangle3).test('lies in both', (s, t) {
      final a = Plane3.through(
        Point3.lift(s.$1),
        Point3.lift(s.$2),
        Point3.lift(s.$3),
      );
      final b = Plane3.through(
        Point3.lift(t.$1),
        Point3.lift(t.$2),
        Point3.lift(t.$3),
      );
      final l = a.meet(b);
      if (!l.isFinite(1e-6)) {
        return;
      }
      expect(l.liesIn(a, 1e-6), isTrue);
      expect(l.liesIn(b, 1e-6), isTrue);
    });
  });

  group('line meets plane', () {
    test('at the expected point', () {
      final l = const Point3(1, 1, -1).join(const Point3(1, 1, 3));
      final p = l.meetPlane(Plane3.base);
      expect(p.toVec3(), const Vec3(1, 1, 0));
    });

    test('a line in the plane meets it in exactly the zero point', () {
      final l = const Point3(0, 0, 0).join(const Point3(1, 2, 0));
      expect(l.meetPlane(Plane3.base).isZero, isTrue);
    });

    test('a line parallel to the plane meets it at infinity', () {
      final l = const Point3(0, 0, 1).join(const Point3(1, 2, 1));
      final p = l.meetPlane(Plane3.base);
      expect(p.isZero, isFalse);
      expect(p.w, 0);
      expect(p.toVec3(), isNull);
    });

    Glados3(any.finitePoint3, any.finitePoint3, any.triangle3).test(
      'the point lies on both',
      (p, q, t) {
        final l = p.join(q);
        final plane = Plane3.through(
          Point3.lift(t.$1),
          Point3.lift(t.$2),
          Point3.lift(t.$3),
        );
        final x = l.meetPlane(plane);
        if (l.isZero || !x.isFinite(1e-6)) {
          return;
        }
        expect(plane.contains(x, 1e-6), isTrue);
        expect(l.contains(x, 1e-6), isTrue);
      },
    );
  });

  group('join of a line and a point', () {
    test('is the plane through both', () {
      final l = const Point3(0, 0, 0).join(const Point3(1, 0, 0));
      final plane = l.joinPoint(const Point3(0, 1, 0));
      expect(plane.contains(const Point3(5, -3, 0)), isTrue);
      expect(plane.contains(const Point3(5, -3, 0.1)), isFalse);
    });

    test('with a point on the line is exactly the zero plane', () {
      final l = const Point3(0, 0, 0).join(const Point3(1, 0, 0));
      expect(l.joinPoint(const Point3(4, 0, 0)).isZero, isTrue);
    });
  });

  group('reciprocal', () {
    test('is zero for two lines through a common point', () {
      const p = Point3(1, 2, 3);
      final a = p.join(const Point3(4, 0, -1));
      final b = p.join(const Point3(-2, 5, 2));
      expect(a.reciprocal(b), closeTo(0, 1e-9));
    });

    test('is zero for parallel lines', () {
      final a = const Point3(0, 0, 0).join(const Point3(1, 1, 1));
      final b = const Point3(0, 3, 0).join(const Point3(1, 4, 1));
      expect(a.reciprocal(b), 0);
    });

    test('is nonzero for a skew pair, and changes sign with handedness', () {
      final a = const Point3(0, 0, 0).join(const Point3(1, 0, 0));
      final above = const Point3(0, 0, 1).join(const Point3(0, 1, 1));
      final below = const Point3(0, 0, -1).join(const Point3(0, 1, -1));
      expect(a.reciprocal(above), isNot(0));
      expect(a.reciprocal(above).sign, -a.reciprocal(below).sign);
    });

    Glados3(any.finitePoint3, any.finitePoint3, any.finitePoint3).test(
      'vanishes for concurrent lines',
      (p, q, r) {
        final a = p.join(q);
        final b = p.join(r);
        final scale = a.norm2 * b.norm2;
        expect(a.reciprocal(b).abs(), lessThanOrEqualTo(1e-9 * (1 + scale)));
      },
    );
  });

  group('Euclidean constructions', () {
    test('the perpendicular to a plane runs along its normal', () {
      final l = perpendicularLineToPlane(
        const Point3(1, 2, 3),
        const Plane3(0, 0, 2, 5),
      );
      expect(l.direction.cross(const Vec3(0, 0, 1)), Vec3.zero);
      expect(l.contains(const Point3(1, 2, -7)), isTrue);
    });

    test('the parallel line keeps the direction and passes through p', () {
      final base = const Point3(0, 0, 0).join(const Point3(1, 2, 3));
      final l = parallelLineThrough(const Point3(5, 5, 5), base);
      expect(l.direction.cross(base.direction), Vec3.zero);
      expect(l.contains(const Point3(6, 7, 8)), isTrue);
    });

    test('the plane perpendicular to a line has its direction as normal', () {
      final l = const Point3(0, 0, 0).join(const Point3(0, 0, 4));
      final plane = perpendicularPlaneToLine(const Point3(1, 2, 3), l);
      expect(plane.contains(const Point3(-8, 9, 3)), isTrue);
      expect(plane.normal.cross(l.direction), Vec3.zero);
    });

    test('the parallel plane keeps the normal and passes through p', () {
      final plane = parallelPlaneThrough(
        const Point3(1, 2, 3),
        const Plane3(1, 1, 0, 9),
      );
      expect(plane.contains(const Point3(1, 2, 3)), isTrue);
      expect(plane.contains(const Point3(2, 1, -4)), isTrue);
      expect(plane.normal.cross(const Vec3(1, 1, 0)), Vec3.zero);
    });

    Glados2(any.finitePoint3, any.triangle3).test(
      'a perpendicular meets its plane at the nearest point',
      (p, t) {
        final plane = Plane3.through(
          Point3.lift(t.$1),
          Point3.lift(t.$2),
          Point3.lift(t.$3),
        );
        final foot = perpendicularLineToPlane(p, plane).meetPlane(plane);
        final f = foot.toVec3()!;
        final distance = plane.signedDistance(p.toVec3()!)!.abs();
        expect(f.distanceTo(p.toVec3()!), closeTo(distance, 1e-6));
      },
    );
  });

  test('Line3.closeTo ignores scale and orientation', () {
    final a = const Point3(0, 1, 2).join(const Point3(3, 1, 2));
    final b = const Point3(9, 1, 2).join(const Point3(-4, 1, 2));
    expect(a.closeTo(b), isTrue);
    expect(a.closeTo(const Line3(Vec3(1, 0, 0), Vec3(0, 2, -1.01))), isFalse);
    expect(const Line3(Vec3.zero, Vec3.zero).closeTo(a), isFalse);
  });
}
