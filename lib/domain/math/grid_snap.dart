import 'vec2.dart';

/// Quantizes [p] componentwise to the nearest multiple of [step] — the
/// Phase 45 snap-to-grid rounding. A hard round-to-nearest (deterministic
/// "fixed to grid"), not a proximity gate: while snapping is on, every
/// genuinely free position lands exactly on a grid crossing.
///
/// A [step] that is zero, negative or non-finite returns [p] unchanged —
/// 0 is the wire format for "snapping off" (`ToolInput.gridSnapStep`).
Vec2 snapToGrid(Vec2 p, double step) {
  if (!step.isFinite || step <= 0) {
    return p;
  }
  return Vec2(
    (p.x / step).roundToDouble() * step,
    (p.y / step).roundToDouble() * step,
  );
}
