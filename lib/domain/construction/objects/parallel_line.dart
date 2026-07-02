import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import 'relative_line.dart';

/// The line through [through], parallel to [reference].
///
/// When [through] lies on the reference the two lines coincide — that is
/// still a defined line, not a degeneracy.
class ParallelLine extends RelativeLine {
  ParallelLine({
    required super.id,
    required super.through,
    required super.reference,
    super.attributes,
  });

  @override
  Vec2 directionFrom(LineEq referenceLine) => referenceLine.direction;
}
