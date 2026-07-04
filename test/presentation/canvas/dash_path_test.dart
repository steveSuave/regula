import 'dart:ui';

import 'package:fgex/presentation/canvas/dash_path.dart';
import 'package:flutter_test/flutter_test.dart';

double _totalLength(Path path) {
  var total = 0.0;
  for (final metric in path.computeMetrics()) {
    total += metric.length;
  }
  return total;
}

void main() {
  test('a dashed line keeps roughly half its length in dashes', () {
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final dashed = dashPath(line, 8);
    // 100 px at period 8 = 13 four-px runs drawn (the last clamped run
    // starts at 96), 12 gaps: 52 px on.
    expect(_totalLength(dashed), closeTo(52, 0.001));
    expect(dashed.computeMetrics().length, 13);
  });

  test('a closed contour dashes around its whole perimeter', () {
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 50));
    final dashed = dashPath(circle, 10);
    final perimeter = _totalLength(circle);
    expect(_totalLength(dashed), closeTo(perimeter / 2, 5.001));
    expect(dashed.computeMetrics().length, greaterThan(10));
  });

  test('an empty path stays empty', () {
    expect(dashPath(Path(), 8).computeMetrics(), isEmpty);
  });

  test('a path shorter than one dash survives whole', () {
    final stub = Path()
      ..moveTo(0, 0)
      ..lineTo(2, 0);
    expect(_totalLength(dashPath(stub, 8)), closeTo(2, 0.001));
  });
}
