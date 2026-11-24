import 'package:glados/glados.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/plane_frame.dart';
import 'package:regula/domain/projective/space/point3.dart';

/// Shared glados generators for the space kernel.
extension SpaceAnys on Any {
  /// A finite coordinate on a 0.01 grid in [-100, 100].
  Generator<double> get coordinate =>
      intInRange(-10000, 10001).map((i) => i / 100);

  Generator<Vec3> get vec3 =>
      combine3(coordinate, coordinate, coordinate, Vec3.new);

  /// A finite point of space.
  Generator<Point3> get finitePoint3 => vec3.map(Point3.lift);

  /// A triangle with a nondegenerate area: three points whose spanned
  /// parallelogram is at least one square unit.
  Generator<(Vec3, Vec3, Vec3)> get triangle3 =>
      combine3(vec3, vec3, vec3, (Vec3 a, Vec3 b, Vec3 c) {
        if ((b - a).cross(c - a).norm >= 1) {
          return (a, b, c);
        }
        return (a, a + const Vec3(3, 1, 0), a + const Vec3(-1, 2, 2));
      });

  /// A frame through a nondegenerate triangle.
  Generator<PlaneFrame> get planeFrame =>
      triangle3.map((t) => PlaneFrame.throughPoints(t.$1, t.$2, t.$3)!);
}
