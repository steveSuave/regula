import 'dart:math' as math;

import '../../math/vec2.dart';
import '../geo_object.dart';
import 'intersection_point.dart';
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
/// The uniform sweep is post-processed for fidelity (Phase 39b — see
/// [_trace] and [_walk]): circle-host runs are grouped cyclically so no
/// stroke splits at the 0/2π wrap, defined↔undefined boundaries are
/// bisected and given extra samples clustered toward them, and a
/// boundary caused by a chain [IntersectionPoint]'s candidates
/// coalescing (a tangency) is walked *through* by reversing the sweep
/// and flipping that branch — the physical-linkage continuation, which
/// closes figure-eight-style loci. Branch flips are sweep-internal:
/// [IntersectionPoint.branchIndex] is restored (with [driver]'s
/// parameter) before recompute returns, so drag and save semantics keep
/// the deterministic persisted branch. Consequently [samples] is not
/// aligned to the uniform grid and its length varies; [sampleCount] is
/// the uniform resolution the post-processing starts from.
///
/// Perf note: one recompute costs roughly [sampleCount] × chain-length
/// member recomputes — 2–3× that for loci with refined or flipped
/// boundaries — paid every drag frame that touches an ancestor. Fine
/// for realistic chains; revisit with adaptive sampling if it ever
/// isn't.
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
    final savedParameter = driver.parameter;
    final savedBranches = <IntersectionPoint, int>{
      for (final object in _chain)
        if (object is IntersectionPoint) object: object.branchIndex,
    };
    final samples = _trace(parameters);
    savedBranches.forEach((point, branch) => point.branchIndex = branch);
    driver.parameter = savedParameter;
    for (final object in _chain) {
      object.recompute();
    }
    _samples = samples;
  }

  /// Sets the driver to [parameter], recomputes the chain in topological
  /// order and returns the traced position (null while undefined) — one
  /// step of the sweep. Total: safe to call at any parameter, in any
  /// order, under any branch assignment.
  Vec2? _evalAt(double parameter) {
    driver.parameter = parameter;
    for (final object in _chain) {
      object.recompute();
    }
    return traced.position;
  }

  /// The full trace (Phase 39b). A uniform sweep first; when it is
  /// entirely defined or entirely undefined the uniform list is returned
  /// as-is — a gapless full-turn circle host stays exactly the list the
  /// painter closes into a loop. Otherwise the defined runs (grouped
  /// *cyclically* on circle hosts, so a run straddling the 0/2π wrap is
  /// one stroke) each become a component via [_walk]; components are
  /// separated by single nulls.
  List<Vec2?> _trace(List<double> parameters) {
    final positions = [for (final t in parameters) _evalAt(t)];
    final anyDefined = positions.any((p) => p != null);
    final anyGap = positions.contains(null);
    if (!anyDefined || !anyGap) {
      return positions;
    }
    final out = <Vec2?>[];
    for (final run in _runs(parameters, positions)) {
      if (out.isNotEmpty) {
        out.add(null);
      }
      out.addAll(_walk(run));
    }
    return out;
  }

  /// Groups the defined uniform samples into runs. On a circle host the
  /// index space is cyclic: iteration starts at a gap, so no run is ever
  /// split by the array wrap, and the second part of a wrapped run gets
  /// its parameters unwrapped by +2π to keep each run's parameter list
  /// monotone (the host geometry is 2π-periodic, so evaluation agrees).
  /// Every run ends in a gap parameter or, on line hosts, the sweep
  /// window's edge (null — an open end, not a boundary to refine).
  List<_Run> _runs(List<double> parameters, List<Vec2?> positions) {
    final n = positions.length;
    final cyclic = driver.curve is GeoCircle;
    final first = cyclic ? positions.indexWhere((p) => p == null) : 0;
    double parameterAt(int slot) {
      final index = (first + slot) % n;
      final unwrap = cyclic && first + slot >= n ? 2 * math.pi : 0.0;
      return parameters[index] + unwrap;
    }

    final runs = <_Run>[];
    List<double>? current;
    double? leftGap;
    for (var slot = 0; slot < n; slot++) {
      if (positions[(first + slot) % n] != null) {
        if (current == null) {
          current = [];
          leftGap = slot == 0 ? null : parameterAt(slot - 1);
        }
        current.add(parameterAt(slot));
      } else if (current != null) {
        runs.add(
            _Run(current, leftGap: leftGap, rightGap: parameterAt(slot)));
        current = null;
      }
    }
    if (current != null) {
      // A run touching the last slot: the window's right edge on a line
      // host (open end); on a circle host the slot past it is the gap
      // the cyclic iteration started at, one unwrapped turn up.
      runs.add(_Run(current,
          leftGap: leftGap, rightGap: cyclic ? parameterAt(n) : null));
    }
    return runs;
  }

  /// Traces one defined run into a polyline component.
  ///
  /// Gap-adjacent ends are refined by [_refineBoundary]: the boundary is
  /// bisected and the run gains samples geometrically clustered toward
  /// it — near a tangency the traced point moves like √ε per parameter
  /// step, so the uniform grid alone visibly truncates the curve.
  ///
  /// When a boundary is a *tangency* — a chain [IntersectionPoint] whose
  /// two candidates coalesced — the walk continues through it the way
  /// the physical linkage would (the Cinderella behavior, done with real
  /// arithmetic and scoped to this sweep): reverse direction and flip
  /// that intersection's branch.
  ///
  /// Flipped sheets survive **only when the walk closes** — parity back
  /// to the original assignment *and* the trace geometrically rejoining
  /// its start (see [_closes]) — because a closed continuation is a
  /// genuine closed curve of the mechanism (the figure-eight, the full
  /// circle), while an open walk that ends still-flipped dangles into
  /// positions the app's deterministic-branch dragging can never reach,
  /// which reads as phantom curves (Phase 39c, user feedback on 39b).
  /// Any non-closing termination — an open end or non-flip boundary
  /// reached while flipped, an undefined sample mid-segment, the
  /// [_maxWalkSegments] budget, a closed parity whose geometry misses
  /// the join (a downstream branch-ordering swap) — trims the component
  /// back to the last sample taken under the original assignment: never
  /// wrong ink, at worst exactly the branch-fixed trace with refined
  /// boundaries.
  List<Vec2> _walk(_Run run) {
    final left = run.leftGap == null
        ? null
        : _refineBoundary(run.params.first, run.leftGap!);
    final right = run.rightGap == null
        ? null
        : _refineBoundary(run.params.last, run.rightGap!);
    final ascending = <double>[
      ...?left?.ladder.reversed,
      ...run.params,
      ...?right?.ladder,
    ];

    // Start at an open end when there is one, so the original-assignment
    // segment traverses the whole run before any flip.
    var direction = right?.flip == null && left?.flip != null ? -1 : 1;
    final out = <Vec2>[];
    final flipped = <IntersectionPoint>{};
    var lastOriginalEnd = 0;
    // Every non-closing exit must undo the walk's outstanding flips —
    // the global restore only runs after *all* runs are traced, and a
    // leaked flip would put the next run's walk on a mirror sheet.
    List<Vec2> open() {
      if (flipped.isEmpty) {
        return out;
      }
      for (final point in flipped) {
        point.branchIndex = 1 - point.branchIndex;
      }
      return out.sublist(0, lastOriginalEnd);
    }

    for (var segment = 0; segment < _maxWalkSegments; segment++) {
      final params =
          direction > 0 ? ascending : ascending.reversed.toList();
      for (final t in params) {
        final p = _evalAt(t);
        if (p == null) {
          return open();
        }
        out.add(p);
      }
      if (flipped.isEmpty) {
        lastOriginalEnd = out.length;
      }
      final arrival = direction > 0 ? right : left;
      final flip = arrival?.flip;
      if (flip == null) {
        return open();
      }
      flip.branchIndex = 1 - flip.branchIndex;
      if (!flipped.remove(flip)) {
        flipped.add(flip);
      }
      if (flipped.isEmpty) {
        // Original assignment again, back at the starting end.
        if (_closes(out)) {
          out.add(out.first);
          return out;
        }
        return out.sublist(0, lastOriginalEnd);
      }
      direction = -direction;
    }
    return open();
  }

  /// Whether a parity-closed walk geometrically rejoins its start: the
  /// endpoints must sit within a small fraction of the trace's extent.
  /// At a coalescence the traced limit is branch-independent, so a
  /// correctly-continued walk ends where it began; a miss means some
  /// downstream member landed on the wrong sheet.
  static bool _closes(List<Vec2> out) {
    var minX = out.first.x, maxX = out.first.x;
    var minY = out.first.y, maxY = out.first.y;
    for (final p in out) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final extent = Vec2(maxX - minX, maxY - minY).norm;
    return out.first.distanceTo(out.last) <= math.max(extent * 0.05, 1e-9);
  }

  static const _maxWalkSegments = 8;
  static const _boundaryBisections = 48;
  static const _ladderSize = 6;

  /// Locates the defined↔undefined boundary between [tIn] (defined) and
  /// [tOut] (undefined) by bisection, and classifies it: when the first
  /// undefined chain member just past the boundary is an
  /// [IntersectionPoint] that has two candidates strictly *inside* the
  /// run, the boundary is a tangency (two continuous real roots can only
  /// vanish by coalescing) and [_Boundary.flip] names the intersection
  /// to flip; anything else (a line∩line gone parallel, a derived member
  /// undefined for its own reasons) is a genuine end. The two-candidate
  /// probe deliberately sits half a grid step inside — at the boundary
  /// itself the epsilon-tolerant intersection math reports a *tangent*
  /// (one candidate), and the uniform grid can even land exactly on the
  /// tangency, so probing at [tIn] or the bisected boundary misreads
  /// coalescence as a genuine end.
  /// [_Boundary.ladder] holds extra sample parameters from [tIn] toward
  /// the boundary, geometrically clustered, boundary last.
  _Boundary _refineBoundary(double tIn, double tOut) {
    var lo = tIn, hi = tOut;
    for (var i = 0; i < _boundaryBisections; i++) {
      final mid = (lo + hi) / 2;
      if (mid == lo || mid == hi) {
        break;
      }
      if (_evalAt(mid) != null) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    // The culprit scan runs at [tOut] (the undefined uniform sample),
    // not at the bisected `hi`: on the razor's edge past the boundary an
    // intersection can linger epsilon-defined while a *downstream*
    // member has already degenerated, misattributing the gap.
    _evalAt(tOut);
    GeoObject? culprit;
    for (final object in _chain) {
      if (!object.isDefined) {
        culprit = object;
        break;
      }
    }
    IntersectionPoint? flip;
    if (culprit is IntersectionPoint) {
      _evalAt(tIn - (tOut - tIn) / 2);
      if (culprit.candidateCount == 2) {
        flip = culprit;
      }
    }
    final ladder = <double>[
      for (var k = 1; k < _ladderSize; k++)
        tIn + (lo - tIn) * (1 - math.pow(2, -k)),
      lo,
    ];
    return _Boundary(ladder, flip);
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

/// One defined run of the uniform sweep: its sample parameters in
/// monotone order, plus the adjacent undefined parameter on each side —
/// null when the run ends at the sweep window's edge instead of a gap.
class _Run {
  _Run(this.params, {required this.leftGap, required this.rightGap});

  final List<double> params;
  final double? leftGap;
  final double? rightGap;
}

/// A refined defined↔undefined boundary: extra sample [ladder]
/// parameters clustered toward the bisected boundary (boundary last),
/// and, when the boundary is a tangency, the chain intersection whose
/// branch the linkage continuation flips to walk through it.
class _Boundary {
  _Boundary(this.ladder, this.flip);

  final List<double> ladder;
  final IntersectionPoint? flip;
}
