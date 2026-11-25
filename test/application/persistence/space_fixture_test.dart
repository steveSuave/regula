// Intent 004, milestone 2: the saved pyramid. `test/fixtures/` is the
// version 1 corpus and stays that; space documents live in
// `test/space_fixtures/`.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/area_measurement.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/section_polygon.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/space_content.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/drag_session.dart';

import '../../kitchen_sink.dart';

void main() {
  cubeSectionFixture();

  final file = File('test/space_fixtures/pyramid_skeleton.rgl');
  Map<String, dynamic> read() =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  test('is a version 4 document, and the encoder says so again', () {
    final json = read();
    expect(json['version'], 4);
    final decoded = decodeDocument(json);
    final again = encodeDocument(
      decoded.construction,
      viewport: decoded.viewport,
      settings: decoded.settings,
    );
    expect(again['version'], 4);
    expect(jsonEncode(again), jsonEncode(json));
  });

  test('loads with every object wired and defined', () {
    final construction = decodeDocument(read()).construction;
    expect(construction.objects, hasLength(14));
    expect(hasSpaceContent(construction.objects), isTrue);
    for (final object in construction.objects) {
      expect(object.isDefined, isTrue, reason: object.id);
    }
    final reloaded = decodeDocument(
      jsonDecode(jsonEncode(read())) as Map<String, dynamic>,
    ).construction;
    for (final object in construction.objects) {
      expect(
        geometryOf(reloaded.byId(object.id)!),
        geometryOf(object),
        reason: object.id,
      );
    }
  });

  test('is the pyramid it says: a square base, equilateral faces', () {
    final construction = decodeDocument(read()).construction;
    final apex = construction.byId('o')! as FreePoint;
    expect(apex.height, closeTo(200 / math.sqrt2, 1e-12));
    for (final edge in construction.objects.whereType<Segment>()) {
      expect(
        edge.point1.spacePosition!.distanceTo(edge.point2.spacePosition!),
        closeTo(200, 1e-9),
        reason: edge.id,
      );
    }
    final face = construction.byId('oab')! as GeoPlane;
    for (final id in ['o', 'a', 'b']) {
      final vertex = construction.byId(id)! as GeoPoint;
      expect(face.spacePlane!.contains(vertex.spacePoint!, 1e-9), isTrue);
    }
    // The base-to-face dihedral, read off the normals: arctan √2.
    final cosine = face.frame!.normal.z.abs();
    expect(math.acos(cosine), closeTo(math.atan(math.sqrt2), 1e-12));
  });
}

/// Intent 004, milestone 3: the intent's second acceptance fixture — "a
/// cube cut by a plane through three points on its edges: the section
/// polygon, its side count and its area" — and a second cut of the same
/// cube whose section is a regular hexagon.
void cubeSectionFixture() {
  final file = File('test/space_fixtures/cube_section.rgl');
  Map<String, dynamic> read() =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  /// The area of the triangle that cuts legs p, q, r off a corner where
  /// three edges meet at right angles.
  double cornerTriangle(double p, double q, double r) =>
      0.5 * math.sqrt(p * p * q * q + q * q * r * r + r * r * p * p);

  group('cube_section.rgl', () {
    test('is a version 4 document, and the encoder says so again', () {
      final json = read();
      expect(json['version'], 4);
      final decoded = decodeDocument(json);
      final again = encodeDocument(
        decoded.construction,
        viewport: decoded.viewport,
        settings: decoded.settings,
      );
      expect(jsonEncode(again), jsonEncode(json));
      for (final object in decoded.construction.objects) {
        expect(object.isDefined, isTrue, reason: object.id);
      }
    });

    test('the plane through three points on three edges at a corner cuts a '
        'triangle of the area the legs give', () {
      final c = decodeDocument(read()).construction;
      final section = c.byId('corner')! as SectionPolygon;
      expect(section.sideCount, 3);
      // AP = 150 on AB, AQ = 100 on AD, AR = 120 on AE.
      for (final (id, at) in [
        ('p', const Vec3(150, 0, 0)),
        ('q', const Vec3(0, 100, 0)),
        ('r', const Vec3(0, 0, 120)),
      ]) {
        expect(
          (c.byId(id)! as GeoPoint).spacePosition!.distanceTo(at),
          lessThan(1e-9),
          reason: id,
        );
      }
      expect(
        (c.byId('cornerArea')! as AreaMeasurement).value,
        closeTo(cornerTriangle(150, 100, 120), 1e-9),
      );
    });

    test('the plane through three edge midpoints cuts a regular hexagon', () {
      final c = decodeDocument(read()).construction;
      final section = c.byId('hexagon')! as SectionPolygon;
      expect(section.sideCount, 6);
      final loop = section.spaceVertices!;
      for (var i = 0; i < 6; i++) {
        expect(
          loop[i].distanceTo(loop[(i + 1) % 6]),
          closeTo(200 / math.sqrt2, 1e-9),
        );
      }
      expect(
        (c.byId('hexagonArea')! as AreaMeasurement).value,
        closeTo(3 * math.sqrt(3) / 4 * 200 * 200, 1e-9),
      );
    });

    test('both hold through a session-level drag of a base corner', () {
      final c = decodeDocument(read()).construction;
      final b = c.byId('b')! as FreePoint;
      final session = DragSession.start(c, b, b.position!)!
        ..update(const Vec2(220, 60))
        ..update(const Vec2(240, 180));
      session.end()!.apply(c);
      // The cube is now of side 300, turned about A.
      final cube = c.byId('cube')! as GeoSolid;
      final v = cube.spaceVertices!;
      for (final (i, j) in cube.edges) {
        expect(v[i].distanceTo(v[j]), closeTo(300, 1e-9));
      }
      // The glued points keep their distances from A, which is at the
      // origin of every line through it: the same triangle.
      final corner = c.byId('corner')! as SectionPolygon;
      expect(corner.sideCount, 3);
      expect(
        (c.byId('cornerArea')! as AreaMeasurement).value,
        closeTo(cornerTriangle(150, 100, 120), 1e-9),
      );
      // The midpoints are still midpoints: a regular hexagon of the new
      // cube.
      final hexagon = c.byId('hexagon')! as SectionPolygon;
      expect(hexagon.sideCount, 6);
      expect(
        (c.byId('hexagonArea')! as AreaMeasurement).value,
        closeTo(3 * math.sqrt(3) / 4 * 300 * 300, 1e-8),
      );
    });

    test('lifting a base corner takes the cube and both sections away, and '
        'they return with it', () {
      final c = decodeDocument(read()).construction;
      c.setFreePointHeight('b', 10);
      expect(c.byId('cube')!.isDefined, isFalse);
      expect(c.byId('corner')!.isDefined, isFalse);
      expect(c.byId('hexagon')!.isDefined, isFalse);
      c.setFreePointHeight('b', 0);
      expect((c.byId('corner')! as SectionPolygon).sideCount, 3);
      expect((c.byId('hexagon')! as SectionPolygon).sideCount, 6);
    });
  });
}
