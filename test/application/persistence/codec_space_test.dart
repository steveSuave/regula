// Intent 004, milestone 2: what a planar reader would misread is version
// 4, and a document without it is the file it always was.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';

import '../../kitchen_sink.dart';

Construction _pair({double height = 0}) {
  final c = Construction();
  final a = FreePoint(id: 'a', position: const Vec2(1, 2));
  final b = FreePoint(id: 'b', position: const Vec2(5, 2), height: height);
  c
    ..add(a)
    ..add(b)
    ..add(Segment(id: 's', point1: a, point2: b));
  return c;
}

void main() {
  const viewport = ViewportState();

  test('a planar document writes no height and keeps its version', () {
    final document = encodeDocument(_pair(), viewport: viewport);
    expect(document['version'], 1);
    expect(jsonEncode(document), isNot(contains('"h"')));

    final sink = encodeDocument(buildKitchenSink(), viewport: viewport);
    expect(sink['version'], 1);
  });

  test('a lifted point makes the document version 4', () {
    final document = encodeDocument(_pair(height: 2.5), viewport: viewport);
    expect(document['version'], 4);
    expect(constructionFormatVersion, 4);
  });

  test('a lifted document round-trips through JSON', () {
    final encoded = jsonEncode(
      encodeDocument(_pair(height: 2.5), viewport: viewport),
    );
    final decoded = decodeDocument(jsonDecode(encoded) as Map<String, dynamic>);
    final b = decoded.construction.byId('b')! as FreePoint;
    expect(b.height, 2.5);
    expect(b.spacePosition, const Vec3(5, 2, 2.5));
    final s = decoded.construction.byId('s')! as Segment;
    expect(s.hasSpaceExtent, isTrue);
    expect(
      jsonEncode(encodeDocument(decoded.construction, viewport: viewport)),
      encoded,
    );
  });

  test('a height that is not a number is a format error', () {
    final document = encodeDocument(_pair(height: 2.5), viewport: viewport);
    final objects = document['objects'] as List;
    ((objects[1] as Map<String, dynamic>)['params']
            as Map<String, dynamic>)['h'] =
        'high';
    expect(() => decodeDocument(document), throwsFormatException);
  });
}
