import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/vertex_angle.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/intersection_tool.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late int nextId;
  late FreePoint o;
  late FreePoint x;
  late FreePoint y;

  IntersectionTool tool() => IntersectionTool(newId: () => 'n${nextId++}');

  /// Unit circle around the origin (radius |ox| = 4).
  CircleCenterPoint circleAtOrigin() =>
      CircleCenterPoint(id: 'k', center: o, onCircle: x);

  setUp(() {
    nextId = 0;
    o = FreePoint(id: 'o', position: Vec2.zero);
    x = FreePoint(id: 'x', position: const Vec2(4, 0));
    y = FreePoint(id: 'y', position: const Vec2(0, 4));
  });

  IntersectionPoint committedPoint(ToolResult result) {
    expect(result, isA<ToolCommitted>());
    final command = (result as ToolCommitted).command;
    return (command as AddObjectCommand).object as IntersectionPoint;
  }

  group('IntersectionTool', () {
    test('two lines commit one IntersectionPoint, parents in tap order', () {
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final vertical = LineThroughTwoPoints(id: 'v', point1: o, point2: y);
      final t = tool();

      expect(
        t.onInput(ToolInput(const Vec2(2, 0.1), hit: horizontal)),
        isA<ToolAccepted>(),
      );
      final point = committedPoint(
        t.onInput(ToolInput(const Vec2(0.1, 2), hit: vertical)),
      );

      expect(point.parents, [horizontal, vertical]);
      expect(point.branchIndex, 0);
      expect(point.position!.closeTo(Vec2.zero), isTrue);
    });

    test('line ∩ circle: the branch nearest the second tap wins', () {
      // The horizontal line cuts the radius-4 circle at (±4, 0).
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final circle = circleAtOrigin();

      final near = committedPoint(
        (tool()..onInput(ToolInput(const Vec2(1, 0), hit: horizontal)))
            .onInput(ToolInput(const Vec2(3.5, 0.2), hit: circle)),
      );
      final far = committedPoint(
        (tool()..onInput(ToolInput(const Vec2(1, 0), hit: horizontal)))
            .onInput(ToolInput(const Vec2(-3.5, 0.2), hit: circle)),
      );

      expect(near.position!.closeTo(const Vec2(4, 0)), isTrue);
      expect(far.position!.closeTo(const Vec2(-4, 0)), isTrue);
      expect(near.branchIndex != far.branchIndex, isTrue);
    });

    test('circle-first tap order still lands the branch nearest the tap', () {
      // Same construction as above, curves picked in the other order —
      // the line's branch role is fixed by type, not argument order.
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final circle = circleAtOrigin();
      final t = tool()..onInput(ToolInput(const Vec2(0, 4.1), hit: circle));

      final point = committedPoint(
        t.onInput(ToolInput(const Vec2(-3.9, 0), hit: horizontal)),
      );

      expect(point.parents, [circle, horizontal]);
      expect(point.position!.closeTo(const Vec2(-4, 0)), isTrue);
    });

    test('circle ∩ circle picks the branch nearest the second tap', () {
      final circle1 = circleAtOrigin();
      final center2 = FreePoint(id: 'c2', position: const Vec2(4, 4));
      final circle2 = CircleCenterPoint(id: 'k2', center: center2, onCircle: x);
      // Radius-4 circles centered (0,0) and (4,4) meet at (4,0) and (0,4).
      final t = tool()..onInput(ToolInput(const Vec2(4, 0.1), hit: circle1));

      final point = committedPoint(
        t.onInput(ToolInput(const Vec2(3.8, 0), hit: circle2)),
      );

      expect(point.position!.closeTo(const Vec2(4, 0)), isTrue);
    });

    test('non-intersecting curves commit an undefined branch-0 point', () {
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final far = FreePoint(id: 'f', position: const Vec2(0, 10));
      final rim = FreePoint(id: 'r', position: const Vec2(1, 10));
      final circle = CircleCenterPoint(id: 'k', center: far, onCircle: rim);
      final t = tool()..onInput(ToolInput(const Vec2(1, 0), hit: horizontal));

      final point = committedPoint(
        t.onInput(ToolInput(const Vec2(1, 9), hit: circle)),
      );

      expect(point.branchIndex, 0);
      expect(point.position, isNull);
      expect(point.isDefined, isFalse);
    });

    test('non-curve taps are ignored: empty canvas, points, angles', () {
      final t = tool();
      final angle = VertexAngle(id: 'a', arm1: x, vertex: o, arm2: y);

      expect(t.onInput(const ToolInput(Vec2(9, 9))), isA<ToolIgnored>());
      expect(t.onInput(ToolInput(Vec2.zero, hit: o)), isA<ToolIgnored>());
      expect(t.onInput(ToolInput(Vec2.zero, hit: angle)), isA<ToolIgnored>());
      expect(t.previewPositions, isEmpty);
    });

    test('the same curve twice is ignored, a segment carrier works', () {
      final circle = circleAtOrigin();
      final segment = Segment(id: 's', point1: y, point2: x);
      final t = tool()..onInput(ToolInput(const Vec2(4, 0.1), hit: circle));

      expect(
        t.onInput(ToolInput(const Vec2(-4, 0.1), hit: circle)),
        isA<ToolIgnored>(),
      );
      final point = committedPoint(
        t.onInput(ToolInput(const Vec2(0.2, 3.8), hit: segment)),
      );
      expect(point.position!.closeTo(const Vec2(0, 4)), isTrue);
    });

    test('previews the first tap projected onto a line carrier', () {
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final t = tool()
        ..onInput(ToolInput(const Vec2(2, 0.4), hit: horizontal));

      expect(t.previewPositions, hasLength(1));
      expect(t.previewPositions.single.closeTo(const Vec2(2, 0)), isTrue);
    });

    test('previews the first tap projected radially onto a circle', () {
      final t = tool()
        ..onInput(ToolInput(const Vec2(0, 3.5), hit: circleAtOrigin()));

      expect(t.previewPositions, hasLength(1));
      expect(t.previewPositions.single.closeTo(const Vec2(0, 4)), isTrue);
    });

    test('after committing the tool is ready for the next pair', () {
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final vertical = LineThroughTwoPoints(id: 'v', point1: o, point2: y);
      final t = tool()
        ..onInput(ToolInput(const Vec2(2, 0), hit: horizontal))
        ..onInput(ToolInput(const Vec2(0, 2), hit: vertical));

      expect(t.previewPositions, isEmpty);
      expect(
        t.onInput(ToolInput(const Vec2(3, 0), hit: horizontal)),
        isA<ToolAccepted>(),
        reason: 'the tool reset itself on commit',
      );
    });

    test('reset clears the collected curve', () {
      final horizontal = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final vertical = LineThroughTwoPoints(id: 'v', point1: o, point2: y);
      final t = tool()
        ..onInput(ToolInput(const Vec2(2, 0), hit: horizontal))
        ..reset();

      expect(t.previewPositions, isEmpty);
      expect(
        t.onInput(ToolInput(const Vec2(0, 2), hit: vertical)),
        isA<ToolAccepted>(),
        reason: 'after reset the next curve is the first input again',
      );
    });
  });
}
