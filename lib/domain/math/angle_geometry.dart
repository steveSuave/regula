import 'dart:math' as math;

import 'vec2.dart';

const double _tau = 2 * math.pi;

/// Counter-clockwise sweep from angle [from] to angle [to], in [0, 2π).
///
/// Equal angles (mod 2π) sweep 0, never 2π — a full turn is not
/// representable, matching "an angle's two arms coincide" semantics.
double ccwSweep(double from, double to) {
  final sweep = (to - from) % _tau;
  // Rounding can land a tiny negative difference exactly on 2π.
  return sweep == _tau ? 0 : sweep;
}

/// Signed sweep from angle [start] to angle [end] along the side that
/// passes [via]: positive (counter-clockwise) when [via] lies on the CCW
/// path from [start] to [end], negative (clockwise) otherwise.
///
/// This is the branch pick for a three-point arc: the arc from the first
/// endpoint to the last is the one containing the middle point.
double sweepThrough(double start, double via, double end) {
  final toEnd = ccwSweep(start, end);
  final toVia = ccwSweep(start, via);
  return toVia <= toEnd ? toEnd : toEnd - _tau;
}

/// An angle as drawable geometry: a [vertex], a unit [startDirection] and
/// a counter-clockwise [sweep] in [0, 2π).
///
/// This is what a `GeoAngle` exposes — enough for a painter to place the
/// marker arc and for [measure] to be read off; angles take part in no
/// intersection math.
class AngleGeometry {
  AngleGeometry(this.vertex, this.startDirection, this.sweep) {
    if (sweep.isNaN || sweep < 0 || sweep >= _tau) {
      throw ArgumentError.value(sweep, 'sweep', 'must be in [0, 2π)');
    }
  }

  /// The angle at [vertex] swept counter-clockwise from the ray towards
  /// [arm1] to the ray towards [arm2], or null when either arm coincides
  /// with the vertex.
  ///
  /// Swapping the arms yields the complementary marker (2π − sweep).
  static AngleGeometry? fromRays(Vec2 arm1, Vec2 vertex, Vec2 arm2) {
    final toArm1 = arm1 - vertex;
    final toArm2 = arm2 - vertex;
    if (toArm1.normSquared == 0 || toArm2.normSquared == 0) {
      return null;
    }
    return AngleGeometry(
      vertex,
      toArm1.normalized(),
      ccwSweep(toArm1.angle, toArm2.angle),
    );
  }

  /// The acute (or right) angle between two line directions crossing at
  /// [vertex], with sweep in (0, π/2]. Null when the directions are
  /// parallel (a zero angle has no marker) or when either is zero.
  ///
  /// Lines have no orientation, so [direction1]/[direction2] are read up
  /// to sign; the marker always opens counter-clockwise.
  static AngleGeometry? betweenLines(
    Vec2 vertex,
    Vec2 direction1,
    Vec2 direction2,
  ) {
    if (direction1.normSquared == 0 || direction2.normSquared == 0) {
      return null;
    }
    final unit1 = direction1.normalized();
    var unit2 = direction2.normalized();
    if (unit1.dot(unit2) < 0) {
      unit2 = -unit2; // Fold into unit1's half-plane: the angle turns acute.
    }
    if (unit1.cross(unit2) == 0) {
      return null;
    }
    final start = unit1.cross(unit2) > 0 ? unit1 : unit2;
    final end = unit1.cross(unit2) > 0 ? unit2 : unit1;
    return AngleGeometry(vertex, start, ccwSweep(start.angle, end.angle));
  }

  /// The wedge at [vertex] between the half-lines towards [direction1]
  /// and [direction2], with sweep in (0, π): the start arm is whichever
  /// direction makes the counter-clockwise sweep to the other less than
  /// π. Unlike [betweenLines] the directions are read *as given*, not up
  /// to sign, so the obtuse wedge pair is reachable — pass the opposite
  /// half-direction to get the complementary marker. Null when the
  /// directions are parallel or anti-parallel (no wedge between
  /// coincident or opposite rays) or when either is zero.
  static AngleGeometry? betweenHalfLines(
    Vec2 vertex,
    Vec2 direction1,
    Vec2 direction2,
  ) {
    if (direction1.normSquared == 0 || direction2.normSquared == 0) {
      return null;
    }
    final unit1 = direction1.normalized();
    final unit2 = direction2.normalized();
    final cross = unit1.cross(unit2);
    if (cross == 0) {
      return null;
    }
    final start = cross > 0 ? unit1 : unit2;
    final end = cross > 0 ? unit2 : unit1;
    return AngleGeometry(vertex, start, ccwSweep(start.angle, end.angle));
  }

  final Vec2 vertex;

  /// Unit direction of the angle's first arm.
  final Vec2 startDirection;

  /// Counter-clockwise extent in radians, in [0, 2π).
  final double sweep;

  /// The angle's measure in radians — an alias of [sweep].
  double get measure => sweep;

  /// Unit direction of the angle's second arm: [startDirection] rotated
  /// counter-clockwise by [sweep].
  Vec2 get endDirection {
    final c = math.cos(sweep);
    final s = math.sin(sweep);
    return Vec2(
      startDirection.x * c - startDirection.y * s,
      startDirection.x * s + startDirection.y * c,
    );
  }

  bool closeTo(AngleGeometry other, [double epsilon = defaultEpsilon]) =>
      vertex.closeTo(other.vertex, epsilon) &&
      startDirection.closeTo(other.startDirection, epsilon) &&
      (sweep - other.sweep).abs() <= epsilon;

  @override
  bool operator ==(Object other) =>
      other is AngleGeometry &&
      other.vertex == vertex &&
      other.startDirection == startDirection &&
      other.sweep == sweep;

  @override
  int get hashCode => Object.hash(vertex, startDirection, sweep);

  @override
  String toString() =>
      'AngleGeometry(vertex: $vertex, start: $startDirection, sweep: $sweep)';
}
