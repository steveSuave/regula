import '../math/angle_geometry.dart';
import '../math/circle_eq.dart';
import '../math/line_eq.dart';
import '../math/vec2.dart';
import 'object_attributes.dart';

/// Base of every object in the construction graph.
///
/// The hierarchy is sealed at the *kind* level: every object is a
/// [GeoPoint], a [GeoLine], a [GeoCircle], a [GeoAngle] or a
/// [GeoPolygon], so kind-switches are exhaustive. The kinds themselves
/// are open — concrete objects
/// (`FreePoint`, `Midpoint`, …) live one-per-file under `objects/`,
/// which Dart's `sealed` would forbid on the root class directly.
///
/// Derived objects are pure functions of their [parents]: [recompute]
/// re-reads the parents' current state and updates this object's cached
/// geometry. The `Construction` DAG guarantees parents are recomputed
/// first (insertion order is a topological order).
///
/// An object can be *undefined* ([isDefined] is false) when its parents
/// are in a degenerate configuration — coincident points defining a line,
/// circles that stopped intersecting mid-drag. Undefined objects stay in
/// the graph and come back to life when the degeneracy passes; consumers
/// (painter, hit tester) must skip them while undefined.
sealed class GeoObject {
  GeoObject({required this.id, ObjectAttributes? attributes})
      : attributes = attributes ?? const ObjectAttributes();

  /// Stable unique id; referenced by the save format and dependents lookup.
  final String id;

  /// Display attributes. Mutable, but only via `ChangeAttributesCommand`.
  ObjectAttributes attributes;

  /// The objects this one is derived from, in construction order.
  /// Empty for free points. Fixed for the object's lifetime.
  List<GeoObject> get parents;

  /// Whether the object currently has valid geometry (see class doc).
  bool get isDefined;

  /// Recomputes this object's geometry from its parents' current state.
  ///
  /// Must be cheap, must not throw on degenerate input — degeneracy makes
  /// the object undefined instead.
  void recompute();
}

/// A point-valued object. [position] is null while undefined.
abstract class GeoPoint extends GeoObject {
  GeoPoint({required super.id, super.attributes});

  Vec2? get position;

  @override
  bool get isDefined => position != null;
}

/// A line-valued object (infinite lines, rays, segments share the carrier
/// [line] for intersection math). [line] is null while undefined.
abstract class GeoLine extends GeoObject {
  GeoLine({required super.id, super.attributes});

  LineEq? get line;

  @override
  bool get isDefined => line != null;
}

/// A circle-valued object. [circle] is null while undefined.
abstract class GeoCircle extends GeoObject {
  GeoCircle({required super.id, super.attributes});

  CircleEq? get circle;

  @override
  bool get isDefined => circle != null;
}

/// An angle-valued object: a marker at a vertex plus a readable measure
/// ([AngleGeometry.measure]). Angles take part in no intersection math —
/// they are decorations over existing geometry. [angle] is null while
/// undefined.
abstract class GeoAngle extends GeoObject {
  GeoAngle({required super.id, super.attributes});

  AngleGeometry? get angle;

  @override
  bool get isDefined => angle != null;
}

/// A polygon-valued object: a filled region bounded by the closed loop
/// of [polygonVertices]. Polygons take part in no intersection math —
/// like angles they decorate existing geometry rather than carrying any.
/// A collinear or self-intersecting loop is still *defined* (it is a
/// drawable outline); [polygonVertices] is null only while a vertex is
/// undefined.
abstract class GeoPolygon extends GeoObject {
  GeoPolygon({required super.id, super.attributes});

  List<Vec2>? get polygonVertices;

  @override
  bool get isDefined => polygonVertices != null;
}
