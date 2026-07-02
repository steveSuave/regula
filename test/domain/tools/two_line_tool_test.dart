import 'dart:math' as math;

import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/construction/geo_object.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_angle.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:fgex/domain/tools/two_line_tool.dart';
import 'package:flutter_test/flutter_test.dart';

GeoObject _buildLineAngle(String id, GeoLine first, GeoLine second) =>
    LineAngle(id: id, line1: first, line2: second);

void main() {
  late int nextId;
  late FreePoint o;
  late FreePoint x;
  late FreePoint y;
  late LineThroughTwoPoints horizontal;
  late LineThroughTwoPoints vertical;

  TwoLineTool tool() =>
      TwoLineTool(newId: () => 'n${nextId++}', build: _buildLineAngle);

  setUp(() {
    nextId = 0;
    o = FreePoint(id: 'o', position: Vec2.zero);
    x = FreePoint(id: 'x', position: const Vec2(4, 0));
    y = FreePoint(id: 'y', position: const Vec2(0, 4));
    horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
    vertical = LineThroughTwoPoints(id: 'v', point1: o, point2: y);
  });

  group('TwoLineTool', () {
    test('two lines commit one AddObjectCommand, parents in tap order', () {
      final t = tool();
      expect(
        t.onInput(ToolInput(const Vec2(2, 0.1), hit: horizontal)),
        isA<ToolAccepted>(),
      );
      final result = t.onInput(ToolInput(const Vec2(0.1, 2), hit: vertical));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final angle = (command as AddObjectCommand).object as LineAngle;
      expect(angle.parents, [horizontal, vertical]);
      expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9));
    });

    test('non-line taps are ignored: empty canvas, points, circles', () {
      final t = tool();
      final circle = CircleCenterPoint(id: 'k', center: o, onCircle: x);

      expect(t.onInput(const ToolInput(Vec2(9, 9))), isA<ToolIgnored>());
      expect(t.onInput(ToolInput(Vec2.zero, hit: o)), isA<ToolIgnored>());
      expect(
        t.onInput(ToolInput(const Vec2(4, 0), hit: circle)),
        isA<ToolIgnored>(),
      );
      expect(t.previewPositions, isEmpty);
    });

    test('the same line twice is ignored, a segment carrier works', () {
      final t = tool();
      final segment = Segment(id: 's', point1: o, point2: y);

      t.onInput(ToolInput(const Vec2(2, 0), hit: horizontal));
      expect(
        t.onInput(ToolInput(const Vec2(3, 0), hit: horizontal)),
        isA<ToolIgnored>(),
      );
      expect(
        t.onInput(ToolInput(const Vec2(0, 2), hit: segment)),
        isA<ToolCommitted>(),
        reason: 'segments count as lines through their carrier',
      );
    });

    test('the first line previews the tap projected onto its carrier', () {
      final t = tool();
      t.onInput(ToolInput(const Vec2(2, 0.4), hit: horizontal));

      expect(t.previewPositions, hasLength(1));
      expect(t.previewPositions.single.closeTo(const Vec2(2, 0)), isTrue);
    });

    test('reset clears the collected line', () {
      final t = tool()
        ..onInput(ToolInput(const Vec2(2, 0), hit: horizontal))
        ..reset();

      expect(t.previewPositions, isEmpty);
      expect(
        t.onInput(ToolInput(const Vec2(0, 2), hit: vertical)),
        isA<ToolAccepted>(),
        reason: 'after reset the next line is the first input again',
      );
    });
  });
}
