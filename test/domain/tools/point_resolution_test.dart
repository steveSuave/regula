import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/point_resolution.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late int nextId;
  String newId() => 'n${nextId++}';

  setUp(() => nextId = 0);

  LineThroughTwoPoints line(String id, Vec2 p1, Vec2 p2) =>
      LineThroughTwoPoints(
        id: 'l-$id',
        point1: FreePoint(id: 'l-$id-1', position: p1),
        point2: FreePoint(id: 'l-$id-2', position: p2),
      );

  CircleCenterPoint circle(String id, Vec2 center, Vec2 rim) =>
      CircleCenterPoint(
        id: 'c-$id',
        center: FreePoint(id: 'c-$id-c', position: center),
        onCircle: FreePoint(id: 'c-$id-r', position: rim),
      );

  group('resolvePoint', () {
    test('reuses an existing hit point without consuming an id', () {
      final existing = FreePoint(id: 'x', position: Vec2.zero);

      final resolved =
          resolvePoint(ToolInput(Vec2.zero, hit: existing), newId);

      expect(resolved.isNew, isFalse);
      expect(identical(resolved.point, existing), isTrue);
      expect(nextId, 0, reason: 'rung 1 must not call newId');
    });

    test('empty canvas makes a FreePoint at the tap', () {
      final resolved = resolvePoint(const ToolInput(Vec2(3, -2)), newId);

      expect(resolved.isNew, isTrue);
      final point = resolved.point as FreePoint;
      expect(point.position, const Vec2(3, -2));
      expect(point.id, 'n0');
    });

    test('a single line glues a PointOnObject at the projection', () {
      final l = line('h', Vec2.zero, const Vec2(4, 0));

      final resolved =
          resolvePoint(ToolInput(const Vec2(3, 1), hit: l), newId);

      expect(resolved.isNew, isTrue);
      final point = resolved.point as PointOnObject;
      expect(point.parents, [l]);
      expect(point.position!.closeTo(const Vec2(3, 0)), isTrue);
    });

    test('a single circle glues a PointOnObject on the rim', () {
      final c = circle('k', Vec2.zero, const Vec2(2, 0));

      final resolved =
          resolvePoint(ToolInput(const Vec2(0, 5), hit: c), newId);

      final point = resolved.point as PointOnObject;
      expect(point.parents, [c]);
      expect(point.position!.closeTo(const Vec2(0, 2)), isTrue);
    });

    test('a tap near two crossing lines snaps to their intersection', () {
      final l1 = line('h', Vec2.zero, const Vec2(4, 0));
      final l2 = line('v', const Vec2(2, -2), const Vec2(2, 2));

      final resolved = resolvePoint(
        ToolInput(
          const Vec2(2.3, 0.3),
          hit: l1,
          extraHits: [l2],
          snapThreshold: 1,
        ),
        newId,
      );

      expect(resolved.isNew, isTrue);
      final point = resolved.point as IntersectionPoint;
      expect(point.parents, [l1, l2]);
      expect(point.position!.closeTo(const Vec2(2, 0)), isTrue);
    });

    test('line ∩ circle picks the branch nearest the tap', () {
      // Branches along the line's direction: 0 at (-2, 0), 1 at (2, 0).
      final l = line('h', const Vec2(-4, 0), const Vec2(4, 0));
      final c = circle('k', Vec2.zero, const Vec2(2, 0));

      final near2 = resolvePoint(
        ToolInput(
          const Vec2(1.9, 0.2),
          hit: c,
          extraHits: [l],
          snapThreshold: 1,
        ),
        newId,
      );
      final nearMinus2 = resolvePoint(
        ToolInput(
          const Vec2(-1.9, 0.2),
          hit: c,
          extraHits: [l],
          snapThreshold: 1,
        ),
        newId,
      );

      expect((near2.point as IntersectionPoint).branchIndex, 1);
      expect(near2.point.position!.closeTo(const Vec2(2, 0)), isTrue);
      expect((nearMinus2.point as IntersectionPoint).branchIndex, 0);
      expect(nearMinus2.point.position!.closeTo(const Vec2(-2, 0)), isTrue);
    });

    test('circle ∩ circle snaps and both branches are reachable', () {
      // Unit-2 circles centered (0,0) and (2,0): crossings at (1, ±√3).
      final c1 = circle('a', Vec2.zero, const Vec2(2, 0));
      final c2 = circle('b', const Vec2(2, 0), const Vec2(4, 0));
      final up = Vec2(1, 1.7320508075688772);

      final resolved = resolvePoint(
        ToolInput(
          up + const Vec2(0.1, 0.1),
          hit: c1,
          extraHits: [c2],
          snapThreshold: 0.5,
        ),
        newId,
      );

      final point = resolved.point as IntersectionPoint;
      expect(point.position!.closeTo(up, 1e-9), isTrue);
    });

    test('a crossing beyond the threshold glues to the ranked-best curve',
        () {
      final l1 = line('h', Vec2.zero, const Vec2(4, 0));
      final l2 = line('v', const Vec2(2, -2), const Vec2(2, 2));

      final resolved = resolvePoint(
        ToolInput(
          const Vec2(2.5, 0.1),
          hit: l1,
          extraHits: [l2],
          snapThreshold: 0.3,
        ),
        newId,
      );

      final point = resolved.point as PointOnObject;
      expect(point.parents, [l1], reason: 'glue to the topmost curve');
      expect(point.position!.closeTo(const Vec2(2.5, 0)), isTrue);
    });

    test('the default snapThreshold of 0 disables intersection snapping',
        () {
      final l1 = line('h', Vec2.zero, const Vec2(4, 0));
      final l2 = line('v', const Vec2(2, -2), const Vec2(2, 2));

      final resolved = resolvePoint(
        ToolInput(const Vec2(2, 0), hit: l1, extraHits: [l2]),
        newId,
      );

      expect(resolved.point, isA<PointOnObject>(),
          reason: 'legacy inputs without threshold data must not snap');
    });

    test('parallel lines in range glue instead of snapping', () {
      final l1 = line('a', Vec2.zero, const Vec2(4, 0));
      final l2 = line('b', const Vec2(0, 0.2), const Vec2(4, 0.2));

      final resolved = resolvePoint(
        ToolInput(
          const Vec2(2, 0.05),
          hit: l1,
          extraHits: [l2],
          snapThreshold: 1,
        ),
        newId,
      );

      expect(resolved.point, isA<PointOnObject>());
      expect(resolved.point.parents, [l1]);
    });

    test('three curves: the nearest branch across all pairs wins', () {
      final l1 = line('h', const Vec2(-4, 0), const Vec2(4, 0));
      final l2 = line('v0', const Vec2(0, -2), const Vec2(0, 2));
      final l3 = line('v1', const Vec2(1, -2), const Vec2(1, 2));

      // Crossings at (0,0) and (1,0); l2 ∩ l3 are parallel. The tap is
      // 0.11 from (1,0) and 0.9 from (0,0).
      final resolved = resolvePoint(
        ToolInput(
          const Vec2(0.9, 0.05),
          hit: l1,
          extraHits: [l2, l3],
          snapThreshold: 1,
        ),
        newId,
      );

      final point = resolved.point as IntersectionPoint;
      expect(point.parents, [l1, l3]);
      expect(point.position!.closeTo(const Vec2(1, 0)), isTrue);
    });
  });

  group('nearestIntersectionBranch', () {
    test('null when the curves do not currently intersect', () {
      final l = line('h', Vec2.zero, const Vec2(4, 0));
      final c = circle('k', const Vec2(0, 5), const Vec2(1, 5));

      expect(nearestIntersectionBranch(l, c, Vec2.zero), isNull);
    });

    test('tangency resolves to branch 0', () {
      final l = line('h', Vec2.zero, const Vec2(4, 0));
      final c = circle('k', const Vec2(2, 2), const Vec2(2, 0));

      final branch = nearestIntersectionBranch(l, c, const Vec2(2.1, 0));

      expect(branch, isNotNull);
      expect(branch!.index, 0);
      expect(branch.distance, closeTo(0.1, 1e-9));
    });
  });
}
