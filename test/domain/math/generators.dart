import 'package:fgex/domain/math/vec2.dart';
import 'package:glados/glados.dart';

/// Shared glados generators for the math layer.
extension MathAnys on Any {
  /// A finite coordinate on a 0.001 grid in [-1000, 1000].
  ///
  /// Built from ints so values shrink nicely and can never be NaN/infinite,
  /// while still exercising non-representable fractions like 0.001.
  Generator<double> get coordinate =>
      intInRange(-1000000, 1000001).map((i) => i / 1000);

  Generator<Vec2> get vec2 => combine2(coordinate, coordinate, Vec2.new);

  /// An interpolation parameter in [0, 1] on a 0.001 grid.
  Generator<double> get unitInterval =>
      intInRange(0, 1001).map((i) => i / 1000);
}
