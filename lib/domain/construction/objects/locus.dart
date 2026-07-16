import 'dart:math' as math;

import '../../math/vec2.dart';
import '../geo_object.dart';
import 'point_on_object.dart';

/// The trace of [traced] as [driver] sweeps its host curve, sampled as a
/// polyline of [sampleCount] positions.
///
/// Recompute is *sweep-and-restore* over [chain] — the transitive
/// ancestors of [traced] that themselves depend on [driver], endpoints
/// included, in topological order, computed once at construction (parent
/// graphs are fixed for an object's lifetime): save the driver's
/// [PointOnObject.parameter]; for each sample set it and recompute the
/// chain in order, recording [traced]'s position; then restore the saved
/// parameter and recompute the chain once. The restore is bit-exact —
/// chain members are pure functions of their parents and parameter — and
/// safe against every graph invariant: `GeoObject.recompute` never
/// notifies (the construction's single notification fires after the whole
/// topological pass this runs inside), the locus sits after its ancestors
/// in topological order so the chain has settled before being perturbed,
/// and a chain can never contain another locus (`PointOnObject` rejects
/// non-line/circle hosts, so no point can descend from one). A pleasing
/// consequence: sliding the driver along its host does not change the
/// locus — the sweep domain is fixed.
///
/// Sampling domain: a circle host is swept one full turn ([sampleCount]
/// uniform angles; the painter closes the loop when gapless); a line host
/// is swept over `[center - halfSpan, center + halfSpan]`, endpoints
/// included, both baked at creation by the tool — the locus sibling of
/// `PointOnObject`'s analytic-parameter caveat (translating the host line
/// along itself shifts the window). Samples where [traced] is undefined
/// become null entries — gaps in the drawn polyline; the locus itself is
/// undefined only while the driver's host has no geometry to sweep.
///
/// Perf note: one recompute costs [sampleCount] × chain-length member
/// recomputes, paid every drag frame that touches an ancestor — fine for
/// realistic chains; revisit with adaptive sampling if it ever isn't.
class Locus extends GeoLocus {
  Locus({
    required super.id,
    required this.driver,
    required this.traced,
    this.sampleCount = 128,
    this.center = 0,
    this.halfSpan = 100,
    super.attributes,
  }) {
    if (sampleCount < 2) {
      throw ArgumentError('Locus sampleCount must be at least 2');
    }
    if (!center.isFinite || !halfSpan.isFinite || halfSpan <= 0) {
      throw ArgumentError(
        'Locus needs a finite center and a positive finite halfSpan',
      );
    }
    _chain = List.unmodifiable(_computeChain(driver, traced));
    if (_chain.length < 2) {
      throw ArgumentError(
        'Locus traced point must (transitively) depend on the driver',
      );
    }
    recompute();
  }

  /// The point whose parameter is swept over the host curve.
  final PointOnObject driver;

  /// The point whose positions the sweep records. Must transitively
  /// depend on [driver] (enforced in the constructor).
  final GeoPoint traced;

  /// Number of sample positions recorded per sweep. At least 2.
  final int sampleCount;

  /// Line hosts only: the sweep covers `[center - halfSpan, center +
  /// halfSpan]` in the host line's arc-length parameter. Baked at
  /// creation; unused (but persisted) for circle hosts.
  final double center;

  /// See [center]. Positive.
  final double halfSpan;

  late final List<GeoObject> _chain;

  /// The objects the sweep recomputes per sample: [driver], [traced] and
  /// every ancestor of [traced] between them, parents before children.
  /// Fixed at construction, like every parent graph. Unmodifiable.
  List<GeoObject> get chain => _chain;

  List<Vec2?>? _samples;

  @override
  List<Vec2?>? get samples => _samples;

  @override
  List<GeoObject> get parents => [driver, traced];

  @override
  void recompute() {
    final parameters = _sampleParameters();
    if (parameters == null) {
      _samples = null;
      return;
    }
    final saved = driver.parameter;
    final samples = List<Vec2?>.filled(sampleCount, null);
    for (var i = 0; i < sampleCount; i++) {
      driver.parameter = parameters[i];
      for (final object in _chain) {
        object.recompute();
      }
      samples[i] = traced.position;
    }
    driver.parameter = saved;
    for (final object in _chain) {
      object.recompute();
    }
    _samples = samples;
  }

  /// The parameter values one sweep visits, or null while the host has no
  /// geometry. A circle host gets [sampleCount] uniform angles over one
  /// full turn (no duplicated closing sample — the painter closes the
  /// loop); a line host gets [sampleCount] uniform values across
  /// `[center - halfSpan, center + halfSpan]`, endpoints included.
  List<double>? _sampleParameters() {
    switch (driver.curve) {
      case GeoCircle(:final circle):
        if (circle == null) {
          return null;
        }
        const tau = 2 * math.pi;
        return [
          for (var i = 0; i < sampleCount; i++) tau * i / sampleCount,
        ];
      case GeoLine(:final line):
        if (line == null) {
          return null;
        }
        final start = center - halfSpan;
        final step = 2 * halfSpan / (sampleCount - 1);
        return [
          for (var i = 0; i < sampleCount; i++) start + step * i,
        ];
      default:
        // Unreachable: PointOnObject only hosts on lines and circles.
        throw StateError('Locus driver must be hosted on a line or circle');
    }
  }

  /// Post-order DFS from [traced] over parent links, restricted to
  /// objects that (transitively) depend on [driver] — parents are
  /// appended before their children, so the result is in topological
  /// order with [driver] first and [traced] last. A diamond is visited
  /// once; ancestors of [traced] that do not depend on [driver] (and
  /// their subtrees' independent branches) are excluded. Empty when
  /// [traced] does not depend on [driver] at all.
  static List<GeoObject> _computeChain(PointOnObject driver, GeoPoint traced) {
    final dependsMemo = <GeoObject, bool>{};
    bool dependsOnDriver(GeoObject object) {
      if (identical(object, driver)) {
        return true;
      }
      return dependsMemo[object] ??= object.parents.any(dependsOnDriver);
    }

    final chain = <GeoObject>[];
    final visited = <GeoObject>{};
    void visit(GeoObject object) {
      if (!visited.add(object) || !dependsOnDriver(object)) {
        return;
      }
      object.parents.forEach(visit);
      chain.add(object);
    }

    visit(traced);
    return chain;
  }
}
