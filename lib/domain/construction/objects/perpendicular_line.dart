import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import 'relative_line.dart';

/// The line through [through], perpendicular to [reference].
class PerpendicularLine extends RelativeLine {
  PerpendicularLine({
    required super.id,
    required super.through,
    required super.reference,
    super.attributes,
  });

  @override
  Vec2 directionFrom(LineEq referenceLine) => referenceLine.normal;
}
