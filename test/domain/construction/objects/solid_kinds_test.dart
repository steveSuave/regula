// Intent 004, milestone 3: the two solids — faces over points of space.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, setUp, test;
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/prism.dart';
import 'package:regula/domain/construction/objects/pyramid.dart';
import 'package:regula/domain/construction/objects/raised_point.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/construction/space_content.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';

import '../../../kitchen_sink.dart';

/// The corners of a regular [n]-gon of radius 3 on the base plane.
List<FreePoint> _ring(int n) => [
  for (var i = 0; i < n; i++)
    FreePoint(
      id: 'v$i',
      position: Vec2(
        3 * math.cos(2 * math.pi * i / n),
        3 * math.sin(2 * math.pi * i / n),
      ),
    ),
];

/// Every edge of [solid] borders exactly two faces, and V − E + F = 2.
void _expectClosedSurface(GeoSolid solid, int vertexCount) {
  final sides = <(int, int), int>{};
  for (final face in solid.faces) {
    for (var k = 0; k < face.length; k++) {
      final i = face[k];
      final j = face[(k + 1) % face.length];
      final key = i < j ? (i, j) : (j, i);
      sides[key] = (sides[key] ?? 0) + 1;
    }
  }
  expect(sides.values.toSet(), {2});
  expect({
    for (final (i, j) in solid.edges) i < j ? (i, j) : (j, i),
  }, sides.keys.toSet());
  expect(solid.edges, hasLength(sides.length));
  expect(vertexCount - solid.edges.length + solid.faces.length, 2);
}

