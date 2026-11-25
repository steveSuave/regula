// Intent 004, milestone 3: which parts of a stroke a face hides.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/presentation/canvas/hidden_line.dart';

/// A square face from (100, 100) to (200, 200) at constant depth.
Occluder _square(double depth) => _face(const [
  Offset(100, 100),
  Offset(200, 100),
  Offset(200, 200),
  Offset(100, 200),
], (_) => depth);

Occluder _face(List<Offset> loop, double Function(Offset) depth) =>
    (loop: loop, depth: depth);

void main() {
  const margin = 1e-6;

  List<(double, double)> hidden(
    Offset a,
    Offset b,
    double da,
    double db,
    List<Occluder> faces,
  ) => hiddenIntervals(a, b, da, db, faces, margin: margin);

  void expectIntervals(
    List<(double, double)> actual,
    List<(double, double)> expected,
  ) {
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      // Where the stroke passes through a face's plane the margin moves
      // the end of the hidden stretch by its own size over the slope.
      expect(actual[i].$1, closeTo(expected[i].$1, 1e-6));
      expect(actual[i].$2, closeTo(expected[i].$2, 1e-6));
    }
  }

  test('a segment wholly behind a face is hidden whole', () {
    expectIntervals(
      hidden(const Offset(120, 150), const Offset(180, 150), 0, 0, [
        _square(5),
      ]),
      [(0, 1)],
    );
  });

  test('a segment in front of a face is not hidden', () {
    expect(
      hidden(const Offset(120, 150), const Offset(180, 150), 9, 9, [
        _square(5),
      ]),
      isEmpty,
    );
  });

  test('a segment that passes behind a face is hidden where it is behind '
      'the outline', () {
    expectIntervals(
      hidden(const Offset(0, 150), const Offset(400, 150), 0, 0, [_square(5)]),
      [(0.25, 0.5)],
    );
  });

  test('a segment that pierces a face is hidden on the far side only', () {
    // Depth runs 0 → 10 along it; the face is at depth 5.
    expectIntervals(
      hidden(const Offset(100, 150), const Offset(200, 150), 0, 10, [
        _square(5),
      ]),
      [(0, 0.5)],
    );
  });

  test('a segment behind a corner of a face is hidden across the corner', () {
    // Enters through the top edge at x = 150, leaves through the right
    // edge at y = 150.
    expectIntervals(
      hidden(const Offset(100, 50), const Offset(250, 200), 0, 0, [_square(5)]),
      [(1 / 3, 2 / 3)],
    );
  });

  test('an edge of the face, and a segment drawn in it, are not hidden by '
      'it', () {
    final face = _square(5);
    expect(
      hidden(const Offset(100, 100), const Offset(200, 100), 5, 5, [face]),
      isEmpty,
    );
    expect(
      hidden(const Offset(120, 120), const Offset(180, 190), 5, 5, [face]),
      isEmpty,
    );
    // Rounding puts it a hair behind: still not hidden.
    expect(
      hidden(
        const Offset(120, 120),
        const Offset(180, 190),
        5 - 1e-9,
        5 - 1e-9,
        [face],
      ),
      isEmpty,
    );
  });

  test('a face that is not convex hides only behind its own shape', () {
    // An L: the square with its top-right quarter removed.
    final ell = _face(const [
      Offset(100, 100),
      Offset(150, 100),
      Offset(150, 150),
      Offset(200, 150),
      Offset(200, 200),
      Offset(100, 200),
    ], (_) => 5);
    // Across the top half: behind the L only for its left arm.
    expectIntervals(
      hidden(const Offset(100, 125), const Offset(200, 125), 0, 0, [ell]),
      [(0, 0.5)],
    );
    // A diagonal that leaves the L through the notch and comes back.
    expectIntervals(
      hidden(const Offset(110, 110), const Offset(190, 190), 0, 0, [ell]),
      [(0, 1)],
    );
    expectIntervals(
      hidden(const Offset(140, 100), const Offset(200, 160), 0, 0, [ell]),
      [(0, 1 / 6), (5 / 6, 1)],
    );
  });

  test('behind two faces a segment is hidden over their union, merged', () {
    final second = _face(const [
      Offset(180, 100),
      Offset(300, 100),
      Offset(300, 200),
      Offset(180, 200),
    ], (_) => 7);
    expectIntervals(
      hidden(const Offset(0, 150), const Offset(400, 150), 0, 0, [
        _square(5),
        second,
      ]),
      [(0.25, 0.75)],
    );
    // And with a gap between them, two intervals.
    final apart = _face(const [
      Offset(240, 100),
      Offset(300, 100),
      Offset(300, 200),
      Offset(240, 200),
    ], (_) => 7);
    expectIntervals(
      hidden(const Offset(0, 150), const Offset(400, 150), 0, 0, [
        _square(5),
        apart,
      ]),
      [(0.25, 0.5), (0.6, 0.75)],
    );
  });

  test('a face whose depth slopes hides where it is in front', () {
    // The face's depth rises with x: 0 at x = 100, 10 at x = 200. A
    // segment at depth 5 right across is behind its right half.
    final sloped = _face(_square(0).loop, (p) => (p.dx - 100) / 10);
    expectIntervals(
      hidden(const Offset(100, 150), const Offset(200, 150), 5, 5, [sloped]),
      [(0.5, 1)],
    );
  });

  test('a piece too short to draw takes its neighbour\'s state', () {
    // Hidden up to a hair before the end: hidden to the end.
    expect(absorbSlivers(const [(0.0, 0.999)], 0.01), [(0.0, 1.0)]);
    // A hair of hidden at the start of a seen stroke: not hidden.
    expect(absorbSlivers(const [(0.0, 0.001)], 0.01), isEmpty);
    // A hair of seen between two hidden stretches: one hidden stretch.
    expect(absorbSlivers(const [(0.1, 0.5), (0.505, 0.9)], 0.01), [(0.1, 0.9)]);
    // A hair of hidden in the middle of a seen stroke: gone.
    expect(absorbSlivers(const [(0.5, 0.505)], 0.01), isEmpty);
    // Nothing short: nothing changes.
    expect(absorbSlivers(const [(0.25, 0.5)], 0.01), [(0.25, 0.5)]);
    expect(absorbSlivers(const [], 0.01), isEmpty);
    expect(absorbSlivers(const [(0.0, 1.0)], 0.01), [(0.0, 1.0)]);
  });

  test('the visible stretches are what the hidden ones leave', () {
    expect(visibleIntervals(const []), [(0.0, 1.0)]);
    expect(visibleIntervals(const [(0.0, 1.0)]), isEmpty);
    expect(visibleIntervals(const [(0.25, 0.5)]), [(0.0, 0.25), (0.5, 1.0)]);
    expect(visibleIntervals(const [(0.0, 0.3), (0.6, 1.0)]), [(0.3, 0.6)]);
  });
}
