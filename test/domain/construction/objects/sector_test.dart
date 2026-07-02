import 'dart:math' as math;

import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/sector.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sector', () {
    test('start fixes radius and start angle; end fixes only the angle',
        () {
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final s = FreePoint(id: 's', position: const Vec2(2, 0));
      final e = FreePoint(id: 'e', position: const Vec2(0, 5));
      final sector = Sector(id: 'w', center: c, start: s, end: e);

      expect(sector.circle!.center, Vec2.zero);
      expect(sector.circle!.radius, closeTo(2, 1e-9));
      expect(sector.startAngle, closeTo(0, 1e-9));
      expect(sector.sweep, closeTo(math.pi / 2, 1e-9));
      expect(sector.startRim!.closeTo(const Vec2(2, 0)), isTrue);
      expect(sector.endRim!.closeTo(const Vec2(0, 2)), isTrue,
          reason: "end's distance from the center must not matter");
      expect(sector.parents, [c, s, e]);
    });

    test('the sweep is always counter-clockwise from start to end', () {
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final s = FreePoint(id: 's', position: const Vec2(0, 5));
      final e = FreePoint(id: 'e', position: const Vec2(2, 0));
      final sector = Sector(id: 'w', center: c, start: s, end: e);

      expect(sector.sweep, closeTo(3 * math.pi / 2, 1e-9),
          reason: 'swapped start/end covers the complementary wedge');
    });

    test('containsAngle covers exactly the wedge, endpoints included', () {
      final sector = Sector(
        id: 'w',
        center: FreePoint(id: 'c', position: Vec2.zero),
        start: FreePoint(id: 's', position: const Vec2(2, 0)),
        end: FreePoint(id: 'e', position: const Vec2(0, 5)),
      );

      expect(sector.containsAngle(0), isTrue);
      expect(sector.containsAngle(math.pi / 4), isTrue);
      expect(sector.containsAngle(math.pi / 2), isTrue);
      expect(sector.containsAngle(math.pi), isFalse);
      expect(sector.containsAngle(-math.pi / 4), isFalse);
    });

    test('undefined while start or end sits on the center; recovers', () {
      final construction = Construction();
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final s = FreePoint(id: 's', position: const Vec2(2, 0));
      final e = FreePoint(id: 'e', position: const Vec2(0, 3));
      final sector = Sector(id: 'w', center: c, start: s, end: e);
      construction
        ..add(c)
        ..add(s)
        ..add(e)
        ..add(sector);

      construction.moveFreePoint('s', Vec2.zero);
      expect(sector.isDefined, isFalse);
      expect(sector.startRim, isNull);
      expect(sector.endRim, isNull);
      expect(sector.containsAngle(0), isFalse);

      construction.moveFreePoint('s', const Vec2(2, 0));
      expect(sector.isDefined, isTrue);

      construction.moveFreePoint('e', Vec2.zero);
      expect(sector.isDefined, isFalse);
    });
  });
}
