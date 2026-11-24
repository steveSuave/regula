// Intent 004, milestone 2, stage C: constructions inside a plane. Sheets,
// free points that belong to a plane, the adapters that carry an object
// into a plane's coordinates, and the rule for what may be carried.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/chart_line.dart';
import 'package:regula/domain/construction/objects/chart_point.dart';
import 'package:regula/domain/construction/objects/compass_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_plane_intersection_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/parallel_line.dart';
import 'package:regula/domain/construction/objects/perpendicular_line.dart';
import 'package:regula/domain/construction/objects/plane_intersection_line.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/space_incidence.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/point3.dart';
import 'package:regula/domain/tools/drag_session.dart';
import 'package:regula/domain/tools/intersection_tool.dart';
import 'package:regula/domain/tools/plane_scope.dart';
import 'package:regula/domain/tools/point_and_line_tool.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/domain/tools/two_point_tool.dart';

/// A pyramid over a square of side 4 with its apex 3 above the centre,
/// the face OAB as a plane, and the base as a plane through A, B, C.
class _Pyramid {
  _Pyramid() {
    for (final object in [a, b, c, d, o, ab, cd, oa, face, floor]) {
      construction.add(object);
    }
  }

  final construction = Construction();
  final a = FreePoint(id: 'a', position: Vec2.zero);
  final b = FreePoint(id: 'b', position: const Vec2(4, 0));
  final c = FreePoint(id: 'c', position: const Vec2(4, 4));
  final d = FreePoint(id: 'd', position: const Vec2(0, 4));
  final o = FreePoint(id: 'o', position: const Vec2(2, 2), height: 3);
  late final ab = Segment(id: 'ab', point1: a, point2: b);
  late final cd = Segment(id: 'cd', point1: c, point2: d);
  late final oa = Segment(id: 'oa', point1: o, point2: a);
  late final face = ThreePointPlane(
    id: 'face',
    point1: a,
    point2: b,
    point3: o,
  );
  late final floor = ThreePointPlane(
    id: 'floor',
    point1: a,
    point2: b,
    point3: c,
  );
}

