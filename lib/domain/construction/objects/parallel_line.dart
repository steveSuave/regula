import '../../projective/absolute.dart';
import '../../projective/metric.dart';
import '../../projective/proj_line.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/line3.dart';
import '../../projective/space/space_metric.dart';
import 'relative_line.dart';

/// The line through [through], parallel to [reference].
///
/// The join of the through-point with the reference's point at infinity
/// (its meet with the line at infinity). When [through] lies on the
/// reference the two lines coincide — that is still a defined line, not a
/// degeneracy.
class ParallelLine extends RelativeLine {
  ParallelLine({
    required super.id,
    required super.through,
    required super.reference,
    super.attributes,
  });

  @override
  ProjLine carrierFrom(
    ProjPoint through,
    ProjLine reference,
    Absolute absolute,
  ) => parallelThrough(through, reference, absolute);

  bool get _offSheet =>
      !sheet.exists || through.projPoint == null || reference.projLine == null;

  /// A parallel needs no plane (intent 004): through a point of space,
  /// along a line of space. Used when the two have no common value in
  /// the sheet; the planar carrier's lift otherwise.
  @override
  Line3? get spaceLine {
    if (!_offSheet) {
      return super.spaceLine;
    }
    final p = through.spacePoint;
    final ref = reference.spaceLine;
    if (p == null || ref == null) {
      return null;
    }
    final l = parallelLineThrough(p, ref);
    return l.isZero ? null : l;
  }

  @override
  bool get hasSpaceExtent => _offSheet && (spaceLine?.isFinite() ?? false);
}
