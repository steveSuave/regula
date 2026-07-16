import 'vec2.dart';

/// Signed area of the polygon whose vertices are [vertices], in loop
/// order — the shoelace formula. Positive for counter-clockwise loops,
/// negative for clockwise, zero for collinear (degenerate) loops.
///
/// Consumers wanting a magnitude (`AreaMeasurement`) take the absolute
/// value. For a *self-intersecting* loop the shoelace value is the
/// alternating sum of the loop's regions, so |shoelace| is what a bowtie
/// reports — documented behavior, GeoGebra-compatible enough.
///
/// Fewer than 3 vertices have no area: 0.
double polygonSignedArea(List<Vec2> vertices) {
  if (vertices.length < 3) {
    return 0;
  }
  var twiceArea = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i];
    final b = vertices[(i + 1) % vertices.length];
    twiceArea += a.cross(b);
  }
  return twiceArea / 2;
}
