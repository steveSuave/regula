import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_angle.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/domain/tools/two_line_tool.dart';

GeoObject _buildLineAngle(
  String id,
  GeoLine first,
  GeoLine second,
  Vec2 firstTap,
  Vec2 secondTap,
) =>
    LineAngle.near(
      id: id,
      line1: first,
      line2: second,
      tap1: firstTap,
      tap2: secondTap,
    );

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

    test('the two tap positions reach the builder: obtuse taps, obtuse '
        'wedge', () {
      final t = tool();
      // Taps on −x and +y: the wedge between those halves is the obtuse
      // 3π/4 one (the lines cross at 45°/135°).
      final diagonal = LineThroughTwoPoints(
        id: 'd',
        point1: o,
        point2: FreePoint(id: 'dd', position: const Vec2(1, 1)),
      );
      t.onInput(ToolInput(const Vec2(-3, 0.1), hit: horizontal));
      final result = t.onInput(ToolInput(const Vec2(1.1, 1), hit: diagonal));

      final command = (result as ToolCommitted).command;
      final angle = (command as AddObjectCommand).object as LineAngle;
      expect(angle.sign1, -1);
      expect(angle.sign2, 1);
      expect(angle.angle!.measure, closeTo(3 * math.pi / 4, 1e-9));
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
      expect(t.previewObjectIds, isEmpty);
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

    test('the first line is reported for haloing, with no marker', () {
      final t = tool();
      t.onInput(ToolInput(const Vec2(2, 0.4), hit: horizontal));

      expect(t.previewObjectIds, ['h']);
      expect(t.previewPositions, isEmpty,
          reason: 'an existing line is haloed, never marked');
    });

    test('reset clears the collected line', () {
      final t = tool()
        ..onInput(ToolInput(const Vec2(2, 0), hit: horizontal))
        ..reset();

      expect(t.previewObjectIds, isEmpty);
      expect(
        t.onInput(ToolInput(const Vec2(0, 2), hit: vertical)),
        isA<ToolAccepted>(),
        reason: 'after reset the next line is the first input again',
      );
    });
  });
}
