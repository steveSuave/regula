import 'dart:math' as math;

/// Default tolerance for epsilon-comparisons across the math layer.
///
/// Geometric predicates (`closeTo`, `contains`, `isParallelTo`, …) accept an
/// explicit epsilon; this is the value they use when the caller doesn't care.
const double defaultEpsilon = 1e-9;

/// An immutable 2D vector, also used as a point in world coordinates.
class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator -() => Vec2(-x, -y);

  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);

  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Z-component of the 3D cross product.
  ///
  /// Positive when [other] points counter-clockwise from this vector,
  /// negative when clockwise, zero when the two are parallel.
  double cross(Vec2 other) => x * other.y - y * other.x;

  double get normSquared => x * x + y * y;

  double get norm => math.sqrt(normSquared);

  double distanceTo(Vec2 other) => (this - other).norm;

  double squaredDistanceTo(Vec2 other) => (this - other).normSquared;

  /// This vector scaled to unit length.
  ///
  /// Throws a [StateError] for the zero vector — callers constructing
  /// directions from user input must guard against coincident points first.
  Vec2 normalized() {
    final n = norm;
    if (n == 0) {
      throw StateError('Cannot normalize the zero vector');
    }
    return this / n;
  }

  /// This vector rotated 90° counter-clockwise (same length).
  Vec2 get perpendicular => Vec2(-y, x);

  /// Linear interpolation: `this` at t = 0, [other] at t = 1.
  ///
  /// t is not clamped, so values outside [0, 1] extrapolate.
  Vec2 lerp(Vec2 other, double t) =>
      Vec2(x + (other.x - x) * t, y + (other.y - y) * t);

  /// Angle in radians from the positive x-axis, in (-π, π].
  double get angle => math.atan2(y, x);

  bool closeTo(Vec2 other, [double epsilon = defaultEpsilon]) =>
      distanceTo(other) <= epsilon;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
