import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/arc.dart';
import '../construction/objects/central_reflection_point.dart';
import '../construction/objects/circle_center_point.dart';
import '../construction/objects/compass_circle.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/line_through_two_points.dart';
import '../construction/objects/ray.dart';
import '../construction/objects/reflected_point.dart';
import '../construction/objects/rotated_point.dart';
import '../construction/objects/sector.dart';
import '../construction/objects/segment.dart';
import '../construction/objects/three_point_circle.dart';
import '../construction/objects/translated_point.dart';
import '../construction/objects/vertex_angle.dart';
import '../math/vec2.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// Which isometry a [TransformObjectTool] applies.
enum ObjectTransform { reflectAboutLine, reflectAboutPoint, rotate, translate }

/// The Phase 24 transform tool: applies one of the four isometries to a
/// point *or* a whole curve, replacing the four Phase 15 point-only
/// wirings.
///
/// The transformee is always the **first** input. A first tap whose
/// best-ranked in-threshold curve is a supported source picks that curve —
/// consulted *before* the point-resolution ladder, which would otherwise
/// glue a `PointOnObject` to the very curve being transformed. A first
/// tap on a point (or empty canvas) enters point mode, which behaves
/// exactly like the Phase 15 tools, including reflect's point + line in
/// either order and the shared resolution ladder for the later parameter
/// taps (center, vector tail and tip).
///
/// Curve mode rebuilds the **same kind over transform-point images of the
/// defining points**, all in one `MacroCommand` — no new object kinds, and
/// since all four transforms are isometries the image is automatically
/// congruent. Image points are committed visible (usable geometry).
///
/// Supported sources are the curves whose parents are all `GeoPoint`s:
/// `Segment`, `Ray`, `LineThroughTwoPoints`, `CircleCenterPoint`,
/// `CompassCircle`, `ThreePointCircle`, `Arc`, `VertexAngle`, and `Sector`
/// except under reflect-about-line (rebuilding would give the
/// complementary wedge — documented limitation). Curves with non-point
/// parents (`PerpendicularLine`, `ParallelLine`, `AngleBisectorLine`,
/// `LineAngle`) are ignored as transformees — object-level recursion is
/// deferred — though any `GeoLine` still serves as reflect's mirror.
///
/// Orientation: line reflection reverses it, so a reflected `VertexAngle`
/// swaps its arm points and the marker measures the same wedge; the three
/// orientation-preserving transforms rebuild arms as-is. `Arc` needs no
/// care — the via-point image picks the branch.
class TransformObjectTool implements ToolInputPreview {
  TransformObjectTool.reflectAboutLine({required this.newId})
      : transform = ObjectTransform.reflectAboutLine,
        angle = null;

  TransformObjectTool.reflectAboutPoint({required this.newId})
      : transform = ObjectTransform.reflectAboutPoint,
        angle = null;

  TransformObjectTool.rotate({required this.newId, required double this.angle})
      : transform = ObjectTransform.rotate;

  TransformObjectTool.translate({required this.newId})
      : transform = ObjectTransform.translate,
        angle = null;

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  final ObjectTransform transform;

  /// Rotation angle in radians, counter-clockwise; non-null exactly for
  /// [ObjectTransform.rotate] (chosen in a dialog before activation, like
  /// the segment-ratio tool's ratio).
  final double? angle;

  /// Point-mode transformee (tapped existing point, or a new free point
  /// from an empty-canvas tap).
  GeoPoint? _point;
  bool _pointIsNew = false;

  /// Curve-mode transformee (a supported source, see class doc).
  GeoObject? _source;
  Vec2? _sourceTap;

  /// Reflect's axis when a non-transformable line was tapped *first*
  /// (Phase 15's either-order); a supported line tapped first sits in
  /// [_source] instead and only becomes the mirror if a point follows.
  GeoLine? _mirror;
  Vec2? _mirrorTap;

  /// Parameter points after the transformee: reflect-about-point's and
  /// rotate's center, translate's vector tail and tip.
  final List<({GeoPoint point, bool isNew})> _params = [];

  int get _paramCount => switch (transform) {
        ObjectTransform.reflectAboutLine => 0,
        ObjectTransform.reflectAboutPoint || ObjectTransform.rotate => 1,
        ObjectTransform.translate => 2,
      };

  /// The line a point-mode commit would reflect across: a mirror-first
  /// line, or a line collected as [_source] awaiting the either-order
  /// resolution.
  GeoLine? get _pendingMirror {
    if (_mirror case final mirror?) {
      return mirror;
    }
    if (_source case final GeoLine line) {
      return line;
    }
    return null;
  }

