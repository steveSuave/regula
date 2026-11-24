import 'dart:typed_data';
import 'dart:ui';

import 'canvas_viewport.dart';
import 'dash_path.dart';

/// The canvas the painter draws the base plane on.
///
/// The painter computes every coordinate in the **planar frame**
/// (`CanvasViewport.flat`): the picture the document has with the camera
/// looking straight down. This adapter carries that picture to the screen
/// through the viewport's sheet map, and it knows two kinds of mark:
///
/// - **In-plane geometry** — [drawLine], [drawCircle], [drawArc],
///   [drawPath], [drawRect]. The *path* is transformed and then stroked or
///   filled on the untransformed canvas, so a circle foreshortens to an
///   ellipse while its stroke keeps its width, and dashes are cut after
///   the transform so they keep their length.
/// - **Sprites** — [drawDot], and text painted on [screen] at
///   [toScreen] of its anchor. Only the anchor moves; a point's dot stays
///   round and a label stays upright.
///
/// **At the identity it is not there.** With the camera not tilted every
/// call forwards to the canvas unchanged — `drawCircle` stays `drawCircle`,
/// a dashed path is dashed exactly as before — which is what keeps the
/// planar app's pixels, and its goldens, where they were. Wrapping the
/// paint in `canvas.transform` instead would be one line, and it would
/// squash strokes, dots and text along with the geometry.
/// DECISIONS §"The space view is a camera over one document".
class SheetCanvas {
  SheetCanvas(this.screen, CanvasViewport viewport)
    : _viewport = viewport,
      _matrix = viewport.isTilted ? viewport.sheetMatrix : null;

  /// The real canvas, in real screen coordinates — for sprites and for
  /// anything that is not on the sheet at all.
  final Canvas screen;

  final CanvasViewport _viewport;

  /// Null at the identity.
  final Float64List? _matrix;

  bool get isIdentity => _matrix == null;

  /// Where a planar-frame point lands on screen.
  Offset toScreen(Offset flat) => _viewport.sheetToScreen(flat);

  /// A planar-frame path on screen; [path] itself at the identity.
  Path mapPath(Path path) {
    final matrix = _matrix;
    return matrix == null ? path : path.transform(matrix);
  }

  void drawLine(Offset from, Offset to, Paint paint) {
    if (isIdentity) {
      screen.drawLine(from, to, paint);
    } else {
      // An affine map takes a line to a line: no path is needed.
      screen.drawLine(toScreen(from), toScreen(to), paint);
    }
  }

  /// A circle lying in the plane, by [paint]'s style its rim or its disc.
  void drawCircle(Offset center, double radius, Paint paint) {
    if (isIdentity) {
      screen.drawCircle(center, radius, paint);
    } else {
      screen.drawPath(
        mapPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        ),
        paint,
      );
    }
  }

  /// A round mark of fixed screen [radius] at a planar-frame [center].
  void drawDot(Offset center, double radius, Paint paint) =>
      screen.drawCircle(toScreen(center), radius, paint);

  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    if (isIdentity) {
      screen.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
      return;
    }
    final path = Path();
    if (useCenter) {
      path.moveTo(rect.center.dx, rect.center.dy);
    }
    path.arcTo(rect, startAngle, sweepAngle, !useCenter);
    if (useCenter) {
      path.close();
    }
    screen.drawPath(mapPath(path), paint);
  }

  /// Draws [path]; with [dashPeriod] > 0, dashed — cut on screen, after
  /// the sheet map, so every dash has its full length at any tilt.
  void drawPath(Path path, Paint paint, {double dashPeriod = 0}) {
    final mapped = mapPath(path);
    screen.drawPath(
      dashPeriod > 0 ? dashPath(mapped, dashPeriod) : mapped,
      paint,
    );
  }

  void drawRect(Rect rect, Paint paint) {
    if (isIdentity) {
      screen.drawRect(rect, paint);
    } else {
      screen.drawPath(mapPath(Path()..addRect(rect)), paint);
    }
  }
}