void main() {
  late Construction c;
  late List<FreePoint> square;
  late FreePoint apex;

  setUp(() {
    c = Construction();
    square = [
      FreePoint(id: 'a', position: const Vec2(0, 0)),
      FreePoint(id: 'b', position: const Vec2(4, 0)),
      FreePoint(id: 'c', position: const Vec2(4, 4)),
      FreePoint(id: 'd', position: const Vec2(0, 4)),
    ];
    apex = FreePoint(id: 'o', position: const Vec2(2, 2), height: 3);
    for (final p in [...square, apex]) {
      c.add(p);
    }
  });

  group('Pyramid', () {
    test('has its base and apex as vertices, a face per side and the base', () {
      final p = Pyramid(id: 'p', base: square, apex: apex);
      c.add(p);
      expect(p.spaceVertices, const [
        Vec3(0, 0, 0),
        Vec3(4, 0, 0),
        Vec3(4, 4, 0),
        Vec3(0, 4, 0),
        Vec3(2, 2, 3),
      ]);
      expect(p.faces, [
        [0, 1, 2, 3],
        [0, 1, 4],
        [1, 2, 4],
        [2, 3, 4],
        [3, 0, 4],
      ]);
      expect(p.edges, hasLength(8));
      expect(p.faceVertices(2), const [
        Vec3(4, 0, 0),
        Vec3(4, 4, 0),
        Vec3(2, 2, 3),
      ]);
      expect(p.sheet, Sheet.none);
      expect(p.parents, [...square, apex]);
      expect(p.isDefined, isTrue);
    });

    test('follows its apex and its base', () {
      final p = Pyramid(id: 'p', base: square, apex: apex);
      c
        ..add(p)
        ..setFreePointHeight('o', 7)
        ..moveFreePoint('b', const Vec2(6, -1));
      expect(p.spaceVertices![4], const Vec3(2, 2, 7));
      expect(p.spaceVertices![1], const Vec3(6, -1, 0));
    });

    test('a base of four is undefined while one of its corners is off the '
        'plane, and returns with it', () {
      final p = Pyramid(id: 'p', base: square, apex: apex);
      c
        ..add(p)
        ..setFreePointHeight('c', 0.5);
      expect(p.isDefined, isFalse);
      expect(p.faceVertices(0), isNull);
      c.setFreePointHeight('c', 0);
      expect(p.isDefined, isTrue);
    });

    test('a base of three is a triangle wherever its corners are', () {
      final p = Pyramid(id: 'p', base: square.sublist(0, 3), apex: apex);
      c
        ..add(p)
        ..setFreePointHeight('c', 2);
      expect(p.isDefined, isTrue);
      expect(p.spaceVertices![2], const Vec3(4, 4, 2));
      expect(p.faces, hasLength(4));
      expect(p.edges, hasLength(6));
    });

    test('a base in a plane of the construction is defined by construction, '
        'and not by where a point happens to be', () {
      final wall = ThreePointPlane(
        id: 'w',
        point1: square[0],
        point2: square[1],
        point3: apex,
      );
      final inWall = [
        for (final (i, at) in const [
          Vec2(0, 0),
          Vec2(3, 0),
          Vec2(3, 2),
          Vec2(0, 2),
        ].indexed)
          FreePoint(id: 'w$i', position: at, plane: wall),
      ];
      c.add(wall);
      inWall.forEach(c.add);
      final good = Pyramid(id: 'g', base: inWall, apex: square[2], plane: wall);
      // The base-plane square is not in the wall, though two of its
      // corners are on it.
      final bad = Pyramid(id: 'x', base: square, apex: apex, plane: wall);
      c
        ..add(good)
        ..add(bad);
      expect(good.isDefined, isTrue);
      expect(good.parents.last, same(wall));
      expect(bad.isDefined, isFalse);
    });

    test('needs three base points', () {
      expect(
        () => Pyramid(id: 'p', base: square.sublist(0, 2), apex: apex),
        throwsArgumentError,
      );
    });
  });

  group('Prism', () {
    test('has the base and the base moved to its top as vertices', () {
      final top = RaisedPoint(id: 't', foot: square[0], height: 5);
      final p = Prism(id: 'p', base: square, top: top);
      c
        ..add(top)
        ..add(p);
      expect(p.spaceVertices, const [
        Vec3(0, 0, 0),
        Vec3(4, 0, 0),
        Vec3(4, 4, 0),
        Vec3(0, 4, 0),
        Vec3(0, 0, 5),
        Vec3(4, 0, 5),
        Vec3(4, 4, 5),
        Vec3(0, 4, 5),
      ]);
      expect(p.faces, [
        [0, 1, 2, 3],
        [4, 5, 6, 7],
        [0, 1, 5, 4],
        [1, 2, 6, 5],
        [2, 3, 7, 6],
        [3, 0, 4, 7],
      ]);
      expect(p.edges, hasLength(12));
    });

    test('over a raised point it is right and stays right as its base '
        'moves', () {
      final top = RaisedPoint(id: 't', foot: square[0], height: 5);
      final p = Prism(id: 'p', base: square, top: top);
      c
        ..add(top)
        ..add(p)
        ..moveFreePoint('a', const Vec2(-2, -1));
      final v = p.spaceVertices!;
      for (var i = 0; i < 4; i++) {
        expect(v[4 + i] - v[i], const Vec3(0, 0, 5));
      }
      c.setPointHeight('t', 2);
      expect(p.spaceVertices![6], const Vec3(4, 4, 2));
    });

    test('to any other point it is the oblique prism, and its corners agree '
        'with the translations a tool adds beside it', () {
      final p = Prism(id: 'p', base: square, top: apex);
      final corner = TranslatedPoint(
        id: 'c1',
        point: square[2],
        vectorFrom: square[0],
        vectorTo: apex,
      );
      c
        ..add(p)
        ..add(corner);
      expect(p.spaceVertices![6], const Vec3(6, 6, 3));
      expect(corner.spacePosition, p.spaceVertices![6]);
      c.moveFreePoint('o', const Vec2(-1, 5));
      expect(corner.spacePosition, p.spaceVertices![6]);
    });

    test('a base of four is undefined while a corner is off the plane', () {
      final p = Prism(id: 'p', base: square, top: apex);
      c
        ..add(p)
        ..setFreePointHeight('b', 1);
      expect(p.isDefined, isFalse);
      c.setFreePointHeight('b', 0);
      expect(p.isDefined, isTrue);
    });
  });

  group('a closed surface', () {
    Glados(any.intInRange(3, 12)).test('a pyramid on any base', (n) {
      final ring = _ring(n);
      final solid = Pyramid(id: 'p', base: ring, apex: apex);
      _expectClosedSurface(solid, n + 1);
      expect(solid.spaceVertices, hasLength(n + 1));
    });

    Glados(any.intInRange(3, 12)).test('a prism on any base', (n) {
      final ring = _ring(n);
      final solid = Prism(id: 'p', base: ring, top: apex);
      _expectClosedSurface(solid, 2 * n);
      expect(solid.spaceVertices, hasLength(2 * n));
    });
  });

  test('a solid is space content and round-trips at version 4, with and '
      'without a plane', () {
    expect(hasSpaceContent(buildSolidKinds().objects), isTrue);
    final wall = ThreePointPlane(
      id: 'w',
      point1: square[0],
      point2: square[1],
      point3: apex,
    );
    final inWall = [
      for (final (i, at) in const [
        Vec2(0, 0),
        Vec2(3, 0),
        Vec2(3, 2),
        Vec2(0, 2),
      ].indexed)
        FreePoint(id: 'w$i', position: at, plane: wall),
    ];
    c.add(wall);
    inWall.forEach(c.add);
    c
      ..add(Pyramid(id: 'g', base: inWall, apex: square[2], plane: wall))
      ..add(Prism(id: 'h', base: inWall, top: square[3], plane: wall))
      ..add(Pyramid(id: 'k', base: square, apex: apex));
    const viewport = ViewportState();
    final document = encodeDocument(c, viewport: viewport);
    expect(document['version'], 4);
    final encoded = jsonEncode(document);
    final decoded = decodeDocument(jsonDecode(encoded) as Map<String, dynamic>)
        .construction;
    for (final id in ['g', 'h', 'k']) {
      final before = c.byId(id)! as GeoSolid;
      final after = decoded.byId(id)! as GeoSolid;
      expect(after.runtimeType, before.runtimeType);
      expect(after.spaceVertices, before.spaceVertices, reason: id);
      expect(after.faces, before.faces);
    }
    expect((decoded.byId('g')! as Pyramid).plane!.id, 'w');
    expect((decoded.byId('k')! as Pyramid).plane, isNull);
    expect(jsonEncode(encodeDocument(decoded, viewport: viewport)), encoded);
  });

  test('a solid with too few parents is a format error', () {
    final p = Pyramid(id: 'p', base: square, apex: apex);
    c.add(p);
    final document = encodeDocument(c, viewport: const ViewportState());
    final objects = (document['objects'] as List).cast<Map<String, dynamic>>();
    final solid = objects.firstWhere((o) => o['id'] == 'p');
    solid['parents'] = ['a', 'b', 'c'];
    expect(
      () => decodeDocument(
        jsonDecode(jsonEncode(document)) as Map<String, dynamic>,
      ),
      throwsFormatException,
    );
  });
}
