import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/proj_transform.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';

/// [point] translated by the vector from [vectorFrom] to [vectorTo].
///
/// Defined whenever all three parents are — coincident vector points just
/// give the zero translation. The vector is live: dragging either of its
/// defining points re-translates the image.
///
/// Migrated (Phase 108): [ProjTransform.translationTaking] on the
/// parents' projective views. Translations fix every point at infinity,
/// so a [point] at infinity is its own image; a vector endpoint at
/// infinity makes the map singular and sends finite points to the
/// direction's point at infinity — in each case marked as such:
/// [projPoint] real, [position] null.
class TranslatedPoint extends GeoPoint {
  TranslatedPoint({
    required super.id,
    required this.point,
    required this.vectorFrom,
    required this.vectorTo,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoPoint vectorFrom;
  final GeoPoint vectorTo;

  ProjPoint? _point;

  @override
  ProjPoint? get projPoint => _point;

  @override
  Vec2? get position => _point?.toVec2();

  bool get _offSheet =>
      !sheet.exists ||
      point.projPoint == null ||
      vectorFrom.projPoint == null ||
      vectorTo.projPoint == null;

  /// A translation needs no plane (intent 004, milestone 3): when the
  /// three points have no common value in one sheet, the image is taken
  /// in space. Euclidean only, like the planar value; a document with
  /// space content is Euclidean.
  @override
  Vec3? get spacePosition {
    if (!_offSheet) {
      return super.spacePosition;
    }
    final p = point.spacePosition;
    final from = vectorFrom.spacePosition;
    final to = vectorTo.spacePosition;
    if (p == null || from == null || to == null) {
      return null;
    }
    return p + (to - from);
  }

  @override
  Point3? get spacePoint {
    if (!_offSheet) {
      return super.spacePoint;
    }
    final at = spacePosition;
    return at == null ? null : Point3.lift(at);
  }

  @override
  List<GeoObject> get parents => [point, vectorFrom, vectorTo];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    // Euclidean only (Phase 125). Translation by an affine vector is affine. The CK analogue is
    // the isometry carrying one point to another along their geodesic,
    // which is a different construction, not this one re-pointed.
    if (!absolute.isEuclidean) {
      _point = null;
      return;
    }
    final p = point.projPoint;
    final from = vectorFrom.projPoint;
    final to = vectorTo.projPoint;
    if (p == null || from == null || to == null || !sheet.exists) {
      _point = null;
      return;
    }
    final image = ProjTransform.translationTaking(from, to).apply(p);
    _point = image.isZero ? null : image.wPositive;
  }
}
