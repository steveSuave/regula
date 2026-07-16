import 'dart:math' as math;

import '../../math/polygon_math.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// The live area of a polygon or circle, displayed as canvas text at the
/// subject's center of mass — the vertex average, or the circle's center.
/// Undefined while the subject is.
///
/// One kind serves both subjects, so [subject] is a plain [GeoObject]
/// with the allowed kinds enforced in the constructor (the
/// `PointOnObject.curve` precedent — an ill-typed save normalizes to
/// `FormatException` through the codec's ArgumentError handler). A
/// polygon's area is the absolute shoelace value, so a self-intersecting
/// loop reports its alternating region sum's magnitude (documented at
/// [polygonSignedArea]).
class AreaMeasurement extends GeoMeasurement {
  AreaMeasurement({
    required super.id,
    required this.subject,
    super.attributes,
  }) {
    if (subject is! GeoPolygon && subject is! GeoCircle) {
      throw ArgumentError(
        'AreaMeasurement requires a polygon or circle parent',
      );
    }
    recompute();
  }

  /// A [GeoPolygon] or [GeoCircle] (enforced in the constructor).
  final GeoObject subject;

  double? _value;
  Vec2? _anchor;

  @override
  double? get value => _value;

  @override
  Vec2? get anchor => _anchor;

  @override
  List<GeoObject> get parents => [subject];

  @override
  void recompute() {
    switch (subject) {
      case GeoPolygon(:final polygonVertices?):
        _value = polygonSignedArea(polygonVertices).abs();
        _anchor = polygonVertices.reduce((sum, vertex) => sum + vertex) /
            polygonVertices.length.toDouble();
      case GeoCircle(:final circle?):
        _value = math.pi * circle.radius * circle.radius;
        _anchor = circle.center;
      default:
        _value = null;
        _anchor = null;
    }
  }
}
