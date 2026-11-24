// Intent 004, milestone 2: the saved pyramid. `test/fixtures/` is the
// version 1 corpus and stays that; space documents live in
// `test/space_fixtures/`.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/space_content.dart';

import '../../kitchen_sink.dart';

void main() {
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
