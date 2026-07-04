@Tags(['golden'])
library;

import 'package:fgex/application/providers/viewport_provider.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/angle_bisector_line.dart';
import 'package:fgex/domain/construction/objects/arc.dart';
import 'package:fgex/domain/construction/objects/centroid.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/circumcenter.dart';
import 'package:fgex/domain/construction/objects/compass_circle.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/incenter.dart';
import 'package:fgex/domain/construction/objects/intersection_point.dart';
import 'package:fgex/domain/construction/objects/line_angle.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/orthocenter.dart';
import 'package:fgex/domain/construction/objects/parallel_line.dart';
import 'package:fgex/domain/construction/objects/perpendicular_line.dart';
import 'package:fgex/domain/construction/objects/point_on_object.dart';
import 'package:fgex/domain/construction/objects/ray.dart';
import 'package:fgex/domain/construction/objects/sector.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/construction/objects/segment_ratio_point.dart';
import 'package:fgex/domain/construction/objects/three_point_circle.dart';
import 'package:fgex/domain/construction/objects/vertex_angle.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/presentation/canvas/canvas_viewport.dart';
import 'package:fgex/presentation/canvas/fit_viewport.dart';
import 'package:fgex/presentation/canvas/geometry_painter.dart';
import 'package:fgex/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel goldens for every concrete object kind, light + dark — one scene
/// per sealed kind plus a decorations scene (labels, custom attributes,
/// selection halos, preview markers).
///
/// Goldens are rendered with the test framework's default font (Ahem), so
/// labels appear as solid boxes: position and metrics are locked, glyph
/// shapes are not. Regenerate on macOS with
/// `flutter test --update-goldens --tags golden`; CI excludes the tag.
void main() {
  const hidden = ObjectAttributes(visible: false);
  const canvasSize = Size(640, 480);
  const sceneKey = ValueKey('golden-scene');

  Future<void> expectSceneGolden(
    WidgetTester tester, {
    required Construction construction,
    required ThemeData theme,
    required String golden,
    Set<String> selectedIds = const {},
    List<Vec2> previewMarkers = const [],
  }) async {
    final viewportState = fittedViewport(construction.objects, canvasSize) ??
        const ViewportState();
    final painter = GeometryPainter(
      construction: construction,
      viewport: CanvasViewport(viewportState),
      revision: 0,
      defaultColor: theme.colorScheme.primary,
      selectionColor: theme.colorScheme.tertiary,
      selectedIds: selectedIds,
      previewMarkers: previewMarkers,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: sceneKey,
              // The real canvas paints over the scaffold; the golden's
              // boundary needs its own background to capture that surface.
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: SizedBox.fromSize(
                  size: canvasSize,
                  child: CustomPaint(painter: painter),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(sceneKey),
      matchesGoldenFile('goldens/$golden.png'),
    );
  }

  /// Every point kind: three visible free points spanning a triangle, the
  /// derived points over them, and hidden scaffolding (an extra free
  /// point, two lines, a circle) for the kinds that need curve parents.
  Construction pointsScene() {
    final construction = Construction();
    final a = FreePoint(id: 'a', position: Vec2.zero);
    final b = FreePoint(id: 'b', position: const Vec2(8, 0));
    final c = FreePoint(id: 'c', position: const Vec2(2, 6));
    final d = FreePoint(id: 'd', position: const Vec2(8, 4), attributes: hidden);
    final lineAd =
        LineThroughTwoPoints(id: 'lad', point1: a, point2: d, attributes: hidden);
    final lineBc =
        LineThroughTwoPoints(id: 'lbc', point1: b, point2: c, attributes: hidden);
    final circle =
        CircleCenterPoint(id: 'k', center: d, onCircle: b, attributes: hidden);
    construction
      ..add(a)
      ..add(b)
      ..add(c)
      ..add(d)
      ..add(lineAd)
      ..add(lineBc)
      ..add(circle)
      ..add(Midpoint(id: 'm', point1: a, point2: b))
      ..add(SegmentRatioPoint(id: 'sr', point1: a, point2: c, ratio: 0.75))
      ..add(Centroid(id: 'ce', vertex1: a, vertex2: b, vertex3: c))
      ..add(Orthocenter(id: 'or', vertex1: a, vertex2: b, vertex3: c))
      ..add(Incenter(id: 'ic', vertex1: a, vertex2: b, vertex3: c))
      ..add(Circumcenter(id: 'cc', vertex1: a, vertex2: b, vertex3: c))
      ..add(IntersectionPoint(
          id: 'x', curve1: lineAd, curve2: lineBc, branchIndex: 0))
      ..add(PointOnObject(id: 'po', curve: circle, parameter: 0.7));
    return construction;
  }

  /// Every line kind over three visible anchor points.
  Construction linesScene() {
    final construction = Construction();
    final a = FreePoint(id: 'a', position: Vec2.zero);
    final b = FreePoint(id: 'b', position: const Vec2(6, 0));
    final c = FreePoint(id: 'c', position: const Vec2(1, 4));
    final segment = Segment(id: 's', point1: a, point2: b);
    final ray = Ray(id: 'r', origin: a, through: c);
    construction
      ..add(a)
      ..add(b)
      ..add(c)
      ..add(segment)
      ..add(ray)
      ..add(LineThroughTwoPoints(id: 'l', point1: b, point2: c))
      ..add(PerpendicularLine(id: 'pp', through: c, reference: segment))
      ..add(ParallelLine(id: 'pl', through: b, reference: ray))
      ..add(AngleBisectorLine(id: 'ab', arm1: b, vertex: a, arm2: c));
    return construction;
  }

  /// Every circle kind, spread out so the carriers stay distinguishable.
  Construction circlesScene() {
    final construction = Construction();
    final o = FreePoint(id: 'o', position: Vec2.zero);
    final p = FreePoint(id: 'p', position: const Vec2(3, 0));
    final p1 = FreePoint(id: 'p1', position: const Vec2(7, 0));
    final p2 = FreePoint(id: 'p2', position: const Vec2(11, 2));
    final p3 = FreePoint(id: 'p3', position: const Vec2(9, 4));
    final r1 = FreePoint(id: 'r1', position: const Vec2(0, 6));
    final r2 = FreePoint(id: 'r2', position: const Vec2(2, 6));
    final k = FreePoint(id: 'k', position: const Vec2(5, 7));
    final s1 = FreePoint(id: 's1', position: const Vec2(-2, -4));
    final s2 = FreePoint(id: 's2', position: const Vec2(0, -2));
    final s3 = FreePoint(id: 's3', position: const Vec2(2, -4));
    final t = FreePoint(id: 't', position: const Vec2(9, -4));
    final u = FreePoint(id: 'u', position: const Vec2(11, -4));
    final v = FreePoint(id: 'v', position: const Vec2(9, -1));
    construction
      ..add(o)
      ..add(p)
      ..add(p1)
      ..add(p2)
      ..add(p3)
      ..add(r1)
      ..add(r2)
      ..add(k)
      ..add(s1)
      ..add(s2)
      ..add(s3)
      ..add(t)
      ..add(u)
      ..add(v)
      ..add(CircleCenterPoint(id: 'c1', center: o, onCircle: p))
      ..add(ThreePointCircle(id: 'c2', point1: p1, point2: p2, point3: p3))
      ..add(CompassCircle(
          id: 'c3', radiusPoint1: r1, radiusPoint2: r2, center: k))
      ..add(Arc(id: 'arc', start: s1, via: s2, end: s3))
      ..add(Sector(id: 'sec', center: t, start: u, end: v));
    return construction;
  }

  /// Both angle kinds: a directed vertex angle and the always-acute angle
  /// between two crossing lines.
  Construction anglesScene() {
    final construction = Construction();
    final arm1 = FreePoint(id: 'a1', position: const Vec2(4, 0));
    final vertex = FreePoint(id: 'vx', position: Vec2.zero);
    final arm2 = FreePoint(id: 'a2', position: const Vec2(1, 3));
    final e = FreePoint(id: 'e', position: const Vec2(6, 0));
    final f = FreePoint(id: 'f', position: const Vec2(10, 3));
    final g = FreePoint(id: 'g', position: const Vec2(6, 3));
    final h = FreePoint(id: 'h', position: const Vec2(10, 0));
    final line1 = LineThroughTwoPoints(id: 'l1', point1: e, point2: f);
    final line2 = LineThroughTwoPoints(id: 'l2', point1: g, point2: h);
    construction
      ..add(arm1)
      ..add(vertex)
      ..add(arm2)
      ..add(e)
      ..add(f)
      ..add(g)
      ..add(h)
      ..add(line1)
      ..add(line2)
      ..add(VertexAngle(id: 'va', arm1: arm1, vertex: vertex, arm2: arm2))
      ..add(LineAngle(id: 'la', line1: line1, line2: line2));
    return construction;
  }

  /// Attribute and overlay rendering: a label, custom color / stroke /
  /// point size, a filled sector, selection halos and preview markers.
  Construction decorationsScene() {
    final construction = Construction();
    final a = FreePoint(
      id: 'a',
      position: Vec2.zero,
      attributes: const ObjectAttributes(name: 'A'),
    );
    final b = FreePoint(id: 'b', position: const Vec2(4, 0));
    final c = FreePoint(id: 'c', position: const Vec2(4, 3));
    final center = FreePoint(id: 'k', position: const Vec2(8, 2));
    final rim = FreePoint(id: 'rim', position: const Vec2(10, 2));
    final secEnd = FreePoint(id: 'se', position: const Vec2(8, 4));
    construction
      ..add(a)
      ..add(b)
      ..add(c)
      ..add(center)
      ..add(rim)
      ..add(secEnd)
      ..add(Segment(
        id: 's',
        point1: b,
        point2: c,
        attributes:
            const ObjectAttributes(colorArgb: 0xFFE64A19, strokeWidth: 4),
      ))
      ..add(FreePoint(
        id: 'big',
        position: const Vec2(2, 3),
        attributes:
            const ObjectAttributes(colorArgb: 0xFF2E7D32, pointSize: 8),
      ))
      ..add(CircleCenterPoint(id: 'circ', center: center, onCircle: rim))
      ..add(Sector(
        id: 'fill',
        center: center,
        start: rim,
        end: secEnd,
        attributes: const ObjectAttributes(fillAlpha: 0.25),
      ));
    return construction;
  }

  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  final scenes = {
    'points': pointsScene,
    'lines': linesScene,
    'circles': circlesScene,
    'angles': anglesScene,
  };

  for (final MapEntry(key: themeName, value: theme) in themes.entries) {
    for (final MapEntry(key: sceneName, value: buildScene) in scenes.entries) {
      testWidgets('$sceneName scene — $themeName', (tester) async {
        await expectSceneGolden(
          tester,
          construction: buildScene(),
          theme: theme,
          golden: '${sceneName}_$themeName',
        );
      });
    }

    testWidgets('decorations scene — $themeName', (tester) async {
      await expectSceneGolden(
        tester,
        construction: decorationsScene(),
        theme: theme,
        golden: 'decorations_$themeName',
        selectedIds: const {'k', 'circ'},
        previewMarkers: const [Vec2(0, 4), Vec2(2, 5)],
      );
    });
  }
}
