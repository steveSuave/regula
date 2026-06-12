import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/math/vec2.dart';

part 'viewport_provider.g.dart';

/// Immutable pan/zoom state: [pan] is the world-space point at the canvas
/// origin, [scale] is screen pixels per world unit.
///
/// This is the *state* only. World↔screen transforms (which need screen
/// sizes, i.e. Flutter types) live in the presentation layer's `Viewport`
/// (Phase 5), which is built from this.
class ViewportState {
  const ViewportState({this.pan = Vec2.zero, this.scale = 1});

  final Vec2 pan;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is ViewportState && other.pan == pan && other.scale == scale;

  @override
  int get hashCode => Object.hash(pan, scale);

  @override
  String toString() => 'ViewportState(pan: $pan, scale: $scale)';
}

/// Pan/zoom state for the canvas. Not undoable, not persisted with the
/// construction's undo history (the save format snapshots it separately).
///
/// Zoom-about-a-focal-point and scale clamping are gesture concerns,
/// decided where the gestures land (Phases 5 and 8) — this notifier only
/// stores state.
@Riverpod(keepAlive: true, name: 'viewportProvider')
class ViewportNotifier extends _$ViewportNotifier {
  @override
  ViewportState build() => const ViewportState();

  /// Shifts the pan by [delta] (world units).
  void panBy(Vec2 delta) =>
      state = ViewportState(pan: state.pan + delta, scale: state.scale);

  /// Multiplies the scale by [factor] (> 1 zooms in).
  void zoomBy(double factor) =>
      state = ViewportState(pan: state.pan, scale: state.scale * factor);

  void set(ViewportState viewport) => state = viewport;

  /// Back to origin at 100 %.
  void reset() => state = const ViewportState();
}