  @override
  List<Vec2> get previewPositions => [
        ?_point?.position,
        if (_sourceTap case final tap?) ?_sourceMarker(tap),
        if (_mirrorTap case final tap?) ?_mirror?.line?.project(tap),
        for (final p in _params) ?p.point.position,
      ];

  /// The in-progress marker for the collected curve: the tap projected
  /// onto the curve's current carrier (an angle marks its vertex), so it
  /// rides along if the curve moves before the collection completes.
  Vec2? _sourceMarker(Vec2 tap) {
    switch (_source) {
      case final GeoLine line:
        return line.line?.project(tap);
      case final GeoCircle circle:
        final eq = circle.circle;
        if (eq == null) {
          return null;
        }
        return eq.pointAt(eq.angleAt(tap));
      case final GeoAngle angle:
        return angle.angle?.vertex;
      default:
        return null;
    }
  }

  @override
  ToolResult onInput(ToolInput input) {
    if (_point == null && _source == null && _mirror == null) {
      return _collectTransformee(input);
    }
    if (transform == ObjectTransform.reflectAboutLine) {
      return _collectMirrorOrPoint(input);
    }
    return _collectParam(input);
  }

  /// Slot 1. A tapped point wins (matching the ladder's first rung); else
  /// the best-ranked in-threshold curve decides: supported → curve-mode
  /// transformee, a line under reflect → mirror-first, anything else →
  /// ignored. Only a tap with no usable hit at all falls through to a new
  /// free point — never the gluing/crossing rungs of the ladder (see
  /// class doc).
  ToolResult _collectTransformee(ToolInput input) {
    if (input.hit case final GeoPoint hit) {
      _point = hit;
      _pointIsNew = false;
      return const ToolAccepted();
    }
    for (final object in input.hits) {
      if (object is GeoPoint) {
        continue;
      }
      if (_isSupportedSource(object)) {
        _source = object;
        _sourceTap = input.position;
        return const ToolAccepted();
      }
      if (transform == ObjectTransform.reflectAboutLine &&
          object is GeoLine) {
        _mirror = object;
        _mirrorTap = input.position;
        return const ToolAccepted();
      }
      return const ToolIgnored();
    }
    _point = FreePoint(id: newId(), position: input.position);
    _pointIsNew = true;
    return const ToolAccepted();
  }

  bool _isSupportedSource(GeoObject object) => switch (object) {
        Segment() ||
        Ray() ||
        LineThroughTwoPoints() ||
        CircleCenterPoint() ||
        CompassCircle() ||
        ThreePointCircle() ||
        Arc() ||
        VertexAngle() =>
          true,
        Sector() => transform != ObjectTransform.reflectAboutLine,
        _ => false,
      };

  /// Reflect's slot 2, preserving `PointAndLineTool`'s behavior exactly:
  /// with the point slot filled only a line commits; with a line pending,
  /// a point (or an empty-canvas tap creating one) commits the point
  /// reflection — either order — while a *second* line commits the
  /// curve-mode image of the first. Circles and angles are ignored, as is
  /// the source line itself (a line reflected across itself is itself).
  ToolResult _collectMirrorOrPoint(ToolInput input) {
    switch (input.hit) {
      case final GeoPoint hit:
        final mirror = _pendingMirror;
        if (_point != null || mirror == null) {
          return const ToolIgnored();
        }
        _point = hit;
        _pointIsNew = false;
        return _commitPoint(mirror: mirror);
      case final GeoLine hit:
        if (_point != null) {
          return _commitPoint(mirror: hit);
        }
        if (_source != null) {
          if (identical(hit, _source)) {
            return const ToolIgnored();
          }
          return _commitSource(mirror: hit);
        }
        return const ToolIgnored();
      case GeoCircle() || GeoAngle():
        return const ToolIgnored();
      case null:
        final mirror = _pendingMirror;
        if (_point != null || mirror == null) {
          return const ToolIgnored();
        }
        _point = FreePoint(id: newId(), position: input.position);
        _pointIsNew = true;
        return _commitPoint(mirror: mirror);
    }
  }

  /// Slots 2+ for the point-parameterized transforms: the full resolution
  /// ladder, exactly like `MultiPointTool.collectVertex` — parameter taps
  /// may reuse points, glue to curves or snap to crossings. An existing
  /// point already collected (as transformee or earlier parameter) is
  /// refused, matching `MultiPointTool`'s distinctness rule.
  ToolResult _collectParam(ToolInput input) {
    final resolved = resolvePoint(input, newId);
    if (!resolved.isNew &&
        (identical(resolved.point, _point) ||
            _params.any((p) => identical(p.point, resolved.point)))) {
      return const ToolIgnored();
    }
    _params.add(resolved);
    if (_params.length < _paramCount) {
      return const ToolAccepted();
    }
    return _point != null ? _commitPoint() : _commitSource();
  }

