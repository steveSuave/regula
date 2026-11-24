import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'space_view_provider.g.dart';

/// Whether the canvas is in the space view (intent 004): the camera is
/// unlocked, and a one-finger drag that would open the rubber band turns
/// the figure instead.
///
/// Session state, off at launch and never saved: a document reopens as
/// the planar figure it is. It is a flag of its own rather than "the
/// viewport is tilted", because looking straight down is a legitimate
/// space view — the Top preset — and the gesture must not change meaning
/// as the camera passes through it.
///
/// The flag does not move the camera. Whoever flips it also sets the
/// viewport (`enterSpaceView` / `leaveSpaceView` in the presentation
/// layer, which need the canvas size), so that off always means tilt 0.
@Riverpod(keepAlive: true, name: 'spaceViewProvider')
class SpaceViewNotifier extends _$SpaceViewNotifier {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}
