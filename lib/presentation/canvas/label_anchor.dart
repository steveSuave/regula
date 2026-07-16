import 'dart:math' as math;

import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/math/vec2.dart';

/// World position a label hangs from. The painter converts it to screen
/// space and nudges it by a fixed pixel offset, so this only decides
/// *where on the object* the label belongs:
///
/// - points and angles: the point / vertex itself;
/// - segments: the midpoint; rays: the origin;
/// - infinite lines: the anchor closest to the world origin (the only
///   stable point an unbounded carrier has);
/// - circles: the top of the rim; arcs and sectors: the middle of the
///   drawn branch;
/// - polygons: the vertex average (inside for convex regions, stable
///   under drags either way).
///
/// Only call on defined objects — the force-unwraps mirror the painter's,
/// which skips undefined objects before asking for an anchor.
Vec2 labelAnchor(GeoObject object) => switch (object) {
      GeoPoint() => object.position!,
      Segment() => object.start!.lerp(object.end!, 0.5),
      Ray() => object.start!,
      GeoLine() => object.line!.pointOnLine,
      Arc() => object.circle!.pointAt(object.startAngle! + object.sweep! / 2),
      Sector() =>
        object.circle!.pointAt(object.startAngle! + object.sweep! / 2),
      GeoCircle() => object.circle!.pointAt(math.pi / 2),
      GeoAngle() => object.angle!.vertex,
      GeoPolygon() => object.polygonVertices!
              .reduce((sum, vertex) => sum + vertex) /
          object.polygonVertices!.length.toDouble(),
    };
