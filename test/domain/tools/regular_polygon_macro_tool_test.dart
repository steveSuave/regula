import 'dart:math' as math;

import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/geo_object.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/rotated_point.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/regular_polygon_macro_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;

  RegularPolygonMacroTool toolFor(int sides) => RegularPolygonMacroTool(
        newId: () => 'n${nextId++}',
        sideCount: sides,
      );

  setUp(() => nextId = 0);

  Construction buildPolygon(int sides, Vec2 a, Vec2 b) {
    final construction = Construction();
    final tool = toolFor(sides);
    tool.onInput(ToolInput(a));
    (tool.onInput(ToolInput(b)) as ToolCommitted).command.apply(construction);
    return construction;
  }

  List<Vec2> vertexPositions(Construction c) => [
        for (final o in c.objects)
          if (o case final GeoPoint p) p.position!,
      ];

  /// Equal sides and equal distances to the vertex centroid on the
  /// current positions.
  void expectRegular(Construction construction, int sides) {
    final positions = vertexPositions(construction);
    expect(positions, hasLength(sides));
    var centroid = const Vec2(0, 0);
    for (final p in positions) {
      centroid += p;
    }
    centroid /= sides.toDouble();
    final circumradius = positions.first.distanceTo(centroid);
    final side = positions[0].distanceTo(positions[1]);
    for (var k = 0; k < sides; k++) {
      expect(positions[k].distanceTo(centroid), closeTo(circumradius, 1e-9));
      expect(
        positions[k].distanceTo(positions[(k + 1) % sides]),
        closeTo(side, 1e-9),
      );
    }
  }

  group('RegularPolygonMacroTool', () {
    test('two taps commit the polygon as one macro, left of A→B', () {
      final construction = Construction();
      final tool = toolFor(4);

      expect(tool.onInput(const ToolInput(Vec2(0, 0))), isA<ToolAccepted>());
      final result =
          tool.onInput(const ToolInput(Vec2(2, 0))) as ToolCommitted;

      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);
      expect(
        construction.length,
        8,
        reason: '2 free + 2 derived vertices + 4 sides',
      );
      final derived =
          construction.objects.whereType<RotatedPoint>().toList();
      expect(derived[0].position!.closeTo(const Vec2(2, 2), 1e-12), isTrue);
      expect(derived[1].position!.closeTo(const Vec2(0, 2), 1e-12), isTrue);
      expectRegular(construction, 4);

      result.command.undo(construction);
      expect(
        construction.isEmpty,
        isTrue,
        reason: 'the whole polygon is one undo unit',
      );
    });

    test('a hexagon is regular and stays regular under drags', () {
      final construction = buildPolygon(6, const Vec2(0, 0), const Vec2(3, 1));
      expectRegular(construction, 6);
      expect(
        construction.objects.whereType<Segment>(),
        hasLength(6),
        reason: 'no hidden scaffolding — every object is a vertex or a side',
      );

      final a = construction.objects.whereType<FreePoint>().first;
      construction.moveFreePoint(a.id, const Vec2(-2, 4));
      expectRegular(construction, 6);
    });

    test('three sides reproduce the equilateral apex', () {
      final construction = buildPolygon(3, const Vec2(0, 0), const Vec2(2, 0));
      final apex = construction.objects.whereType<RotatedPoint>().single;
      expect(
        apex.position!.closeTo(Vec2(1, math.sqrt(3)), 1e-12),
        isTrue,
      );
    });
  });
}