void main() {
  late _Pyramid p;
  late int nextId;
  String newId() => 'n${nextId++}';

  setUp(() {
    p = _Pyramid();
    nextId = 0;
  });

  group('sheets', () {
    test('a planar object is on the base sheet; a plane is on none', () {
      expect(p.a.sheet, Sheet.base);
      expect(p.ab.sheet, Sheet.base);
      expect(p.ab.sheet.isBase, isTrue);
      expect(p.face.sheet, Sheet.none);
      expect(Sheet.base.frame!.lift(const Vec2(1, 2)), const Vec3(1, 2, 0));
      expect(Sheet.none.frame, isNull);
    });

    test('a sheet is the plane object, not the place', () {
      // The floor coincides with the base plane and is another sheet.
      expect(Sheet.of(p.floor), isNot(Sheet.base));
      expect(Sheet.of(p.floor), Sheet.of(p.floor));
      expect(Sheet.of(p.floor), isNot(Sheet.of(p.face)));
      expect(Sheet.of(p.floor).hashCode, Sheet.of(p.floor).hashCode);
      expect(Sheet.of(p.face).frame, p.face.frame);
    });

    test('an object built on one sheet is on it; across two, on none', () {
      final f = FreePoint(id: 'f', position: const Vec2(1, 1), plane: p.face);
      final g = FreePoint(id: 'g', position: const Vec2(2, 1), plane: p.face);
      p.construction
        ..add(f)
        ..add(g);
      expect(f.sheet, Sheet.of(p.face));
      expect(f.parents, [p.face]);
      final inFace = LineThroughTwoPoints(id: 'l', point1: f, point2: g);
      expect(inFace.sheet, Sheet.of(p.face));
      expect(inFace.projLine, isNotNull);
      final across = Segment(id: 's', point1: f, point2: p.c);
      expect(across.sheet, Sheet.none);
      expect(across.projLine, isNull, reason: 'no common coordinates');
      expect(across.isDefined, isTrue, reason: 'and still a segment of space');
      expect(across.spaceStart, f.spacePosition);
      expect(across.spaceEnd, const Vec3(4, 4, 0));
      final mid = Midpoint(id: 'm', point1: f, point2: p.c);
      expect(mid.projPoint, isNull);
      expect(
        mid.spacePosition!.distanceTo(
          (f.spacePosition! + const Vec3(4, 4, 0)) * 0.5,
        ),
        lessThan(1e-12),
      );
      final parallel = ParallelLine(id: 'q', through: p.c, reference: inFace);
      expect(parallel.sheet, Sheet.none);
      expect(parallel.projLine, isNull);
      expect(parallel.spaceLine!.contains(const Point3(4, 4, 0), 1e-9), isTrue);
    });
  });

  group('a free point placed in a plane', () {
    late FreePoint f;
    setUp(() {
      f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      p.construction.add(f);
    });

    test('is where the plane puts its coordinates', () {
      final frame = p.face.frame!;
      expect(f.position, const Vec2(1, 2));
      expect(f.spacePosition, frame.lift(const Vec2(1, 2)));
      expect(p.face.spacePlane!.contains(f.spacePoint!, 1e-9), isTrue);
    });

    test('moves with its plane when a defining point is dragged', () {
      p.construction.setFreePointHeight('o', 5);
      expect(f.position, const Vec2(1, 2), reason: 'its coordinates hold');
      expect(p.face.spacePlane!.contains(f.spacePoint!, 1e-9), isTrue);
      expect(f.spacePosition, p.face.frame!.lift(const Vec2(1, 2)));
    });

    test('lifts along its own plane\'s normal', () {
      p.construction.setFreePointHeight('f', 2);
      expect(f.position, isNull);
      final frame = p.face.frame!;
      expect(
        f.spacePosition!.distanceTo(
          frame.lift(const Vec2(1, 2)) + frame.normal * 2,
        ),
        lessThan(1e-12),
      );
      expect(frame.heightOf(f.spacePosition!), closeTo(2, 1e-12));
    });

    test('drags in its plane as one command, and is undefined with it', () {
      final session = DragSession.start(p.construction, f, const Vec2(1, 2))!
        ..update(const Vec2(3, 1));
      expect(f.position, const Vec2(3, 1));
      final command = session.end()!..apply(p.construction);
      expect(f.spacePosition, p.face.frame!.lift(const Vec2(3, 1)));
      command.undo(p.construction);
      expect(f.position, const Vec2(1, 2));

      // The plane collapses: A, B, O collinear.
      p.construction
        ..setFreePointHeight('o', 0)
        ..moveFreePoint('o', const Vec2(8, 0));
      expect(p.face.isDefined, isFalse);
      expect(f.spacePosition, isNull);
      expect(f.isDefined, isTrue, reason: 'it keeps its coordinates');
    });

    test('a circle and an intersection built in the plane lie in it', () {
      final g = FreePoint(id: 'g', position: const Vec2(3, 2), plane: p.face);
      final circle = CompassCircle(
        id: 'k',
        radiusPoint1: f,
        radiusPoint2: g,
        center: f,
      );
      final h = FreePoint(id: 'h', position: const Vec2(0, 0), plane: p.face);
      final line = LineThroughTwoPoints(id: 'l', point1: h, point2: g);
      final x = IntersectionPoint(
        id: 'x',
        curve1: line,
        curve2: circle,
        branchIndex: 0,
      );
      p.construction
        ..add(g)
        ..add(circle)
        ..add(h)
        ..add(line)
        ..add(x);
      expect(circle.sheet, Sheet.of(p.face));
      expect(circle.circle!.radius, 2);
      expect(x.isDefined, isTrue);
      expect(p.face.spacePlane!.contains(x.spacePoint!, 1e-9), isTrue);
      expect(
        x.spacePosition!.distanceTo(f.spacePosition!),
        closeTo(2, 1e-9),
        reason: 'the frame is orthonormal: the radius is a distance of space',
      );
    });
  });

  group('liesIn', () {
    test('a defining point is in its plane wherever it is put', () {
      expect(liesIn(p.o, p.face), isTrue);
      expect(liesIn(p.a, p.face), isTrue);
      p.construction.setFreePointHeight('a', 7);
      expect(liesIn(p.a, p.face), isTrue);
      expect(liesIn(p.a, p.floor), isTrue);
    });

    test('a point that only happens to be in the plane is not', () {
      // D is in the floor's plane, numerically; nothing says so.
      expect(p.floor.spacePlane!.contains(p.d.spacePoint!), isTrue);
      expect(liesIn(p.d, p.floor), isFalse);
      expect(liesIn(p.c, p.face), isFalse);
    });

    test('a line through two points in the plane, and what is on it', () {
      expect(liesIn(p.ab, p.face), isTrue);
      expect(liesIn(p.oa, p.face), isTrue);
      expect(liesIn(p.cd, p.face), isFalse);
      expect(liesIn(p.cd, p.floor), isFalse, reason: 'D is not known in it');
      final mid = Midpoint(id: 'm', point1: p.o, point2: p.b);
      final glued = PointOnObject(id: 'g', curve: p.ab, parameter: 1);
      expect(liesIn(mid, p.face), isTrue);
      expect(liesIn(glued, p.face), isTrue);
      expect(liesIn(glued, p.floor), isTrue);
      final median = Segment(id: 'med', point1: p.a, point2: mid);
      expect(liesIn(median, p.face), isTrue);
      expect(liesIn(median, p.floor), isFalse);
    });

    test('what planes give: their meet with a line, and with each other', () {
      final foot = LinePlaneIntersectionPoint(
        id: 'x',
        line: p.cd,
        plane: p.face,
      );
      expect(liesIn(foot, p.face), isTrue);
      expect(liesIn(foot, p.floor), isFalse);
      final edge = PlaneIntersectionLine(
        id: 'e',
        plane1: p.face,
        plane2: p.floor,
      );
      expect(liesIn(edge, p.face), isTrue);
      expect(liesIn(edge, p.floor), isTrue);
    });

    test('an object on the plane\'s own sheet is in it while it has a value '
        'there', () {
      final f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      p.construction.add(f);
      expect(liesIn(f, p.face), isTrue);
      final toApex = Midpoint(id: 'm', point1: f, point2: p.o);
      expect(liesIn(toApex, p.face), isTrue);
      p.construction.setFreePointHeight('f', 1);
      expect(liesIn(f, p.face), isFalse);
      expect(liesIn(toApex, p.face), isFalse);
    });

    test('planesHolding finds the planes, the preferred one first', () {
      expect(planesHolding(p.construction.objects, [p.ab, p.oa]), [p.face]);
      expect(
        planesHolding(p.construction.objects, [p.ab], preferred: p.floor),
        [p.floor, p.face],
      );
      expect(planesHolding(p.construction.objects, [p.oa, p.cd]), isEmpty);
    });
  });

  group('adapters', () {
    test('a ChartPoint is its source, read in the plane', () {
      final apex = ChartPoint(id: 'co', source: p.o, plane: p.face);
      p.construction.add(apex);
      expect(apex.isInternal, isTrue);
      expect(apex.attributes.visible, isFalse);
      expect(apex.sheet, Sheet.of(p.face));
      expect(apex.spacePosition, p.o.spacePosition);
      expect(
        p.face.frame!.lift(apex.position!).distanceTo(p.o.spacePosition!),
        lessThan(1e-12),
      );
      // It follows its source, and the plane follows the source too.
      p.construction.setFreePointHeight('o', 9);
      expect(
        p.face.frame!.lift(apex.position!).distanceTo(const Vec3(2, 2, 9)),
        lessThan(1e-12),
      );
    });

    test('a ChartLine keeps its source\'s ends', () {
      final edge = ChartLine(id: 'cab', source: p.ab, plane: p.face);
      p.construction.add(edge);
      expect(edge.isInternal, isTrue);
      expect(edge.spaceLine, p.ab.spaceLine);
      final (min, max) = edge.parameterExtent!;
      expect(max! - min!, closeTo(4, 1e-12));
      final glued = PointOnObject(id: 'g', curve: edge, parameter: min + 1);
      p.construction.add(glued);
      expect(glued.spacePosition!.z.abs(), lessThan(1e-12));
      expect(glued.spacePosition!.y.abs(), lessThan(1e-12));
      expect(
        [1.0, 3.0].any((x) => (glued.spacePosition!.x - x).abs() < 1e-9),
        isTrue,
      );
    });

    test('has no value for a source that is not in the plane', () {
      final wrong = ChartPoint(id: 'cc', source: p.c, plane: p.face);
      expect(wrong.projPoint, isNull);
      expect(wrong.isDefined, isFalse);
      expect(ChartLine(id: 'l', source: p.cd, plane: p.face).projLine, isNull);
    });

    test('loses its value when its source leaves, and gets it back', () {
      final f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      final toApex = Midpoint(id: 'm', point1: f, point2: p.o);
      final floorless = ThreePointPlane(
        id: 'other',
        point1: f,
        point2: p.o,
        point3: p.c,
      );
      final read = ChartPoint(id: 'cm', source: toApex, plane: p.face);
      p.construction
        ..add(f)
        ..add(toApex)
        ..add(floorless)
        ..add(read);
      expect(read.isDefined, isTrue);
      p.construction.setFreePointHeight('f', 1);
      expect(read.projPoint, isNull, reason: 'never the foot');
      p.construction.setFreePointHeight('f', 0);
      expect(read.isDefined, isTrue);
    });
  });

  group('PlaneScope', () {
    ToolInput tap(GeoObject? hit, {GeoPlane? plane, Vec2 at = Vec2.zero}) =>
        ToolInput(at, hit: hit, objects: p.construction.objects, plane: plane);

    TwoPointTool planar() => TwoPointTool(
      newId: newId,
      build: (id, a, b) => LineThroughTwoPoints(id: id, point1: a, point2: b),
    );

    test('hands a planar tool adapters for points in the active plane, and '
        'adds them with what it builds', () {
      final scope = PlaneScope();
      final tool = planar();
      final first = scope.adapt(tap(p.o, plane: p.face), tool, newId);
      expect(first.refusal, isNull);
      expect(first.input!.hit, isA<ChartPoint>());
      expect(tool.onInput(first.input!), isA<ToolAccepted>());
      expect(scope.sourceIdOf(tool.previewObjectIds.single), 'o');

      final second = scope.adapt(tap(p.b, plane: p.face), tool, newId);
      final committed = tool.onInput(second.input!) as ToolCommitted;
      final whole = scope.commit(committed.command) as MacroCommand;
      expect(whole.commands, hasLength(3));
      expect(
        [
          for (final c in whole.commands.take(2))
            (c as AddObjectCommand).object.runtimeType,
        ],
        [ChartPoint, ChartPoint],
      );
      final before = p.construction.objects.length;
      whole.apply(p.construction);
      final line = p.construction.objects.last as LineThroughTwoPoints;
      expect(line.sheet, Sheet.of(p.face));
      expect(line.spaceLine!.contains(p.o.spacePoint!, 1e-9), isTrue);
      expect(line.spaceLine!.contains(p.b.spacePoint!, 1e-9), isTrue);
      whole.undo(p.construction);
      expect(p.construction.objects, hasLength(before));
    });

    test('reuses an adapter that is already in the construction', () {
      final existing = ChartPoint(id: 'co', source: p.o, plane: p.face);
      p.construction.add(existing);
      final scope = PlaneScope();
      final seen = scope.adapt(tap(p.o, plane: p.face), planar(), newId);
      expect(seen.input!.hit, same(existing));
      expect(adapterOf(p.o, p.face, p.construction.objects), same(existing));
      expect(adapterOf(p.o, p.floor, p.construction.objects), isNull);
    });

    test('adapts a line in the plane for a tool that takes one', () {
      final scope = PlaneScope();
      final tool = PointAndLineTool(newId: newId, build: PerpendicularLine.new);
      tool.onInput(scope.adapt(tap(p.o, plane: p.face), tool, newId).input!);
      final committed = tool.onInput(
        scope.adapt(tap(p.ab, plane: p.face), tool, newId).input!,
      ) as ToolCommitted;
      final whole = scope.commit(committed.command)..apply(p.construction);
      expect((whole as MacroCommand).commands, hasLength(3));
      final slant = p.construction.objects.last as PerpendicularLine;
      expect(slant.isDefined, isTrue);
      // Through O, at right angles to AB, in the face.
      final direction = slant.spaceLine!.direction;
      expect(direction.dot(const Vec3(1, 0, 0)).abs(), lessThan(1e-9));
      expect(slant.spaceLine!.contains(p.o.spacePoint!, 1e-9), isTrue);
      expect(slant.spaceLine!.liesIn(p.face.spacePlane!, 1e-9), isTrue);
    });

    test('refuses the tap when the tapped object is not in the plane', () {
      final scope = PlaneScope();
      final seen = scope.adapt(tap(p.c, plane: p.face), planar(), newId);
      expect(seen.input, isNull);
      expect(seen.refusal, ScopeRefusal.notInPlane);
      // With the base plane active, an object of another sheet is refused
      // the same way.
      final f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      p.construction.add(f);
      expect(scope.adapt(tap(f), planar(), newId).refusal, isNotNull);
      expect(scope.adapt(tap(f, plane: p.face), planar(), newId).input!.hit, f);
    });

    test('drops an extra hit that is not in the plane, and keeps the tap', () {
      final scope = PlaneScope();
      final input = ToolInput(
        Vec2.zero,
        hit: p.o,
        extraHits: [p.cd, p.oa],
        objects: p.construction.objects,
        plane: p.face,
      );
      final seen = scope.adapt(input, planar(), newId).input!;
      expect(seen.hits.map((h) => h.runtimeType), [ChartPoint, ChartLine]);
    });

    test('a tap on empty canvas places the point in the active plane', () {
      final scope = PlaneScope();
      final tool = planar();
      final seen = scope.adapt(
        tap(null, plane: p.face, at: const Vec2(1, 1)),
        tool,
        newId,
      );
      tool.onInput(seen.input!);
      final done = tool.onInput(
        scope
            .adapt(tap(null, plane: p.face, at: const Vec2(2, 3)), tool, newId)
            .input!,
      ) as ToolCommitted;
      scope.commit(done.command).apply(p.construction);
      final placed = p.construction.objects.whereType<FreePoint>().where(
        (point) => point.plane != null,
      );
      expect(placed, hasLength(2));
      expect(placed.every((point) => identical(point.plane, p.face)), isTrue);
    });

    test('a plane under the tap is ground, not a hit: the tap goes through '
        'as a tap on empty canvas', () {
      final scope = PlaneScope();
      for (final plane in [p.face, null]) {
        final seen = scope.adapt(tap(p.face, plane: plane), planar(), newId);
        expect(seen.refusal, isNull);
        expect(seen.input!.hit, isNull);
      }
    });

    test('a space tool is handed everything as it is', () {
      final scope = PlaneScope();
      final segment = TwoPointTool(
        newId: newId,
        scope: ToolScope.space,
        build: (id, a, b) => Segment(id: id, point1: a, point2: b),
      );
      final seen = scope.adapt(tap(p.c, plane: p.face), segment, newId);
      expect(seen.input!.hit, same(p.c));
      expect(scope.commit(AddObjectCommand(p.c)), isA<AddObjectCommand>());
    });

    test('reset forgets the adapters a tool was holding', () {
      final scope = PlaneScope();
      final tool = planar();
      final seen = scope.adapt(tap(p.o, plane: p.face), tool, newId);
      tool.onInput(seen.input!);
      scope.reset();
      expect(scope.sourceIdOf(seen.input!.hit!.id), seen.input!.hit!.id);
    });
  });

  group('the Intersection tool across sheets', () {
    ToolInput tap(GeoObject hit, {GeoPlane? plane}) => ToolInput(
      Vec2.zero,
      hit: hit,
      objects: p.construction.objects,
      plane: plane,
    );

    test('two medians of a face meet at its centroid', () {
      final mOa = Midpoint(id: 'moa', point1: p.o, point2: p.a);
      final mOb = Midpoint(id: 'mob', point1: p.o, point2: p.b);
      final fromB = Segment(id: 'bm', point1: p.b, point2: mOa);
      final fromA = Segment(id: 'am', point1: p.a, point2: mOb);
      p.construction
        ..add(mOa)
        ..add(mOb)
        ..add(fromB)
        ..add(fromA);
      final tool = IntersectionTool(newId: newId)..onInput(tap(fromB));
      final result = tool.onInput(tap(fromA)) as ToolCommitted;
      final commands = (result.command as MacroCommand).commands;
      expect(commands, hasLength(3), reason: 'two adapters and the point');
      result.command.apply(p.construction);
      final g = p.construction.objects.last as IntersectionPoint;
      expect(g.sheet, Sheet.of(p.face));
      final centroid =
          (p.o.spacePosition! + p.a.spacePosition! + p.b.spacePosition!) / 3;
      expect(g.spacePosition!.distanceTo(centroid), lessThan(1e-9));

      // And it stays the centroid when the apex moves.
      p.construction
        ..moveFreePoint('o', const Vec2(1, 3))
        ..setFreePointHeight('o', 5);
      final moved =
          (p.o.spacePosition! + p.a.spacePosition! + p.b.spacePosition!) / 3;
      expect(g.spacePosition!.distanceTo(moved), lessThan(1e-9));
    });

    test('skew lines have no intersection', () {
      final tool = IntersectionTool(newId: newId)..onInput(tap(p.oa));
      expect(tool.onInput(tap(p.cd)), isA<ToolIgnored>());
    });

    test('lines that cross by position, with no plane known to hold both, '
        'have none either', () {
      // AB and the diagonal-ish line through D and the midpoint of AB
      // cross in the base plane; the floor plane knows only A, B, C.
      final e = FreePoint(id: 'e', position: const Vec2(2, -1));
      final de = Segment(id: 'de', point1: p.d, point2: e);
      p.construction
        ..add(e)
        ..add(de)
        ..setFreePointHeight('e', 0);
      // On the base sheet they are planar lines and intersect as always.
      final planar = IntersectionTool(newId: newId)..onInput(tap(p.ab));
      expect(planar.onInput(tap(de)), isA<ToolCommitted>());
      // Lift D: DE leaves the sheet, and no plane holds DE and AB.
      p.construction.setFreePointHeight('d', 1);
      final lifted = IntersectionTool(newId: newId)..onInput(tap(p.ab));
      expect(lifted.onInput(tap(de)), isA<ToolIgnored>());
    });
  });

  group('the save format', () {
    const viewport = ViewportState();

    test('round-trips a point placed in a plane and the adapters under a '
        'construction', () {
      final f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      final apex = ChartPoint(id: 'co', source: p.o, plane: p.face);
      final line = LineThroughTwoPoints(id: 'l', point1: f, point2: apex);
      p.construction
        ..add(f)
        ..add(apex)
        ..add(line);
      final encoded = jsonEncode(
        encodeDocument(p.construction, viewport: viewport),
      );
      final decoded = decodeDocument(
        jsonDecode(encoded) as Map<String, dynamic>,
      ).construction;
      final f2 = decoded.byId('f')! as FreePoint;
      expect(f2.plane, same(decoded.byId('face')));
      expect(f2.spacePosition, f.spacePosition);
      expect(decoded.byId('co'), isA<ChartPoint>());
      final l2 = decoded.byId('l')! as LineThroughTwoPoints;
      expect(l2.sheet, Sheet.of(decoded.byId('face')! as GeoPlane));
      expect(l2.spaceLine!.closeTo(line.spaceLine!), isTrue);
      expect(jsonEncode(encodeDocument(decoded, viewport: viewport)), encoded);
    });

    test('leaves out an adapter nothing was built on', () {
      p.construction.add(ChartPoint(id: 'orphan', source: p.o, plane: p.face));
      final document = encodeDocument(p.construction, viewport: viewport);
      final ids = [
        for (final object in document['objects'] as List)
          (object as Map<String, dynamic>)['id'],
      ];
      expect(ids, isNot(contains('orphan')));
      expect(ids, contains('face'));
    });

    test('refuses a planar object whose parents are on two sheets', () {
      final f = FreePoint(id: 'f', position: const Vec2(1, 2), plane: p.face);
      final g = FreePoint(id: 'g', position: const Vec2(2, 2), plane: p.face);
      final circle = CompassCircle(
        id: 'k',
        radiusPoint1: f,
        radiusPoint2: g,
        center: f,
      );
      p.construction
        ..add(f)
        ..add(g)
        ..add(circle);
      final document = encodeDocument(p.construction, viewport: viewport);
      final objects = document['objects'] as List;
      final encoded = objects.firstWhere(
        (o) => (o as Map)['id'] == 'k',
      ) as Map<String, dynamic>;
      // Centre it on a base-plane point instead.
      encoded['parents'] = ['f', 'g', 'c'];
      expect(
        () => decodeDocument(document),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not in one plane'),
          ),
        ),
      );
    });
  });

  group('the acceptance figure: the slant height of the pyramid', () {
    // A square of side a with equilateral faces: h = a / √2.
    late Construction construction;
    late GeoPlane face;
    late GeoPoint foot;
    const side = 200.0;

    setUp(() {
      construction = decodeDocument(
        jsonDecode(
          File('test/space_fixtures/pyramid_skeleton.rgl').readAsStringSync(),
        ) as Map<String, dynamic>,
      ).construction;
      face = construction.byId('oab')! as GeoPlane;
      final apex = construction.byId('o')! as GeoPoint;
      final ab = construction.byId('s0')! as GeoLine;
      ToolInput tap(GeoObject hit) => ToolInput(
        Vec2.zero,
        hit: hit,
        objects: construction.objects,
        plane: face,
      );

      // In the face: the perpendicular from O to AB.
      final scope = PlaneScope();
      final perpendicular = PointAndLineTool(
        newId: newId,
        build: PerpendicularLine.new,
      );
      perpendicular.onInput(
        scope.adapt(tap(apex), perpendicular, newId).input!,
      );
      final dropped = perpendicular.onInput(
        scope.adapt(tap(ab), perpendicular, newId).input!,
      ) as ToolCommitted;
      scope.commit(dropped.command).apply(construction);
      final slant = construction.objects.last as GeoLine;

      // And where it meets AB.
      final meet = IntersectionTool(newId: newId)..onInput(tap(slant));
      (meet.onInput(tap(ab)) as ToolCommitted).command.apply(construction);
      foot = construction.objects.last as GeoPoint;
    });

    Vec3 at(String id) => (construction.byId(id)! as GeoPoint).spacePosition!;

    test('the foot is the midpoint of AB and |OH| = a√3/2', () {
      expect(foot.isDefined, isTrue);
      expect(
        foot.spacePosition!.distanceTo((at('a') + at('b')) * 0.5),
        lessThan(1e-9),
      );
      expect(
        foot.spacePosition!.distanceTo(at('o')),
        closeTo(side * math.sqrt(3) / 2, 1e-9),
      );
    });

    test('after a drag of A at the session level, it is still the foot of the '
        'perpendicular from O', () {
      final a = construction.byId('a')! as FreePoint;
      final session = DragSession.start(construction, a, Vec2.zero)!
        ..update(const Vec2(-20, 15))
        ..update(const Vec2(-60, 40));
      final command = session.end()!..apply(construction);

      final h = foot.spacePosition!;
      final along = at('b') - at('a');
      expect((at('o') - h).dot(along).abs(), lessThan(1e-6));
      expect(along.cross(h - at('a')).norm, lessThan(1e-6), reason: 'H on AB');
      expect(face.spacePlane!.contains(foot.spacePoint!, 1e-9), isTrue);

      command.undo(construction);
      expect(
        foot.spacePosition!.distanceTo(at('o')),
        closeTo(side * math.sqrt(3) / 2, 1e-9),
      );
    });
  });
}
