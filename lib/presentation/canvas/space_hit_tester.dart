import 'dart:ui';

import '../../domain/construction/geo_object.dart';
import 'canvas_viewport.dart';
import 'screen_figure.dart';

/// Hit testing for the space view, in screen pixels (intent 004,
/// milestone 2).
///
/// `CanvasHitTester` measures in world units on the base plane, which is
/// the right question while the view is the plan: a world disc is a
/// screen disc. Turn the camera and it is not — the disc is an ellipse,
/// and an object off the plane has no world point under the pointer at
/// all. So here each object is turned into its screen ink
/// ([screenInkOf]) and the pointer is measured against that.
///
/// The order is the planar tester's, with depth added: kind priority
/// first (a point beats a curve beats a line beats a polygon), then
/// distance, then the latest inserted. Between two objects of one
/// priority whose distances are within [depthBand] pixels of each
/// other, the one nearer the viewer wins — two edges that cross on
/// screen are not usefully ranked by a pixel of pointer placement.
class SpaceHitTester {
  const SpaceHitTester();

  /// The width of a distance band inside which depth decides.
  static const double depthBand = 4;

  /// Every object within [thresholdPx] of [pointer], best first.
  List<GeoObject> hitTestAll(
    Iterable<GeoObject> objects,
    CanvasViewport viewport,
    Size canvasSize,
    Offset pointer,
    double thresholdPx, {
    bool includeHidden = false,
  }) {
    final candidates =
        <
          ({
            GeoObject object,
            int priority,
            double distance,
            double depth,
            int index,
          })
        >[];
    var index = 0;
    for (final object in objects) {
      index++;
      if ((!object.attributes.visible && !includeHidden) ||
          !object.isDefined ||
          object.isInternal) {
        continue;
      }
      final nearest = screenInkOf(
        objects,
        viewport,
        canvasSize,
        object,
      ).nearest(pointer, viewport.forObject(object).sheetDepthAt(pointer));
      if (nearest.distance > thresholdPx) {
        continue;
      }
      candidates.add((
        object: object,
        priority: switch (object) {
          GeoPoint() => 0,
          GeoCircle() => 1,
          GeoLine() => 2,
          GeoLocus() => 2,
          GeoAngle() => 3,
          GeoMeasurement() || GeoText() => 4,
          GeoPolygon() => 5,
          // Lowest: a plane's patch hits everywhere inside it, so
          // anything drawn in or in front of it must win the tap.
          // A solid's faces are regions too, and rank with planes: the
          // nearer under the pointer wins.
          GeoPlane() || GeoSolid() => 6,
        },
        distance: nearest.distance,
        depth: nearest.depth,
        index: index,
      ));
    }
    candidates.sort((a, b) {
      if (a.priority != b.priority) {
        return a.priority.compareTo(b.priority);
      }
      final bandA = (a.distance / depthBand).floor();
      final bandB = (b.distance / depthBand).floor();
      if (bandA != bandB) {
        return bandA.compareTo(bandB);
      }
      if ((a.depth - b.depth).abs() > _depthTie) {
        return b.depth.compareTo(a.depth); // nearer the viewer first
      }
      if (a.distance != b.distance) {
        return a.distance.compareTo(b.distance);
      }
      return b.index.compareTo(a.index); // exact tie: latest inserted first
    });
    return [for (final c in candidates) c.object];
  }

  /// The best hit, or null.
  GeoObject? hitTest(
    Iterable<GeoObject> objects,
    CanvasViewport viewport,
    Size canvasSize,
    Offset pointer,
    double thresholdPx, {
    bool includeHidden = false,
  }) => hitTestAll(
    objects,
    viewport,
    canvasSize,
    pointer,
    thresholdPx,
    includeHidden: includeHidden,
  ).firstOrNull;

  /// Depths closer than this are one depth: objects on one sheet differ
  /// only by rounding.
  static const double _depthTie = 1e-9;
}
