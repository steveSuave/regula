import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/object_naming.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/vertex_angle.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  final a = FreePoint(id: 'a', position: Vec2(0, 0));
  final b = FreePoint(id: 'b', position: Vec2(1, 0));
  final c = FreePoint(id: 'c', position: Vec2(0, 1));
  final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
  final segment = Segment(id: 's', point1: a, point2: b);
  final circle = CircleCenterPoint(id: 'k', center: a, onCircle: b);
  final angle = VertexAngle(id: 'v', arm1: b, vertex: a, arm2: c);

  group('points', () {
    test('first point is A, scan skips used names', () {
      expect(nextAutoName({}, a), 'A');
      expect(nextAutoName({'A'}, a), 'B');
      expect(nextAutoName({'A', 'B', 'C'}, a), 'D');
    });

    test('gaps are reused first', () {
      expect(nextAutoName({'A', 'C'}, a), 'B');
    });

    test('after Z the suffixed rounds start: A1…Z1, A2…', () {
      final used = <String>{
        for (var i = 0; i < 26; i++) String.fromCharCode(0x41 + i),
      };
      expect(nextAutoName(used, a), 'A1');
      used.add('A1');
      expect(nextAutoName(used, a), 'B1');
      for (var i = 1; i < 26; i++) {
        used.add('${String.fromCharCode(0x41 + i)}1');
      }
      expect(nextAutoName(used, a), 'A2');
    });

    test('manual renames just occupy slots', () {
      expect(nextAutoName({'A', 'midpoint of AB'}, a), 'B');
    });
  });

  group('lines and circles share one lowercase pool', () {
    test('lines draw from a…', () {
      expect(nextAutoName({}, line), 'a');
      expect(nextAutoName({'a'}, segment), 'b');
    });

    test('circles draw from the same pool', () {
      expect(nextAutoName({}, circle), 'a');
      expect(nextAutoName({'a', 'b'}, circle), 'c');
    });

    test('pool is case-sensitive: point names do not block it', () {
      expect(nextAutoName({'A', 'B'}, line), 'a');
    });

    test('overflow past z', () {
      final used = <String>{
        for (var i = 0; i < 26; i++) String.fromCharCode(0x61 + i),
      };
      expect(nextAutoName(used, circle), 'a1');
    });
  });

  group('angles', () {
    test('first angle is α, then β', () {
      expect(nextAutoName({}, angle), 'α');
      expect(nextAutoName({'α'}, angle), 'β');
    });

    test('pool ends at ω (final sigma excluded), then α1', () {
      const greek = 'αβγδεζηθικλμνξοπρστυφχψω';
      expect(greek.length, 24);
      expect(greek.contains('ς'), isFalse);
      final used = {for (final ch in greek.split('')) ch};
      expect(nextAutoName(used, angle), 'α1');
    });
  });
}
