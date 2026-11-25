// Intent 004, milestone 3: a face of a solid as a plane to work in.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/chart_point.dart';
import 'package:regula/domain/construction/objects/face_plane.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/prism.dart';
import 'package:regula/domain/construction/objects/pyramid.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/segment_ratio_point.dart';
import 'package:regula/domain/construction/objects/three_point_circle.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/construction/space_incidence.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/plane_scope.dart';
import 'package:regula/domain/tools/regular_solid_tool.dart';
import 'package:regula/domain/tools/three_point_tool.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late Construction c;
  late Prism cube;
  late List<GeoPoint> corners;
  var ids = 0;
  String newId() => 'n${ids++}';

  /// A cube of side 4 on the base plane, built by its tool: corners 0–3
  /// the base, 4–7 the far end.
  setUp(() {
    ids = 0;
    c = Construction();
    final tool = CubeTool(newId: newId)
      ..onInput(ToolInput(Vec2.zero, objects: c.objects));
    (tool.onInput(
      ToolInput(const Vec2(4, 0), objects: c.objects),
    ) as ToolCommitted).command.apply(c);
    cube = c.objects.whereType<Prism>().single;
    final far = [
      cube.top,
      ...c.objects.whereType<TranslatedPoint>().where(
        (t) => identical(t.vectorTo, cube.top),
      ),
    ];
    corners = [...cube.base, ...far];
    for (var i = 0; i < 8; i++) {
      expect(corners[i].spacePosition, cube.spaceVertices![i], reason: '$i');
    }
  });

  group('FacePlane', () {
    test('has the face\'s first corner as origin, its first edge as u, and '
        'is scaffolding', () {
      // Face 2 is the side over base edge 0: corners 0, 1, 5, 4.
      final side = FacePlane(id: 'f', solid: cube, face: 2);
      final frame = side.frame!;
      expect(frame.origin, const Vec3(0, 0, 0));
      expect(frame.u, const Vec3(1, 0, 0));
      expect(frame.normal.z.abs(), lessThan(1e-12));
      expect(side.isInternal, isTrue);
      expect(side.isDefined, isTrue);
      expect(side.parents, [cube]);
      for (final i in cube.faces[2]) {
        expect(frame.heightOf(cube.spaceVertices![i]).abs(), lessThan(1e-12));
      }
    });

    test('follows the solid without being in the construction', () {
      final lid = FacePlane(id: 'f', solid: cube, face: 1);
      expect(lid.frame!.origin, const Vec3(0, 0, 4));
      c.moveFreePoint(cube.base[1].id, const Vec2(0, 2));
      expect(lid.frame!.origin.distanceTo(const Vec3(0, 0, 2)), lessThan(1e-9));
    });

    test('is undefined while the solid is', () {
      final lid = FacePlane(id: 'f', solid: cube, face: 1);
      c.setFreePointHeight(cube.base[0].id, 1);
      expect(cube.isDefined, isFalse);
      expect(lid.isDefined, isFalse);
    });

    test('refuses a face the solid does not have', () {
      expect(
        () => FacePlane(id: 'f', solid: cube, face: 6),
        throwsArgumentError,
      );
    });
  });

  group('lying in a face by construction', () {
    test('a face holds its own corners and no others', () {
      for (var f = 0; f < cube.faces.length; f++) {
        final plane = FacePlane(id: 'f$f', solid: cube, face: f);
        for (var i = 0; i < 8; i++) {
          expect(
            liesIn(corners[i], plane),
            cube.faces[f].contains(i),
            reason: 'corner $i, face $f',
          );
        }
      }
    });

    test('a pyramid\'s faces hold its base corners and its apex', () {
      final apex = FreePoint(id: 'o', position: const Vec2(1, 1), height: 5);
      c.add(apex);
      final pyramid = Pyramid(id: 'py', base: cube.base, apex: apex);
      c.add(pyramid);
      final side = FacePlane(id: 's', solid: pyramid, face: 1);
      expect(liesIn(apex, side), isTrue);
      expect(liesIn(cube.base[0], side), isTrue);
      expect(liesIn(cube.base[1], side), isTrue);
      expect(liesIn(cube.base[2], side), isFalse);
      expect(
        liesIn(apex, FacePlane(id: 'b', solid: pyramid, face: 0)),
        isFalse,
      );
    });

    test('an edge of the face, a point glued to it, a midpoint and a '
        'ratio point on it are in the face', () {
      final lid = FacePlane(id: 'f', solid: cube, face: 1);
      final edge = c.objects.whereType<Segment>().firstWhere(
        (s) => {s.point1, s.point2}.containsAll([corners[4], corners[5]]),
      );
      expect(liesIn(edge, lid), isTrue);
      final glued = PointOnObject(id: 'g', curve: edge, parameter: 1);
      final middle = Midpoint(id: 'm', point1: corners[4], point2: corners[6]);
      final third = SegmentRatioPoint(
        id: 'r',
        point1: corners[5],
        point2: corners[7],
        ratio: 1 / 3,
      );
      expect(liesIn(glued, lid), isTrue);
      expect(liesIn(middle, lid), isTrue);
      expect(liesIn(third, lid), isTrue);
      // An upright edge is not in the lid, nor a point on it.
      final upright = c.objects.whereType<Segment>().firstWhere(
        (s) => {s.point1, s.point2}.containsAll([corners[0], corners[4]]),
      );
      expect(liesIn(upright, lid), isFalse);
      expect(
        liesIn(PointOnObject(id: 'h', curve: upright, parameter: 4), lid),
        isFalse,
      );
    });

    test('a point that is in the face only by where it is, is not', () {
      final lid = FacePlane(id: 'f', solid: cube, face: 1);
      final floating = FreePoint(
        id: 'x',
        position: const Vec2(1, 1),
        height: 4,
      );
      expect(lid.frame!.heightOf(floating.spacePosition!).abs(), 0);
      expect(liesIn(floating, lid), isFalse);
    });

    test('a translation of a point of a plane by a vector in it stays in '
        'it', () {
      final lid = FacePlane(id: 'f', solid: cube, face: 1);
      final moved = TranslatedPoint(
        id: 't',
        point: corners[4],
        vectorFrom: corners[5],
        vectorTo: corners[7],
      );
      expect(liesIn(moved, lid), isTrue);
      final out = TranslatedPoint(
        id: 'u',
        point: corners[4],
        vectorFrom: corners[5],
        vectorTo: corners[1],
      );
      expect(liesIn(out, lid), isFalse);
    });
  });

  group('building in a face', () {
    ThreePointTool circleTool() => ThreePointTool(
      newId: newId,
      build: (id, p1, p2, p3) =>
          ThreePointCircle(id: id, point1: p1, point2: p2, point3: p3),
    );

    ToolInput tap(GeoObject hit, GeoPlane plane) =>
        ToolInput(Vec2.zero, hit: hit, objects: c.objects, plane: plane);

    test('the first circle in a face is one command holding the face\'s '
        'plane, three adapters and the circle; one undo removes all five', () {
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final scope = PlaneScope();
      final tool = circleTool();
      final before = c.objects.length;
      for (final corner in [corners[4], corners[5]]) {
        final seen = scope.adapt(tap(corner, lid), tool, newId);
        expect(seen.refusal, isNull);
        expect(tool.onInput(seen.input!), isA<ToolAccepted>());
      }
      final last = scope.adapt(tap(corners[6], lid), tool, newId);
      final committed = tool.onInput(last.input!) as ToolCommitted;
      final whole = scope.commit(committed.command) as MacroCommand;
      expect(
        [
          for (final command in whole.commands)
            (command as AddObjectCommand).object.runtimeType,
        ],
        [FacePlane, ChartPoint, ChartPoint, ChartPoint, ThreePointCircle],
      );
      whole.apply(c);
      final circle = c.objects.whereType<ThreePointCircle>().single;
      expect(circle.sheet, Sheet.of(lid));
      expect(circle.isDefined, isTrue);
      // The circumcircle of the lid: radius half its diagonal.
      expect(circle.circle!.radius, closeTo(2 * 1.4142135623730951, 1e-9));
      whole.undo(c);
      expect(c.objects, hasLength(before));
    });

    test('a second construction in that face reuses the plane and the '
        'adapters', () {
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final scope = PlaneScope();
      void circleOn(List<GeoPoint> three) {
        final tool = circleTool();
        late ToolResult result;
        for (final corner in three) {
          result = tool.onInput(
            scope.adapt(tap(corner, lid), tool, newId).input!,
          );
        }
        scope.commit((result as ToolCommitted).command).apply(c);
      }

      circleOn([corners[4], corners[5], corners[6]]);
      final after = c.objects.length;
      circleOn([corners[4], corners[5], corners[7]]);
      // One new adapter and one circle.
      expect(c.objects, hasLength(after + 2));
      expect(c.objects.whereType<FacePlane>(), hasLength(1));
    });

    test('a corner of another face is refused', () {
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final scope = PlaneScope();
      final seen = scope.adapt(tap(corners[0], lid), circleTool(), newId);
      expect(seen.refusal, ScopeRefusal.notInPlane);
    });

    test('a tool that needs no plane still brings the face\'s plane with a '
        'point it places there', () {
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final scope = PlaneScope();
      final placed = FreePoint(id: 'p', position: const Vec2(1, 1), plane: lid);
      // A space-scoped tool: its input is not adapted, its commit is.
      scope.adapt(
        ToolInput(const Vec2(1, 1), objects: c.objects, plane: lid),
        CubeTool(newId: newId),
        newId,
      );
      final whole = scope.commit(AddObjectCommand(placed)) as MacroCommand;
      expect(whole.commands, hasLength(2));
      whole.apply(c);
      expect(placed.spacePosition, const Vec3(1, 1, 4));
    });
  });

  group('the save format', () {
    const viewport = ViewportState();

    test('a face plane nothing was built in is not written; one that was, '
        'is, and reads back', () {
      final unused = FacePlane(id: 'unused', solid: cube, face: 3);
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final orphan = ChartPoint(
        id: 'orphan',
        source: corners[4],
        plane: unused,
      );
      final placed = FreePoint(id: 'p', position: const Vec2(1, 1), plane: lid);
      c
        ..add(unused)
        ..add(orphan)
        ..add(lid)
        ..add(placed);
      final encoded = jsonEncode(encodeDocument(c, viewport: viewport));
      expect(encoded, isNot(contains('"unused"')));
      expect(encoded, isNot(contains('"orphan"')));
      final decoded = decodeDocument(
        jsonDecode(encoded) as Map<String, dynamic>,
      ).construction;
      final again = decoded.byId('lid')! as FacePlane;
      expect(again.face, 1);
      expect(again.solid.id, cube.id);
      expect(
        (decoded.byId('p')! as FreePoint).spacePosition,
        const Vec3(1, 1, 4),
      );
      expect(jsonEncode(encodeDocument(decoded, viewport: viewport)), encoded);
    });

    test('a face the solid does not have is a format error', () {
      c.add(FacePlane(id: 'lid', solid: cube, face: 1));
      c.add(
        FreePoint(
          id: 'p',
          position: const Vec2(1, 1),
          plane: c.byId('lid')! as GeoPlane,
        ),
      );
      final document = encodeDocument(c, viewport: viewport);
      final objects = (document['objects'] as List)
          .cast<Map<String, dynamic>>();
      (objects.firstWhere((o) => o['id'] == 'lid')['params']
              as Map<String, dynamic>)['face'] =
          9;
      expect(
        () => decodeDocument(
          jsonDecode(jsonEncode(document)) as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    });
  });
}
