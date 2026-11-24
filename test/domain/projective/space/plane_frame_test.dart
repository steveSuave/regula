import 'package:glados/glados.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/complex.dart';
import 'package:regula/domain/projective/proj_line.dart';
import 'package:regula/domain/projective/proj_point.dart';
import 'package:regula/domain/projective/space/plane_frame.dart';
import 'package:regula/domain/projective/space/point3.dart';

import '../../math/generators.dart';
import 'generators.dart';

void main() {
  group('the base frame', () {
    test('lifts (x, y) to (x, y, 0) and pulls it back, exactly', () {
      expect(PlaneFrame.base.lift(const Vec2(2.5, -1)), const Vec3(2.5, -1, 0));
      expect(PlaneFrame.base.pull(const Vec3(2.5, -1, 7)), const Vec2(2.5, -1));
      expect(PlaneFrame.base.heightOf(const Vec3(2.5, -1, 7)), 7);
      expect(PlaneFrame.base.normal, Vec3.unitZ);
    });

    test('lifts a homogeneous point without rescaling', () {
      final p = PlaneFrame.base.liftPoint(ProjPoint.real(4, 6, 2))!;
      expect(p, const Point3(4, 6, 0, 2));
    });
  });

  group('throughPoints', () {
    test('puts the origin at a and u along ab', () {
      final f = PlaneFrame.throughPoints(
        const Vec3(1, 1, 1),
        const Vec3(1, 4, 1),
        const Vec3(1, 1, 3),
      )!;
      expect(f.origin, const Vec3(1, 1, 1));
      expect(f.u, const Vec3(0, 1, 0));
      expect(f.v, const Vec3(0, 0, 1));
      expect(f.normal, const Vec3(1, 0, 0));
    });

    test('is null exactly for collinear points', () {
      expect(
        PlaneFrame.throughPoints(
          const Vec3(0, 0, 0),
          const Vec3(1, 1, 1),
          const Vec3(2, 2, 2),
        ),
        isNull,
      );
      expect(
        PlaneFrame.throughPoints(
          const Vec3(0, 0, 0),
          const Vec3(1, 1, 1),
          const Vec3(2, 2, 2.000001),
        ),
        isNotNull,
      );
    });

    Glados(any.planeFrame).test('is orthonormal', (f) {
      expect(f.u.norm, closeTo(1, 1e-12));
      expect(f.v.norm, closeTo(1, 1e-12));
      expect(f.u.dot(f.v), closeTo(0, 1e-12));
      expect(f.normal.norm, closeTo(1, 1e-12));
    });
  });

  group('horizontal', () {
    test('an upward horizontal plane takes the base axes', () {
      final f = PlaneFrame.horizontal(
        const Vec3(0, 0, 3),
        const Vec3(0, 0, 2),
      )!;
      expect(f.u, Vec3.unitX);
      expect(f.v, Vec3.unitY);
    });

    test('a vertical plane has u level and v up', () {
      final f = PlaneFrame.horizontal(Vec3.zero, const Vec3(0, -1, 0))!;
      expect(f.u, Vec3.unitX);
      expect(f.v, Vec3.unitZ);
    });

    test('is null for a zero normal', () {
      expect(PlaneFrame.horizontal(Vec3.zero, Vec3.zero), isNull);
    });
  });

  test('withAxis makes the axis perpendicular to the normal', () {
    final f = PlaneFrame.withAxis(
      Vec3.zero,
      const Vec3(0, 0, 1),
      const Vec3(3, 0, 5),
    )!;
    expect(f.u, Vec3.unitX);
    expect(f.v, Vec3.unitY);
    expect(
      PlaneFrame.withAxis(Vec3.zero, const Vec3(0, 0, 1), const Vec3(0, 0, 5)),
      isNull,
    );
  });

  group('lift and pull', () {
    Glados2(any.planeFrame, any.vec2).test('pull undoes lift', (f, p) {
      final back = f.pull(f.lift(p));
      expect(back.distanceTo(p), lessThan(1e-8));
    });

    Glados3(any.planeFrame, any.vec2, any.vec2).test('lift keeps distances', (
      f,
      p,
      q,
    ) {
      expect(f.lift(p).distanceTo(f.lift(q)), closeTo(p.distanceTo(q), 1e-8));
    });

    Glados2(any.planeFrame, any.vec2).test('a lifted height is read back', (
      f,
      p,
    ) {
      final s = f.lift(p, 2.5);
      expect(f.heightOf(s), closeTo(2.5, 1e-8));
      expect(f.pull(s).distanceTo(p), lessThan(1e-8));
    });

    Glados2(any.planeFrame, any.vec2).test(
      'liftPoint lands in the plane and pullPoint returns it',
      (f, p) {
        final s = f.liftPoint(ProjPoint.lift(p))!;
        expect(f.plane.contains(s, 1e-7), isTrue);
        expect(f.pullPoint(s).toVec2()!.distanceTo(p), lessThan(1e-7));
      },
    );
  });

  group('complex values have no image in space', () {
    test('a complex point lifts to null', () {
      const p = ProjPoint(Complex(1, 1), Complex(2), Complex.one);
      expect(PlaneFrame.base.liftPoint(p), isNull);
    });

    test('a real point carrying a global phase still lifts', () {
      const p = ProjPoint(Complex(0, 2), Complex(0, 4), Complex(0, 2));
      final s = PlaneFrame.base.liftPoint(p)!;
      expect(s.toVec3(), const Vec3(1, 2, 0));
    });

    test('a complex line lifts to null', () {
      const l = ProjLine(Complex(1, 1), Complex(2), Complex.one);
      expect(PlaneFrame.base.liftLine(l), isNull);
    });
  });

  group('lines', () {
    test('the base frame lifts y = 2 to the space line y = 2, z = 0', () {
      final l = PlaneFrame.base.liftLine(ProjLine.real(0, 1, -2))!;
      expect(l.contains(const Point3(0, 2, 0)), isTrue);
      expect(l.contains(const Point3(9, 2, 0)), isTrue);
      expect(l.contains(const Point3(9, 2, 1)), isFalse);
    });

    test('pulling a line is its orthogonal projection', () {
      final l = const Point3(0, 2, 5).join(const Point3(9, 2, 7));
      final pulled = PlaneFrame.base.pullLine(l);
      expect(pulled.contains(ProjPoint.real(0, 2)), isTrue);
      expect(pulled.contains(ProjPoint.real(4, 2)), isTrue);
      expect(pulled.contains(ProjPoint.real(4, 2.1)), isFalse);
    });

    test('a line perpendicular to the plane pulls to exactly zero', () {
      final l = const Point3(1, 2, 0).join(const Point3(1, 2, 5));
      expect(PlaneFrame.base.pullLine(l).isZero, isTrue);
    });

    test('the planar line at infinity lifts to a line at infinity', () {
      final l = PlaneFrame.base.liftLine(ProjLine.infinity)!;
      expect(l.isZero, isFalse);
      expect(l.isFinite(), isFalse);
    });

    Glados3(any.planeFrame, any.vec2, any.vec2).test(
      'a lifted line contains its lifted points and pulls back',
      (f, p, q) {
        if (p.distanceTo(q) < 0.5) {
          return;
        }
        final planar = ProjPoint.lift(p).join(ProjPoint.lift(q));
        final l = f.liftLine(planar)!;
        expect(l.contains(Point3.lift(f.lift(p)), 1e-6), isTrue);
        expect(l.contains(Point3.lift(f.lift(q)), 1e-6), isTrue);
        expect(f.pullLine(l).closeTo(planar, 1e-6), isTrue);
      },
    );
  });
}
