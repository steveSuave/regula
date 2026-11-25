// Intent 004, milestone 3: the loops in which a plane cuts a solid.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/section.dart';

/// The cube [0, a]³: 0–3 the bottom, 4–7 over them.
List<Vec3> _cube(double a) => [
  Vec3(0, 0, 0),
  Vec3(a, 0, 0),
  Vec3(a, a, 0),
  Vec3(0, a, 0),
  Vec3(0, 0, a),
  Vec3(a, 0, a),
  Vec3(a, a, a),
  Vec3(0, a, a),
];

const _cubeFaces = [
  [0, 1, 2, 3],
  [4, 5, 6, 7],
  [0, 1, 5, 4],
  [1, 2, 6, 5],
  [2, 3, 7, 6],
  [3, 0, 4, 7],
];

double _area(List<Vec3> loop) {
  var n = Vec3.zero;
  for (var i = 0; i < loop.length; i++) {
    n += loop[i].cross(loop[(i + 1) % loop.length]);
  }
  return n.norm / 2;
}

/// The plane through three points.
List<List<Vec3>> _cut(List<Vec3> solid, Vec3 a, Vec3 b, Vec3 c) =>
    sectionLoops(solid, _cubeFaces, a, (b - a).cross(c - a));

void main() {
  final cube = _cube(2);

  group('a cube', () {
    test('cut near a corner is a triangle', () {
      final loop = _cut(
        cube,
        const Vec3(1, 0, 0),
        const Vec3(0, 1, 0),
        const Vec3(0, 0, 1),
      ).single;
      expect(loop, hasLength(3));
      // An equilateral triangle of side √2.
      expect(_area(loop), closeTo(math.sqrt(3) / 2, 1e-12));
    });

    test('cut level is a square of its own side', () {
      final loop = sectionLoops(
        cube,
        _cubeFaces,
        const Vec3(0, 0, 0.5),
        Vec3.unitZ,
      ).single;
      expect(loop, hasLength(4));
      expect(_area(loop), closeTo(4, 1e-12));
      for (final p in loop) {
        expect(p.z, 0.5);
      }
    });

    test('cut through a diagonal of each end is a rectangle', () {
      final loop = _cut(
        cube,
        const Vec3(0, 0, 0),
        const Vec3(2, 2, 0),
        const Vec3(0, 0, 2),
      ).single;
      expect(loop, hasLength(4));
      expect(_area(loop), closeTo(2 * 2 * math.sqrt(2), 1e-12));
    });

    test('cut to a pentagon', () {
      // Through the midpoints of two bottom edges at one corner and a
      // point high on the opposite upright edge.
      final loop = _cut(
        cube,
        const Vec3(1, 0, 0),
        const Vec3(0, 1, 0),
        const Vec3(2, 2, 1.5),
      ).single;
      expect(loop, hasLength(5));
    });

    test('cut through its centre across a long diagonal is a regular '
        'hexagon', () {
      final loop = sectionLoops(
        cube,
        _cubeFaces,
        const Vec3(1, 1, 1),
        const Vec3(1, 1, 1),
      ).single;
      expect(loop, hasLength(6));
      // Side a/√2 with a = 2: area (3√3/2)·s².
      expect(_area(loop), closeTo(3 * math.sqrt(3), 1e-12));
      final sides = [
        for (var i = 0; i < 6; i++) loop[i].distanceTo(loop[(i + 1) % 6]),
      ];
      for (final side in sides) {
        expect(side, closeTo(math.sqrt(2), 1e-12));
      }
    });

    test('the loop turns counter-clockwise seen from the normal\'s side, '
        'whichever way the normal points', () {
      for (final normal in [Vec3.unitZ, -Vec3.unitZ]) {
        final loop = sectionLoops(
          cube,
          _cubeFaces,
          const Vec3(0, 0, 1),
          normal,
        ).single;
        var n = Vec3.zero;
        for (var i = 0; i < loop.length; i++) {
          n += loop[i].cross(loop[(i + 1) % loop.length]);
        }
        expect(n.dot(normal), greaterThan(0));
      }
    });
  });

  group('a plane through the solid\'s own corners, exactly', () {
    test('through one corner and across the cube: that corner once', () {
      // Through the corner (0,0,0) and the midpoints of two far edges.
      final loop = _cut(
        cube,
        const Vec3(0, 0, 0),
        const Vec3(2, 1, 2),
        const Vec3(1, 2, 2),
      ).single;
      expect(loop.where((p) => p == const Vec3(0, 0, 0)), hasLength(1));
      expect(loop.toSet(), hasLength(loop.length));
    });

    test('through four corners: exactly those four', () {
      final loop = _cut(
        cube,
        const Vec3(0, 0, 0),
        const Vec3(2, 0, 0),
        const Vec3(2, 2, 2),
      ).single;
      expect(loop.toSet(), {
        const Vec3(0, 0, 0),
        const Vec3(2, 0, 0),
        const Vec3(2, 2, 2),
        const Vec3(0, 2, 2),
      });
    });

    test('containing a face gives that face, from either side', () {
      for (final (origin, normal, z) in [
        (const Vec3(0, 0, 2), Vec3.unitZ, 2.0),
        (const Vec3(0, 0, 2), -Vec3.unitZ, 2.0),
        (const Vec3(0, 0, 0), Vec3.unitZ, 0.0),
        (const Vec3(0, 0, 0), -Vec3.unitZ, 0.0),
      ]) {
        final loop = sectionLoops(cube, _cubeFaces, origin, normal).single;
        expect(loop, hasLength(4));
        expect(loop.every((p) => p.z == z), isTrue);
        expect(_area(loop), closeTo(4, 1e-12));
      }
    });

    test('touching at one corner, or along one edge, is no section', () {
      // The plane x + y + z = 0 touches at the origin.
      for (final normal in [const Vec3(1, 1, 1), const Vec3(-1, -1, -1)]) {
        expect(sectionLoops(cube, _cubeFaces, Vec3.zero, normal), isEmpty);
      }
      // The plane x + y = 0 holds the upright edge at the origin.
      for (final normal in [const Vec3(1, 1, 0), const Vec3(-1, -1, 0)]) {
        expect(sectionLoops(cube, _cubeFaces, Vec3.zero, normal), isEmpty);
      }
    });

    test('a plane that misses is no section', () {
      expect(
        sectionLoops(cube, _cubeFaces, const Vec3(0, 0, 5), Vec3.unitZ),
        isEmpty,
      );
      expect(
        sectionLoops(cube, _cubeFaces, const Vec3(0, 0, -1), Vec3.unitZ),
        isEmpty,
      );
    });
  });

  test('a prism on an L-shaped base, cut across both arms, gives two '
      'loops', () {
    // The L: a 3×3 square with its top-right 2×2 removed, 0 ≤ z ≤ 1.
    const outline = [
      (0.0, 0.0),
      (3.0, 0.0),
      (3.0, 1.0),
      (1.0, 1.0),
      (1.0, 3.0),
      (0.0, 3.0),
    ];
    final vertices = [
      for (final (x, y) in outline) Vec3(x, y, 0),
      for (final (x, y) in outline) Vec3(x, y, 1),
    ];
    final faces = [
      [0, 1, 2, 3, 4, 5],
      [6, 7, 8, 9, 10, 11],
      for (var i = 0; i < 6; i++) [i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i],
    ];
    // The plane x + y = 3.5 crosses the end of each arm.
    final loops = sectionLoops(
      vertices,
      faces,
      const Vec3(3.5, 0, 0),
      const Vec3(1, 1, 0),
    );
    expect(loops, hasLength(2));
    for (final loop in loops) {
      expect(loop, hasLength(4));
      expect(_area(loop), closeTo(0.5 * math.sqrt(2), 1e-12));
    }
    // And level, it is the L itself: one loop of six.
    final level = sectionLoops(
      vertices,
      faces,
      const Vec3(0, 0, 0.5),
      Vec3.unitZ,
    ).single;
    expect(level, hasLength(6));
    expect(_area(level), closeTo(5, 1e-12));
  });

  group('any plane through any cube', () {
    Glados3(
      any.doubleInRange(-1, 1),
      any.doubleInRange(-1, 1),
      any.doubleInRange(0.05, 1.95),
    ).test('gives one convex loop whose corners are on the plane and on '
        'the cube\'s edges', (nx, ny, at) {
      final normal = Vec3(nx, ny, 1);
      final origin = Vec3(1, 1, at);
      final loops = sectionLoops(cube, _cubeFaces, origin, normal);
      // The plane passes through an interior point: there is a section.
      final loop = loops.single;
      expect(loop.length, inInclusiveRange(3, 6));
      final scale = normal.norm;
      for (final p in loop) {
        expect((p - origin).dot(normal).abs() / scale, lessThan(1e-12));
        // On an edge: two of its coordinates are 0 or 2.
        final onFaces = [
          p.x,
          p.y,
          p.z,
        ].where((v) => v.abs() < 1e-12 || (v - 2).abs() < 1e-12).length;
        expect(onFaces, greaterThanOrEqualTo(2));
      }
      // Convex: every turn is the same way about the normal.
      for (var i = 0; i < loop.length; i++) {
        final a = loop[i];
        final b = loop[(i + 1) % loop.length];
        final c = loop[(i + 2) % loop.length];
        expect((b - a).cross(c - b).dot(normal), greaterThan(-1e-9));
      }
    });
  });
}
