import 'dart:math' as math;

/// Fixed-format measure texts for show-value labels (Phase 35).
///
/// Decimal counts are deliberately fixed — no adaptive precision — so
/// golden tests stay deterministic and a value's width doesn't jitter
/// while its object is dragged.

/// A length in world units, 2 decimals: `3.14`.
String formatLength(double length) => length.toStringAsFixed(2);

/// An angle in radians, rendered in degrees with 1 decimal: `90.0°`.
String formatAngle(double radians) =>
    '${(radians * 180 / math.pi).toStringAsFixed(1)}°';

/// An area in squared world units — same shape as lengths (Phase 38
/// forward; areas get no unit suffix either).
String formatArea(double area) => formatLength(area);
