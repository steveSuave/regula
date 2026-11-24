import 'dart:math' as math;

import 'vec2.dart';

/// An immutable 3D vector, also used as a point of space in world
/// coordinates. The base plane is `z = 0`, and a `Vec2` world point
/// `(x, y)` is the space point `(x, y, 0)`.
///
/// A view struct, like [Vec2]: what a `Point3` projects to. The space
/// kernel computes in homogeneous coordinates
/// (`lib/domain/projective/space/`).
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  /// The base-plane point [p] as a point of space.
  Vec3.base(Vec2 p) : this(p.x, p.y, 0);

  static const Vec3 zero = Vec3(0, 0, 0);
  static const Vec3 unitX = Vec3(1, 0, 0);
  static const Vec3 unitY = Vec3(0, 1, 0);
  static const Vec3 unitZ = Vec3(0, 0, 1);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  Vec3 operator -() => Vec3(-x, -y, -z);

  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);

  Vec3 operator /(double scalar) => Vec3(x / scalar, y / scalar, z / scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get normSquared => x * x + y * y + z * z;

  double get norm => math.sqrt(normSquared);

  double distanceTo(Vec3 other) => (this - other).norm;

  bool get isZero => x == 0 && y == 0 && z == 0;

  /// This vector scaled to unit length, or null for the zero vector.
  Vec3? get normalizedOrNull {
    final n = norm;
    return n == 0 ? null : this / n;
  }

  bool closeTo(Vec3 other, [double epsilon = defaultEpsilon]) =>
      distanceTo(other) <= epsilon;

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
