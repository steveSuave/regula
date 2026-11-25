// Intent 004, milestone 3: points that stand over another point — at a
// stored height the lift handle sets, or at a multiple of a length.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/set_point_height_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/proportional_raised_point.dart';
import 'package:regula/domain/construction/objects/raised_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/space_content.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/lift_session.dart';

void main() {
  late Construction c;
  late FreePoint a;
  late FreePoint b;
  late FreePoint apex;
  late ThreePointPlane wall;

  setUp(() {
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    b = FreePoint(id: 'b', position: const Vec2(4, 0));
    apex = FreePoint(id: 'o', position: const Vec2(0, 0), height: 3);
    // The vertical plane y = 0, its normal along -y.
    wall = ThreePointPlane(id: 'w', point1: a, point2: b, point3: apex);
    c
      ..add(a)
      ..add(b)
      ..add(apex)
      ..add(wall);
  });

  group('RaisedPoint', () {
    test('stands over its foot on the base plane, and follows it', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 2.5);
      c.add(r);
      expect(r.spacePosition, const Vec3(4, 0, 2.5));
      expect(r.position, isNull);
      expect(r.projPoint, isNull);
      expect(r.sheet, Sheet.none);
      expect(r.isDefined, isTrue);
      expect(r.parents, [b]);
      c.moveFreePoint('b', const Vec2(7, 1));
      expect(r.spacePosition, const Vec3(7, 1, 2.5));
    });

    test('over a tilted plane it goes along that plane\'s normal', () {
      final r = RaisedPoint(id: 'r', foot: b, plane: wall, height: 2);
      c.add(r);
      final normal = wall.frame!.normal;
      expect(normal.z.abs(), lessThan(1e-12));
      expect(
        r.spacePosition!.distanceTo(const Vec3(4, 0, 0) + normal * 2),
        lessThan(1e-12),
      );
      expect(r.parents, [b, wall]);
      expect(wall.frame!.heightOf(r.spacePosition!), closeTo(2, 1e-12));
    });

    test('its foot may be any point of space', () {
      final r = RaisedPoint(id: 'r', foot: apex, height: -1);
      c.add(r);
      expect(r.spacePosition, const Vec3(0, 0, 2));
    });

    test('at height 0 it is at its foot and still a point of space', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 0);
      expect(r.spacePosition, const Vec3(4, 0, 0));
      expect(r.position, isNull);
    });

    test('it is undefined while its foot or its plane is', () {
      final r = RaisedPoint(id: 'r', foot: b, plane: wall, height: 2);
      c
        ..add(r)
        // The three points of the wall become collinear: no plane.
        ..setFreePointHeight('o', 0);
      expect(r.isDefined, isFalse);
      c.setFreePointHeight('o', 3);
      expect(r.isDefined, isTrue);
    });

    test('setPointHeight moves it and what is built on it, once', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 2);
      final m = Midpoint(id: 'm', point1: a, point2: r);
      c
        ..add(r)
        ..add(m);
      var notified = 0;
      c.addListener(() => notified++);
      c.setPointHeight('r', 6);
      expect(notified, 1);
      expect(r.spacePosition, const Vec3(4, 0, 6));
      expect(m.spacePosition, const Vec3(2, 0, 3));
    });

    test('setPointHeight refuses a point with no height, and a height that '
        'is not finite; setFreePointHeight still wants a free point', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 2);
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(r)
        ..add(m);
      expect(() => c.setPointHeight('m', 1), throwsArgumentError);
      expect(() => c.setPointHeight('r', double.infinity), throwsArgumentError);
      expect(() => c.setFreePointHeight('r', 1), throwsArgumentError);
      c.setPointHeight('a', 1);
      expect(a.height, 1);
    });

    test('the height command applies, undoes and redoes', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 2);
      c.add(r);
      final command = SetPointHeightCommand(pointId: 'r', from: 2, to: 5)
        ..apply(c);
      expect(r.spacePosition, const Vec3(4, 0, 5));
      command.undo(c);
      expect(r.spacePosition, const Vec3(4, 0, 2));
      command.apply(c);
      expect(r.height, 5);
    });

    test('a lift session holds it as it holds a free point', () {
      final r = RaisedPoint(id: 'r', foot: b, height: 2);
      final s = Segment(id: 's', point1: b, point2: r);
      c
        ..add(r)
        ..add(s);
      final session = LiftSession(c, r)..update(7);
      expect(r.height, 7);
      expect(s.spaceEnd, const Vec3(4, 0, 7));
      final command = session.end()! as SetPointHeightCommand;
      expect(r.height, 2);
      expect((command.from, command.to), (2.0, 7.0));

      LiftSession(c, r)
        ..update(9)
        ..cancel();
      expect(r.height, 2);
    });
  });

  group('ProportionalRaisedPoint', () {
    test('stands a multiple of a length over its foot, and follows both', () {
      final top = ProportionalRaisedPoint(
        id: 't',
        foot: a,
        from: a,
        to: b,
        factor: 1,
      );
      c.add(top);
      expect(top.spacePosition, const Vec3(0, 0, 4));
      expect(top.height, 4);
      c.moveFreePoint('b', const Vec2(0, 6));
      expect(top.spacePosition, const Vec3(0, 0, 6));
      c.moveFreePoint('a', const Vec2(0, 1));
      expect(top.spacePosition, const Vec3(0, 1, 5));
    });

    test('a negative factor is the other side of the plane', () {
      final under = ProportionalRaisedPoint(
        id: 't',
        foot: b,
        from: a,
        to: b,
        factor: -math.sqrt(2 / 3),
      );
      expect(
        under.spacePosition!.distanceTo(Vec3(4, 0, -4 * math.sqrt(2 / 3))),
        lessThan(1e-12),
      );
    });

    test('it measures its length in space', () {
      final top = ProportionalRaisedPoint(
        id: 't',
        foot: b,
        from: a,
        to: apex,
        factor: 2,
      );
      expect(top.spacePosition, const Vec3(4, 0, 6));
    });

    test('a factor that is not finite is refused', () {
      expect(
        () => ProportionalRaisedPoint(
          id: 't',
          foot: a,
          from: a,
          to: b,
          factor: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });

  test('both make a document space content, and round-trip at version 4', () {
    final flat = Construction();
    final p = FreePoint(id: 'p', position: const Vec2(1, 2));
    final q = FreePoint(id: 'q', position: const Vec2(4, 6));
    flat
      ..add(p)
      ..add(q);
    expect(hasSpaceContent(flat.objects), isFalse);
    flat.add(RaisedPoint(id: 'r', foot: p, height: 2));
    expect(hasSpaceContent(flat.objects), isTrue);

    c
      ..add(RaisedPoint(id: 'r1', foot: b, height: 2.5))
      ..add(RaisedPoint(id: 'r2', foot: b, plane: wall, height: -1))
      ..add(
        ProportionalRaisedPoint(
          id: 't1',
          foot: a,
          from: a,
          to: b,
          factor: math.sqrt(2 / 3),
        ),
      )
      ..add(
        ProportionalRaisedPoint(
          id: 't2',
          foot: a,
          from: a,
          to: b,
          plane: wall,
          factor: 1,
        ),
      );
    const viewport = ViewportState();
    final document = encodeDocument(flat, viewport: viewport);
    expect(document['version'], 4);
    final encoded = jsonEncode(encodeDocument(c, viewport: viewport));
    final decoded = decodeDocument(jsonDecode(encoded) as Map<String, dynamic>)
        .construction;
    for (final id in ['r1', 'r2', 't1', 't2']) {
      expect(
        (decoded.byId(id)! as GeoPoint).spacePosition,
        (c.byId(id)! as GeoPoint).spacePosition,
        reason: id,
      );
    }
    expect(jsonEncode(encodeDocument(decoded, viewport: viewport)), encoded);
  });
}
