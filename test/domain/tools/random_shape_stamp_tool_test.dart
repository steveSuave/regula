import 'dart:math' as math;

import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/random_shape_stamp_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;

  RandomShapeStampTool toolFor({
    required int min,
    required int max,
    int seed = 7,
  }) =>
      RandomShapeStampTool(
        newId: () => 'n${nextId++}',
        minVertices: min,
        maxVertices: max,
        random: math.Random(seed),
      );

  setUp(() => nextId = 0);

  group('RandomShapeStampTool', () {
    test('one tap stamps free vertices joined by segments, one undo unit',
        () {
      final construction = Construction();
      final tool = toolFor(min: 3, max: 3);

      final result =
          tool.onInput(const ToolInput(Vec2(10, -5))) as ToolCommitted;
      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);

      expect(construction.objects.whereType<FreePoint>(), hasLength(3));
      expect(construction.objects.whereType<Segment>(), hasLength(3));

      result.command.undo(construction);
      expect(
        construction.isEmpty,
        isTrue,
        reason: 'the whole stamp is one undo unit',
      );
    });

    test('vertices land in the stamp annulus around the tap', () {
      const tap = Vec2(100, 200);
      const threshold = 4.0; // world units → radius 40
      final construction = Construction();
      final tool = toolFor(min: 4, max: 7);

      final result = tool.onInput(
        const ToolInput(tap, snapThreshold: threshold),
      ) as ToolCommitted;
      result.command.apply(construction);

      for (final vertex in construction.objects.whereType<FreePoint>()) {
        final distance = vertex.position.distanceTo(tap);
        expect(distance, greaterThanOrEqualTo(20));
        expect(distance, lessThanOrEqualTo(40));
      }
    });

    test('the vertex count stays inside the requested range', () {
      for (var seed = 0; seed < 20; seed++) {
        final construction = Construction();
        final tool = toolFor(min: 4, max: 7, seed: seed);
        (tool.onInput(const ToolInput(Vec2(0, 0))) as ToolCommitted)
            .command
            .apply(construction);
        final count =
            construction.objects.whereType<FreePoint>().length;
        expect(count, inInclusiveRange(4, 7));
        expect(
          construction.objects.whereType<Segment>(),
          hasLength(count),
          reason: 'the outline closes',
        );
      }
    });

    test('the outline is simple — vertices wind around the tap in order',
        () {
      const tap = Vec2(0, 0);
      final construction = Construction();
      final tool = toolFor(min: 5, max: 5);
      (tool.onInput(const ToolInput(tap)) as ToolCommitted)
          .command
          .apply(construction);

      // The stamp draws its angles in [0, 2π); atan2 lives in [−π, π], so
      // normalize back before comparing the winding order.
      final angles = [
        for (final v in construction.objects.whereType<FreePoint>())
          math.atan2(v.position.y, v.position.x) % (2 * math.pi),
      ];
      final sorted = List.of(angles)..sort();
      expect(angles, sorted, reason: 'sorted angles cannot self-intersect');
    });

    test('a tap on an existing point stamps beside it, never consuming it',
        () {
      final construction = Construction();
      final e = FreePoint(id: 'e', position: const Vec2(0, 0));
      construction.add(e);
      final tool = toolFor(min: 3, max: 3);

      final result =
          tool.onInput(ToolInput(e.position, hit: e)) as ToolCommitted;
      result.command.apply(construction);
      expect(
        construction.objects.whereType<FreePoint>(),
        hasLength(4),
        reason: 'three new vertices, the hit point untouched',
      );

      result.command.undo(construction);
      expect(construction.objects, [e]);
    });
  });
}
