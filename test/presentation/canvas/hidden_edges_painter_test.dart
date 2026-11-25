// Intent 004, milestone 3: the painter dashes straight ink behind a face
// of a solid, in the space view, and nothing else.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/change_attributes_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/face_plane.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/prism.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/regular_solid_tool.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/hidden_line.dart';

const _size = Size(800, 600);

/// Strokes as the painter hands them over: whole lines, and dashed
/// paths with the opacity they were drawn at.
class _StrokeRecorder implements Canvas {
  final List<(Offset, Offset)> lines = [];
  final List<({Rect bounds, double alpha})> dashed = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  void drawPath(Path path, Paint paint) {
    if (paint.style == PaintingStyle.stroke) {
      dashed.add((bounds: path.getBounds(), alpha: paint.color.a));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Construction c;
  late Prism cube;
  late List<GeoPoint> corners;
  var ids = 0;
  String newId() => 'n${ids++}';

  CanvasViewport camera({double tilt = math.pi / 3, double rotation = -0.5}) =>
      CanvasViewport(
        ViewportState(
          pan: const Vec2(-400, 300),
          tilt: tilt,
          rotation: rotation,
        ),
      );

  _StrokeRecorder paint(CanvasViewport viewport) {
    final recorder = _StrokeRecorder();
    GeometryPainter(
      construction: c,
      viewport: viewport,
      revision: 0,
      defaultColor: const Color(0xFF000000),
      selectionColor: const Color(0xFF0000FF),
      selectedIds: const {},
      highlightedIds: const {},
    ).paint(recorder, _size);
    return recorder;
  }

  /// A cube of side 100 near the middle of the canvas.
  setUp(() {
    ids = 0;
    c = Construction();
    final tool = CubeTool(newId: newId)
      ..onInput(ToolInput(const Vec2(-50, -50), objects: c.objects));
    (tool.onInput(
      ToolInput(const Vec2(50, -50), objects: c.objects),
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

  /// The cube's corner farthest from the viewer.
  int farCorner(CanvasViewport viewport) {
    var far = 0;
    for (var i = 1; i < 8; i++) {
      if (viewport.depthOf(cube.spaceVertices![i]) <
          viewport.depthOf(cube.spaceVertices![far])) {
        far = i;
      }
    }
    return far;
  }

  test('a cube seen obliquely has its three back edges dashed and dimmed, '
      'and the other nine whole', () {
    for (final rotation in [-0.5, 0.4, 2.0, -2.6]) {
      final viewport = camera(rotation: rotation);
      final strokes = paint(viewport);
      expect(strokes.lines, hasLength(9), reason: 'rotation $rotation');
      expect(strokes.dashed, hasLength(3), reason: 'rotation $rotation');
      // The three meet at the corner farthest from the viewer.
      final far = viewport.spaceToScreen(
        cube.spaceVertices![farCorner(viewport)],
      );
      for (final stroke in strokes.dashed) {
        expect(stroke.alpha, closeTo(hiddenInkAlpha, 1e-6));
        expect(stroke.bounds.inflate(hiddenDashPeriod).contains(far), isTrue);
      }
    }
  });

  test('seen from below, the three edges at the top far corner are the '
      'hidden ones', () {
    final viewport = camera(tilt: 2.2);
    final strokes = paint(viewport);
    expect(strokes.lines, hasLength(9));
    expect(strokes.dashed, hasLength(3));
    expect(farCorner(viewport), greaterThanOrEqualTo(4));
  });

  test('looking straight down nothing is dashed', () {
    final strokes = paint(camera(tilt: 0, rotation: 0));
    expect(strokes.dashed, isEmpty);
    expect(strokes.lines, hasLength(12));
  });

  test('a solid made invisible hides nothing: the wireframe', () {
    ChangeAttributesCommand({cube.id: cube.attributes.copyWith(visible: false)})
        .apply(c);
    final strokes = paint(camera());
    expect(strokes.dashed, isEmpty);
    expect(strokes.lines, hasLength(12));
  });

  test('with no solid the strokes are the ones they always were', () {
    final plain = Construction();
    final a = FreePoint(id: 'a', position: const Vec2(-50, -50));
    final b = FreePoint(id: 'b', position: const Vec2(50, -50));
    final up = FreePoint(id: 'u', position: const Vec2(0, 20), height: 80);
    plain
      ..add(a)
      ..add(b)
      ..add(up)
      ..add(Segment(id: 'ab', point1: a, point2: b))
      ..add(Segment(id: 'au', point1: a, point2: up));
    c = plain;
    final viewport = camera();
    final strokes = paint(viewport);
    expect(strokes.dashed, isEmpty);
    expect(strokes.lines, [
      (
        viewport.worldToScreen(const Vec2(-50, -50)),
        viewport.worldToScreen(const Vec2(50, -50)),
      ),
      (
        viewport.spaceToScreen(const Vec3(-50, -50, 0)),
        viewport.spaceToScreen(const Vec3(0, 20, 80)),
      ),
    ]);
  });

  test('a segment that passes behind the cube is dashed where the cube '
      'covers it, and a user-dashed one keeps its own dashes there', () {
    final viewport = camera();
    // A long segment on the base plane, behind the cube from here.
    final back =
        viewport.depthOf(const Vec3(0, 400, 0)) <
            viewport.depthOf(const Vec3(0, -400, 0))
        ? 1.0
        : -1.0;
    final p = FreePoint(id: 'p', position: Vec2(-400, 150 * back));
    final q = FreePoint(id: 'q', position: Vec2(400, 150 * back));
    c
      ..add(p)
      ..add(q)
      ..add(Segment(id: 'pq', point1: p, point2: q));
    final strokes = paint(viewport);
    // Its visible ends are two more whole lines; its covered middle one
    // more dashed stroke.
    expect(strokes.lines, hasLength(11));
    expect(strokes.dashed, hasLength(4));
  });

  group('the grid in the active plane', () {
    int gridLines({required bool showGrid, GeoPlane? active}) {
      final recorder = _StrokeRecorder();
      GeometryPainter(
        construction: c,
        viewport: camera(),
        revision: 0,
        defaultColor: const Color(0xFF000000),
        selectionColor: const Color(0xFF0000FF),
        selectedIds: const {},
        highlightedIds: const {},
        showGrid: showGrid,
        activePlaneId: active?.id,
        activePlane: active,
      ).paint(recorder, _size);
      // Twelve edges, three of them dashed: nine whole lines are edges.
      return recorder.lines.length - 9;
    }

    test('is drawn in an active face, in its own coordinates, and only '
        'while the grid is shown', () {
      final lid = FacePlane(id: 'lid', solid: cube, face: 1);
      final baseOnly = gridLines(showGrid: true);
      final withFace = gridLines(showGrid: true, active: lid);
      expect(baseOnly, greaterThan(0));
      // A face 100 across at the default step: a handful of lines each
      // way, and not one more with the grid off.
      expect(withFace - baseOnly, inInclusiveRange(4, 40));
      expect(gridLines(showGrid: false, active: lid), 0);
    });
  });

  test('a diagonal drawn in the nearest face is not hidden by it', () {
    final viewport = camera();
    // The top face is towards the viewer from above.
    c.add(Segment(id: 'diag', point1: corners[4], point2: corners[6]));
    final strokes = paint(viewport);
    expect(strokes.lines, hasLength(10));
    expect(strokes.dashed, hasLength(3));
  });
}