  /// The transform-point image of [point]; reads [_params] (and reflect's
  /// [mirror]), so it must run before [reset].
  GeoPoint _imageOf(GeoPoint point, {GeoLine? mirror}) => switch (transform) {
        ObjectTransform.reflectAboutLine =>
          ReflectedPoint(id: newId(), point: point, mirror: mirror!),
        ObjectTransform.reflectAboutPoint => CentralReflectionPoint(
            id: newId(),
            point: point,
            center: _params[0].point,
          ),
        ObjectTransform.rotate => RotatedPoint(
            id: newId(),
            point: point,
            center: _params[0].point,
            angle: angle!,
          ),
        ObjectTransform.translate => TranslatedPoint(
            id: newId(),
            point: point,
            vectorFrom: _params[0].point,
            vectorTo: _params[1].point,
          ),
      };

  /// Point-mode commit: new points in tap order, then the image — a bare
  /// `AddObjectCommand` when every input was an existing object, matching
  /// the Phase 15 tools.
  ToolResult _commitPoint({GeoLine? mirror}) {
    final point = _point!;
    final pointIsNew = _pointIsNew;
    final params = List.of(_params);
    final image = _imageOf(point, mirror: mirror);
    reset();
    final commands = <Command>[
      if (pointIsNew) AddObjectCommand(point),
      for (final p in params)
        if (p.isNew) AddObjectCommand(p.point),
      AddObjectCommand(image),
    ];
    return ToolCommitted(
      commands.length == 1 ? commands.single : MacroCommand(commands),
    );
  }

  /// Curve-mode commit: new parameter points, then one image per distinct
  /// defining point, then the rebuilt curve — dependency order, one
  /// `MacroCommand`, everything visible.
  ToolResult _commitSource({GeoLine? mirror}) {
    final source = _source!;
    final params = List.of(_params);
    final images = <GeoPoint, GeoPoint>{};
    GeoPoint img(GeoPoint parent) =>
        images.putIfAbsent(parent, () => _imageOf(parent, mirror: mirror));
    final rebuilt = _rebuild(source, img);
    reset();
    final commands = <Command>[
      for (final p in params)
        if (p.isNew) AddObjectCommand(p.point),
      for (final image in images.values) AddObjectCommand(image),
      AddObjectCommand(rebuilt),
    ];
    return ToolCommitted(MacroCommand(commands));
  }

  /// The same kind rebuilt over the images of [source]'s defining points.
  /// Only reflect-about-line reverses orientation, so only there does the
  /// rebuilt `VertexAngle` swap its arms (the marker then measures the
  /// image of the same wedge instead of its 2π complement).
  GeoObject _rebuild(GeoObject source, GeoPoint Function(GeoPoint) img) {
    final swapArms = transform == ObjectTransform.reflectAboutLine;
    return switch (source) {
      final Segment s =>
        Segment(id: newId(), point1: img(s.point1), point2: img(s.point2)),
      final Ray r =>
        Ray(id: newId(), origin: img(r.origin), through: img(r.through)),
      final LineThroughTwoPoints l => LineThroughTwoPoints(
          id: newId(),
          point1: img(l.point1),
          point2: img(l.point2),
        ),
      final CircleCenterPoint c => CircleCenterPoint(
          id: newId(),
          center: img(c.center),
          onCircle: img(c.onCircle),
        ),
      final CompassCircle c => CompassCircle(
          id: newId(),
          radiusPoint1: img(c.radiusPoint1),
          radiusPoint2: img(c.radiusPoint2),
          center: img(c.center),
        ),
      final ThreePointCircle c => ThreePointCircle(
          id: newId(),
          point1: img(c.point1),
          point2: img(c.point2),
          point3: img(c.point3),
        ),
      final Arc a =>
        Arc(id: newId(), start: img(a.start), via: img(a.via), end: img(a.end)),
      final Sector s => Sector(
          id: newId(),
          center: img(s.center),
          start: img(s.start),
          end: img(s.end),
        ),
      final VertexAngle v => VertexAngle(
          id: newId(),
          arm1: img(swapArms ? v.arm2 : v.arm1),
          vertex: img(v.vertex),
          arm2: img(swapArms ? v.arm1 : v.arm2),
        ),
      _ => throw StateError(
          'unsupported transform source: ${source.runtimeType}',
        ),
    };
  }

  @override
  void reset() {
    _point = null;
    _pointIsNew = false;
    _source = null;
    _sourceTap = null;
    _mirror = null;
    _mirrorTap = null;
    _params.clear();
  }
}
