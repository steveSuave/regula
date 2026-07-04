import 'dart:ui';

/// Rebuilds [source] as a dashed path: alternating on/off runs of
/// [period] / 2 logical pixels each, walked along every contour.
///
/// Flutter's `Canvas` has no built-in dash support, so the painter routes
/// dashed strokes (`ObjectAttributes.dashPeriod > 0`) through here after
/// building the primitive as a [Path].
Path dashPath(Path source, double period) {
  assert(period > 0, 'dashPath needs a positive period; 0 means solid');
  final dash = period / 2;
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final end = distance + dash;
      if (draw) {
        result.addPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          Offset.zero,
        );
      }
      distance = end;
      draw = !draw;
    }
  }
  return result;
}
