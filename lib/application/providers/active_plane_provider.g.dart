// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_plane_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The id of the active plane (intent 004, milestone 2), or null for the
/// base plane: the plane a tool's tap lands in and a new free point is
/// placed in.
///
/// Session state, like the space view it belongs to: never saved, the
/// base plane at launch, after File > New or Open, and whenever the
/// space view is turned off. It holds an id, not the plane, so that an
/// undo which removes the plane does not leave a tool working in an
/// object that is gone: read it through [activePlaneOf], which answers
/// the base plane for an id that no longer names a defined plane.

@ProviderFor(ActivePlaneNotifier)
final activePlaneProvider = ActivePlaneNotifierProvider._();

/// The id of the active plane (intent 004, milestone 2), or null for the
/// base plane: the plane a tool's tap lands in and a new free point is
/// placed in.
///
/// Session state, like the space view it belongs to: never saved, the
/// base plane at launch, after File > New or Open, and whenever the
/// space view is turned off. It holds an id, not the plane, so that an
/// undo which removes the plane does not leave a tool working in an
/// object that is gone: read it through [activePlaneOf], which answers
/// the base plane for an id that no longer names a defined plane.
final class ActivePlaneNotifierProvider
    extends $NotifierProvider<ActivePlaneNotifier, String?> {
  /// The id of the active plane (intent 004, milestone 2), or null for the
  /// base plane: the plane a tool's tap lands in and a new free point is
  /// placed in.
  ///
  /// Session state, like the space view it belongs to: never saved, the
  /// base plane at launch, after File > New or Open, and whenever the
  /// space view is turned off. It holds an id, not the plane, so that an
  /// undo which removes the plane does not leave a tool working in an
  /// object that is gone: read it through [activePlaneOf], which answers
  /// the base plane for an id that no longer names a defined plane.
  ActivePlaneNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activePlaneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activePlaneNotifierHash();

  @$internal
  @override
  ActivePlaneNotifier create() => ActivePlaneNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activePlaneNotifierHash() =>
    r'b2b1bd33d38eeaa5cbea674b83e8c2576c990aab';

/// The id of the active plane (intent 004, milestone 2), or null for the
/// base plane: the plane a tool's tap lands in and a new free point is
/// placed in.
///
/// Session state, like the space view it belongs to: never saved, the
/// base plane at launch, after File > New or Open, and whenever the
/// space view is turned off. It holds an id, not the plane, so that an
/// undo which removes the plane does not leave a tool working in an
/// object that is gone: read it through [activePlaneOf], which answers
/// the base plane for an id that no longer names a defined plane.

abstract class _$ActivePlaneNotifier extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
