import 'dart:math' as math;

/// Arming gate for the two-finger twist (Phase 43): keeps a plain pinch
/// from drifting the view angle, and settles a nearly-level release back
/// to exactly 0.
///
/// One instance per navigation gesture. Feed it the recognizer's
/// cumulative `details.rotation` each frame: it returns 0 until the twist
/// *arms* — the cumulative rotation first exceeds [armThreshold] — and
/// from then on the rotation measured *from the arming frame*, so the
/// content never jumps by the threshold when the twist kicks in.
///
/// Sign note: this class is sign-agnostic — it hands back deltas in
/// whatever convention the caller feeds it. (Flutter's scale recognizer
/// reports rotation positive-clockwise on screen; `ViewportState.rotation`
/// is positive-counterclockwise, so the canvas negates at the call site.)
class TwistGate {
  TwistGate();

  /// Cumulative gesture rotation below which the twist stays inert
  /// (~5.7°): a plain pinch wobbles by less, a deliberate twist crosses
  /// it immediately.
  static const double armThreshold = 0.1;

  /// A released view angle within this of level (2°) snaps back to
  /// exactly 0 — "close enough to straight is straight".
  static const double snapThreshold = 2 * math.pi / 180;

  double? _armOffset;
  double? _lastRaw;
  double _unwrapped = 0;

  /// Whether the gesture has committed to twisting.
  bool get armed => _armOffset != null;

  /// The rotation to apply for this frame, given the recognizer's
  /// cumulative [gestureRotation]: 0 while unarmed, afterwards the
  /// rotation since the arming frame.
  ///
  /// The recognizer's value is a raw `atan2` difference, so it jumps by
  /// 2π whenever the line between the fingers crosses the ±π cut —
  /// [applied] unwraps successive samples (no real gesture rotates
  /// anywhere near π between frames) into a continuous angle first.
  double applied(double gestureRotation) {
    final last = _lastRaw;
    _lastRaw = gestureRotation;
    if (last == null) {
      _unwrapped = gestureRotation;
    } else {
      var delta = gestureRotation - last;
      if (delta > math.pi) {
        delta -= 2 * math.pi;
      } else if (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      _unwrapped += delta;
    }
    if (_armOffset == null && _unwrapped.abs() >= armThreshold) {
      _armOffset = _unwrapped;
    }
    final offset = _armOffset;
    return offset == null ? 0 : _unwrapped - offset;
  }

  /// The view angle to settle on at gesture end: [rotation] normalized to
  /// (−π, π] — a full extra turn is not a different view — and snapped to
  /// 0 when within [snapThreshold] of level.
  static double settled(double rotation) {
    final normalized = normalizeAngle(rotation);
    return normalized.abs() <= snapThreshold ? 0 : normalized;
  }
}

/// [angle] wrapped into (−π, π]. In-range angles return unchanged (the
/// wrap-around subtraction would cost a last bit of precision); Dart's
/// `%` is non-negative, so the wrapped value starts in [0, 2π) and only
/// the upper half needs folding.
double normalizeAngle(double angle) {
  if (angle > -math.pi && angle <= math.pi) {
    return angle;
  }
  final wrapped = angle % (2 * math.pi);
  return wrapped > math.pi ? wrapped - 2 * math.pi : wrapped;
}
