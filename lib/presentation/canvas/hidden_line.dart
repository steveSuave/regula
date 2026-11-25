import 'dart:ui';

/// A face that can hide what is behind it: its outline on the screen,
/// and the camera depth of its plane under a screen point (larger is
/// nearer the viewer, as `CanvasViewport.depthOf`).
typedef Occluder = ({List<Offset> loop, double Function(Offset point) depth});

/// The parts of a stroke that a face hides (intent 004, milestone 3):
/// the stretches of the segment from [a] to [b], as parameter intervals
/// in `[0, 1]`, that lie behind some face of [faces]. Sorted, merged,
/// empty when nothing hides it.
///
/// **The rule is per point**: a point of ink is hidden when some face is
/// in front of it along the view direction — its screen position is
/// inside the face's outline and its depth is less than the face's
/// there, by more than [margin]. Nothing is assumed about the solid the
/// face belongs to, so a solid that is not convex, and two solids one
/// behind the other, need no rule of their own.
///
/// Under a parallel projection depth runs linearly along a segment and
/// affinely over a flat face, so along the segment the answer can change
/// only where the segment crosses an edge of the face's outline or
/// passes through its plane. Those are found, and each stretch between
/// two of them is decided at its middle.
///
/// [margin] is what keeps an edge of a face, and anything drawn in a
/// face, from being hidden by that face: it lies *in* the plane, and
/// rounding would otherwise put half of it behind. It is a tolerance on
/// where ink goes and not on the figure.
List<(double, double)> hiddenIntervals(
  Offset a,
  Offset b,
  double depthA,
  double depthB,
  Iterable<Occluder> faces, {
  required double margin,
}) {
  final hidden = <(double, double)>[];
  final along = b - a;
  for (final face in faces) {
    final loop = face.loop;
    if (loop.length < 3) {
      continue;
    }
    // How far the face is in front of the segment at each end, past the
    // margin; linear in between.
    final g0 = face.depth(a) - depthA - margin;
    final g1 = face.depth(b) - depthB - margin;
    if (g0 <= 0 && g1 <= 0) {
      continue;
    }
    final cuts = <double>[0, 1];
    if ((g0 > 0) != (g1 > 0)) {
      cuts.add(g0 / (g0 - g1));
    }
    for (var i = 0; i < loop.length; i++) {
      final p = loop[i];
      final edge = loop[(i + 1) % loop.length] - p;
      final denominator = along.dx * edge.dy - along.dy * edge.dx;
      if (denominator == 0) {
        continue;
      }
      final from = p - a;
      final t = (from.dx * edge.dy - from.dy * edge.dx) / denominator;
      final s = (from.dx * along.dy - from.dy * along.dx) / denominator;
      if (t > 0 && t < 1 && s >= 0 && s <= 1) {
        cuts.add(t);
      }
    }
    cuts.sort();
    for (var i = 0; i + 1 < cuts.length; i++) {
      final from = cuts[i];
      final to = cuts[i + 1];
      if (to <= from) {
        continue;
      }
      final middle = (from + to) / 2;
      if (g0 + (g1 - g0) * middle > 0 && _inside(loop, a + along * middle)) {
        hidden.add((from, to));
      }
    }
  }
  if (hidden.length < 2) {
    return hidden;
  }
  hidden.sort((x, y) => x.$1.compareTo(y.$1));
  final merged = <(double, double)>[hidden.first];
  for (final (from, to) in hidden.skip(1)) {
    final last = merged.last;
    if (from <= last.$2) {
      if (to > last.$2) {
        merged[merged.length - 1] = (last.$1, to);
      }
    } else {
      merged.add((from, to));
    }
  }
  return merged;
}

/// [hidden] with every stretch shorter than [least] — hidden or seen —
/// given to its neighbour, so that no piece of a stroke is too short to
/// draw.
///
/// An edge that runs behind a face up to a corner they share is hidden
/// up to the corner, give or take the margin: what is left at the
/// corner is a piece of the stroke a fraction of a pixel long, which
/// would be drawn as a speck of solid line at the end of a dashed one.
/// [least] is that length as a fraction of the stroke.
List<(double, double)> absorbSlivers(
  List<(double, double)> hidden,
  double least,
) {
  if (hidden.isEmpty) {
    return hidden;
  }
  // The whole stroke as alternating pieces.
  final pieces = <({double from, double to, bool hidden})>[];
  var at = 0.0;
  for (final (from, to) in hidden) {
    if (from > at) {
      pieces.add((from: at, to: from, hidden: false));
    }
    pieces.add((from: from, to: to, hidden: true));
    at = to;
  }
  if (at < 1) {
    pieces.add((from: at, to: 1, hidden: false));
  }
  if (pieces.length > 1) {
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.to - piece.from < least) {
        final neighbour = i > 0 ? pieces[i - 1] : pieces[i + 1];
        pieces[i] = (from: piece.from, to: piece.to, hidden: neighbour.hidden);
      }
    }
  }
  final result = <(double, double)>[];
  for (final piece in pieces) {
    if (!piece.hidden) {
      continue;
    }
    if (result.isNotEmpty && result.last.$2 == piece.from) {
      result[result.length - 1] = (result.last.$1, piece.to);
    } else {
      result.add((piece.from, piece.to));
    }
  }
  return result;
}

/// The stretches of `[0, 1]` that [hidden] leaves: what is drawn as it
/// always was.
List<(double, double)> visibleIntervals(List<(double, double)> hidden) {
  final visible = <(double, double)>[];
  var at = 0.0;
  for (final (from, to) in hidden) {
    if (from > at) {
      visible.add((at, from));
    }
    at = to;
  }
  if (at < 1) {
    visible.add((at, 1));
  }
  return visible;
}

/// Even-odd: an outline that crosses itself, or a face that is not
/// convex, is read the way the painter fills it.
bool _inside(List<Offset> polygon, Offset p) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// The dash period, in pixels, of a hidden stretch of a stroke that is
/// solid where it is seen.
const double hiddenDashPeriod = 8;

/// How much of its opacity a hidden stretch keeps.
const double hiddenInkAlpha = 0.6;

/// The depth by which ink must be behind a face to be hidden by it, as
/// a fraction of the depth the solids span. Ink in a face's own plane
/// is level with it up to rounding, which is many orders smaller.
const double hiddenDepthMargin = 1e-6;

/// The least such depth, for a figure with no depth to speak of.
const double hiddenDepthFloor = 1e-12;

/// The shortest piece of a stroke, in pixels, drawn in a state of its
/// own; a shorter one takes its neighbour's.
const double hiddenSliverPx = 1.5;
