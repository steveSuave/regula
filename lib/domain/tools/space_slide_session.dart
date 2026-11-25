import '../commands/command.dart';
import '../commands/set_point_on_object_parameter_command.dart';
import '../construction/construction.dart';
import '../construction/geo_object.dart';
import '../construction/objects/point_on_object.dart';

/// One slide of a point glued to a line of space: a drag that changes
/// its parameter along a host with no value in any sheet — a pyramid's
/// edge, a perpendicular to a plane (intent 004, milestone 3). The
/// space sibling of `DragSession`'s slide, as `LiftSession` is of its
/// free-point drag.
///
/// The planar slide projects the pointer onto the host's chart form.
/// Such a host has none, so the canvas reads the parameter off the
/// host's screen image and hands this session the number. The preview is
/// a static solve at each frame: space is real, so there is nothing to
/// continue through, and whatever is built on the point re-solves in
/// canonical order as it does when a plane moves.
///
/// Preview frames set the parameter directly through
/// `Construction.setPointOnObjectParameter` (the sanctioned drag-preview
/// carve-out); [end] rolls the preview back and returns the one
/// [SetPointOnObjectParameterCommand] for the caller to execute, or null
/// when the parameter did not change; [cancel] rolls back.
class SpaceSlideSession {
  SpaceSlideSession._(this._construction, this.pointId, this.startParameter)
    : _parameter = startParameter;

  /// Null unless [point] is glued to a line drawn from its space value.
  static SpaceSlideSession? start(
    Construction construction,
    PointOnObject point,
  ) {
    final host = point.curve;
    if (!point.onSpaceLine || host is! GeoLine) {
      return null;
    }
    // From the effective parameter: after a host shrank past the stored
    // one the point is drawn on the extent's end, and that is where it
    // was grabbed.
    return SpaceSlideSession._(
      construction,
      point.id,
      host.clampSpaceParameter(point.parameter),
    ).._stored = point.parameter;
  }

  final Construction _construction;
  final String pointId;

  /// The parameter the point was drawn at when grabbed.
  final double startParameter;

  /// The parameter the document held, which [cancel] restores exactly.
  late final double _stored;

  double _parameter;

  /// Whether a preview has written to the construction.
  bool _touched = false;

  /// Previews the slide at [parameter], clamped to the host's drawn
  /// extent. A no-op once the point is gone (an undo under the gesture).
  void update(double parameter) {
    final point = _point;
    if (point == null) {
      return;
    }
    final host = point.curve;
    final clamped = host is GeoLine
        ? host.clampSpaceParameter(parameter)
        : parameter;
    if (clamped == _parameter) {
      return;
    }
    _parameter = clamped;
    _touched = true;
    _construction.setPointOnObjectParameter(pointId, clamped);
  }

  Command? end() {
    final to = _parameter;
    cancel();
    // Back where it was drawn is no move, even when the stored parameter
    // lies past the host's end and differs from where it is drawn.
    if (to == startParameter || to == _stored) {
      return null;
    }
    return SetPointOnObjectParameterCommand(
      pointId: pointId,
      from: _stored,
      to: to,
    );
  }

  void cancel() {
    if (_point != null && _touched) {
      _construction.setPointOnObjectParameter(pointId, _stored);
    }
    _touched = false;
    _parameter = startParameter;
  }

  PointOnObject? get _point => switch (_construction.byId(pointId)) {
    final PointOnObject point => point,
    _ => null,
  };
}
