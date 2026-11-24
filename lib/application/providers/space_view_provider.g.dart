// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(SpaceViewNotifier)
final spaceViewProvider = SpaceViewNotifierProvider._();

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
final class SpaceViewNotifierProvider
    extends $NotifierProvider<SpaceViewNotifier, bool> {
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
  SpaceViewNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spaceViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spaceViewNotifierHash();

  @$internal
  @override
  SpaceViewNotifier create() => SpaceViewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$spaceViewNotifierHash() => r'18c6435c229fd4621b7a6df764aa131d95663f02';

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

abstract class _$SpaceViewNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
