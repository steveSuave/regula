import 'geo_object.dart';

/// Automatic object naming (Phase 23).
///
/// Pure first-free allocator: given the set of names already present in the
/// construction, returns the first free name from the pool matching the
/// object's kind:
///
/// - points: `A … Z`, then `A1 … Z1`, `A2 …`
/// - lines, circles, polygons *and* measurements (one shared pool):
///   `a … z`, then `a1 … z1`, `a2 …`
/// - angles: `α … ω`, then `α1 … ω1`, `α2 …`
///
/// Scanning the *used names* rather than a counter means deleted names are
/// reused, File > Open just works (the scan sees whatever the file brought),
/// and nothing depends on object ids (uuid.v4 has no order). Manual renames
/// are simply skipped over — any string can occupy a slot.
String nextAutoName(Set<String> usedNames, GeoObject object) {
  final pool = switch (object) {
    GeoPoint() => _upperLatin,
    GeoLine() || GeoCircle() || GeoPolygon() || GeoMeasurement() =>
      _lowerLatin,
    GeoAngle() => _lowerGreek,
  };
  for (var round = 0;; round++) {
    final suffix = round == 0 ? '' : '$round';
    for (final letter in pool) {
      final candidate = '$letter$suffix';
      if (!usedNames.contains(candidate)) return candidate;
    }
  }
}

/// The replacement name for an object evicted from [wanted] by a manual
/// rename (Phase 27).
///
/// The wanted name's trailing digit run is stripped to get the base
/// (`A1` → `A`, plain `A` → `A`), and the first of `base1`, `base2`, …
/// that is neither in [usedNames] nor the wanted name itself is
/// returned. An all-digit name keeps itself as the base (`12` → `121`)
/// rather than degenerating to bare counters.
String evictedName(Set<String> usedNames, String wanted) {
  final stripped = wanted.replaceFirst(RegExp(r'\d+$'), '');
  final base = stripped.isEmpty ? wanted : stripped;
  for (var n = 1;; n++) {
    final candidate = '$base$n';
    if (candidate != wanted && !usedNames.contains(candidate)) {
      return candidate;
    }
  }
}

const _upperLatin = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

const _lowerLatin = [
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', //
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
];

/// Lowercase Greek, final-sigma (ς) excluded.
const _lowerGreek = [
  'α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ', 'ι', 'κ', 'λ', 'μ', //
  'ν', 'ξ', 'ο', 'π', 'ρ', 'σ', 'τ', 'υ', 'φ', 'χ', 'ψ', 'ω',
];
