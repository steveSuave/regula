// Intent 004, milestone 3: a plane cuts a solid in a polygon, and the
// tool that asks for it.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/area_measurement.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/prism.dart';
import 'package:regula/domain/construction/objects/section_polygon.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/drag_session.dart';
import 'package:regula/domain/tools/regular_solid_tool.dart';
import 'package:regula/domain/tools/section_tool.dart';
import 'package:regula/domain/tools/space_slide_session.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/presentation/panels/object_kind_label.dart';

void main() {
  late Construction c;
  late Prism cube;
  late List<GeoPoint> corners;
  var ids = 0;
  String newId() => 'n${ids++}';

  /// The edge of the cube between corners [i] and [j].
  Segment edge(int i, int j) => c.objects.whereType<Segment>().firstWhere(
    (s) => {s.point1, s.point2}.containsAll([corners[i], corners[j]]),
  );

  /// A point glued to the edge from corner [i] to corner [j], [fraction]
  /// of the way along.
  PointOnObject glue(String id, int i, int j, double fraction) {
    final host = edge(i, j);
    final at =
        corners[i].spacePosition! +
        (corners[j].spacePosition! - corners[i].spacePosition!) * fraction;
    final planar = host.line;
    final point = planar != null
        ? PointOnObject(
            id: id,
            curve: host,
            parameter: planar.parameterAt(Vec2(at.x, at.y)),
          )
        : PointOnObject.onSpaceLine(
            id: id,
            curve: host,
            parameter: host.spaceParameterOf(at)!,
          );
    c.add(point);
    expect(point.spacePosition!.distanceTo(at), lessThan(1e-12));
    return point;
  }

  /// A cube of side 2 on the base plane: corners 0–3 the base, 4–7 over
  /// them.
  setUp(() {
    ids = 0;
    c = Construction();
    final tool = CubeTool(newId: newId)
      ..onInput(ToolInput(Vec2.zero, objects: c.objects));
    (tool.onInput(
      ToolInput(const Vec2(2, 0), objects: c.objects),
    ) as ToolCommitted).command.apply(c);
    cube = c.objects.whereType<Prism>().single;
    corners = [
      ...cube.base,
      cube.top,
      ...c.objects.whereType<TranslatedPoint>().where(
        (t) => identical(t.vectorTo, cube.top),
      ),
    ];
  });

  group('SectionPolygon', () {
    test('through three points on three edges at a corner it is a '
        'triangle, on the plane\'s sheet, with its area in space', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 0, 4, 0.5);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      final section = SectionPolygon(id: 's', plane: plane, solid: cube);
      c
        ..add(plane)
        ..add(section);
      expect(section.sideCount, 3);
      expect(section.sheet, Sheet.of(plane));
      expect(section.isDefined, isTrue);
      // Its vertices are the three glued points, in the plane's frame.
      final inSpace = section.spaceVertices!;
      for (final point in [p, q, r]) {
        expect(
          inSpace.any((v) => v.distanceTo(point.spacePosition!) < 1e-12),
          isTrue,
        );
      }
      final area = AreaMeasurement(id: 'a', subject: section);
      c.add(area);
      expect(area.value, closeTo(math.sqrt(3) / 2, 1e-12));
    });

    test('its side count changes as the plane moves through corners, and '
        'it is never undefined on the way', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 0, 4, 0.5);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      final section = SectionPolygon(id: 's', plane: plane, solid: cube);
      c
        ..add(plane)
        ..add(section);
      final session = SpaceSlideSession.start(c, r)!;
      final counts = <int>{};
      for (var t = 1.0; t <= 2.0; t += 0.01) {
        session.update(t);
        expect(section.isDefined, isTrue, reason: 'at $t');
        counts.add(section.sideCount);
      }
      // Past the end of the edge the point stops at the corner, and the
      // plane passes exactly through it: still a triangle, with that
      // corner once.
      session.update(5);
      expect(section.isDefined, isTrue);
      counts.add(section.sideCount);
      expect(counts, {3});
      session.end()!.apply(c);
      expect(r.spacePosition!.distanceTo(const Vec3(0, 0, 2)), lessThan(1e-12));
      expect(section.sideCount, 3);
      expect(objectKindLabel(section), 'Section (3 sides)');
    });

    test('a plane tilted across the cube gives a pentagon, then a hexagon', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 2, 6, 0.75);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      final section = SectionPolygon(id: 's', plane: plane, solid: cube);
      c
        ..add(plane)
        ..add(section);
      expect(section.sideCount, 5);
      // The regular hexagon: midpoints of AB, AD's opposite… the plane
      // through the cube's centre across its long diagonal.
      final u = glue('u', 0, 1, 0.5);
      final v = glue('v', 1, 5, 0.5);
      final w = glue('w3', 5, 6, 0.5);
      final across = ThreePointPlane(id: 'x', point1: u, point2: v, point3: w);
      final hexagon = SectionPolygon(id: 'h', plane: across, solid: cube);
      c
        ..add(across)
        ..add(hexagon);
      expect(hexagon.sideCount, 6);
      final area = AreaMeasurement(id: 'a', subject: hexagon);
      c.add(area);
      expect(area.value, closeTo(3 * math.sqrt(3), 1e-12));
      expect(objectKindLabel(hexagon), 'Section (6 sides)');
    });

    test('it follows a session-level drag of the cube, and a plane that '
        'has left the cube gives none', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 0, 4, 0.5);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      final section = SectionPolygon(id: 's', plane: plane, solid: cube);
      final area = AreaMeasurement(id: 'a', subject: section);
      c
        ..add(plane)
        ..add(section)
        ..add(area);
      final b = cube.base[1];
      final session = DragSession.start(c, b, b.position!)!
        ..update(const Vec2(3, 0))
        ..update(const Vec2(4, 0));
      session.end()!.apply(c);
      // The cube is now of side 4; the glued points keep their arc
      // length (1 from the corner), so the triangle is the same.
      expect(section.sideCount, 3);
      expect(area.value, closeTo(math.sqrt(3) / 2, 1e-9));

      // A plane well outside the solid.
      final far = [
        for (final (i, at) in const [
          Vec2(50, 50),
          Vec2(60, 50),
          Vec2(50, 60),
        ].indexed)
          FreePoint(id: 'f$i', position: at, height: 30),
      ];
      far.forEach(c.add);
      final outside = ThreePointPlane(
        id: 'o',
        point1: far[0],
        point2: far[1],
        point3: far[2],
      );
      final none = SectionPolygon(id: 'z', plane: outside, solid: cube);
      c
        ..add(outside)
        ..add(none);
      expect(none.isDefined, isFalse);
      expect(none.sideCount, 0);
      expect(objectKindLabel(none), 'Section (none)');
    });

    test('it is undefined while the solid is', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 0, 4, 0.5);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      final section = SectionPolygon(id: 's', plane: plane, solid: cube);
      c
        ..add(plane)
        ..add(section)
        ..setFreePointHeight(cube.base[0].id, 1);
      expect(section.isDefined, isFalse);
      c.setFreePointHeight(cube.base[0].id, 0);
      expect(section.sideCount, 3);
    });

    test('round-trips', () {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 2, 6, 0.75);
      final plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      c
        ..add(plane)
        ..add(SectionPolygon(id: 's', plane: plane, solid: cube));
      const viewport = ViewportState();
      final encoded = jsonEncode(encodeDocument(c, viewport: viewport));
      final decoded = decodeDocument(
        jsonDecode(encoded) as Map<String, dynamic>,
      ).construction;
      final again = decoded.byId('s')! as SectionPolygon;
      expect(again.sideCount, 5);
      expect(
        again.polygonVertices,
        (c.byId('s')! as SectionPolygon).polygonVertices,
      );
      expect(jsonEncode(encodeDocument(decoded, viewport: viewport)), encoded);
    });
  });

  group('SectionTool', () {
    late ThreePointPlane plane;

    setUp(() {
      final p = glue('p', 0, 1, 0.5);
      final q = glue('q', 0, 3, 0.5);
      final r = glue('r', 0, 4, 0.5);
      plane = ThreePointPlane(id: 'w', point1: p, point2: q, point3: r);
      c.add(plane);
    });

    ToolInput tap(List<GeoObject> hits) => ToolInput(
      Vec2.zero,
      hit: hits.firstOrNull,
      extraHits: hits.skip(1).toList(),
      objects: c.objects,
    );

    test('a plane then a solid, or a solid then a plane, is one section', () {
      for (final order in [
        [plane, cube],
        [cube, plane],
      ]) {
        final tool = SectionTool(newId: newId);
        expect(tool.onInput(tap([order[0]])), isA<ToolAccepted>());
        expect(tool.previewObjectIds, [order[0].id]);
        final done = tool.onInput(tap([order[1]])) as ToolCommitted;
        final section =
            (done.command as AddObjectCommand).object as SectionPolygon;
        expect(section.plane, same(plane));
        expect(section.solid, same(cube));
        expect(section.attributes.fillAlpha, SectionTool.defaultFillAlpha);
        expect(tool.hasPartialInput, isFalse);
      }
    });

    test('a tap takes the kind still missing from everything under it', () {
      final tool = SectionTool(newId: newId);
      // The solid is on top both times.
      expect(tool.onInput(tap([cube, plane])), isA<ToolAccepted>());
      expect(tool.onInput(tap([cube, plane])), isA<ToolCommitted>());
    });

    test('a tap on neither, a second solid, and the same cut twice are '
        'ignored', () {
      final tool = SectionTool(newId: newId);
      expect(tool.onInput(tap([])), isA<ToolIgnored>());
      expect(tool.onInput(tap([corners[0]])), isA<ToolIgnored>());
      tool.onInput(tap([cube]));
      expect(tool.onInput(tap([cube])), isA<ToolIgnored>());
      (tool.onInput(tap([plane])) as ToolCommitted).command.apply(c);
      tool.onInput(tap([cube]));
      expect(tool.onInput(tap([plane])), isA<ToolIgnored>());
      expect(c.objects.whereType<SectionPolygon>(), hasLength(1));
    });
  });
}
