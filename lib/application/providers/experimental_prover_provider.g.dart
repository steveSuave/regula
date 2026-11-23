// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experimental_prover_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the prover is on: "Prover" under the Experimental header of
/// the geometry menu, off on every fresh load (DECISIONS §"The prover is an
/// experimental toggle in the geometry menu").
///
/// On *is* the prover's panel being open — docked where there is room,
/// a sheet where there is not — so there is no separate Proof button to
/// lose. Session state, like the object tree's visibility, and not
/// stored: a stored "on" would come back on a phone as a prover with no
/// sheet showing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.

@ProviderFor(ExperimentalProverNotifier)
final experimentalProverProvider = ExperimentalProverNotifierProvider._();

/// Whether the prover is on: "Prover" under the Experimental header of
/// the geometry menu, off on every fresh load (DECISIONS §"The prover is an
/// experimental toggle in the geometry menu").
///
/// On *is* the prover's panel being open — docked where there is room,
/// a sheet where there is not — so there is no separate Proof button to
/// lose. Session state, like the object tree's visibility, and not
/// stored: a stored "on" would come back on a phone as a prover with no
/// sheet showing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.
final class ExperimentalProverNotifierProvider
    extends $NotifierProvider<ExperimentalProverNotifier, bool> {
  /// Whether the prover is on: "Prover" under the Experimental header of
  /// the geometry menu, off on every fresh load (DECISIONS §"The prover is an
  /// experimental toggle in the geometry menu").
  ///
  /// On *is* the prover's panel being open — docked where there is room,
  /// a sheet where there is not — so there is no separate Proof button to
  /// lose. Session state, like the object tree's visibility, and not
  /// stored: a stored "on" would come back on a phone as a prover with no
  /// sheet showing.
  ///
  /// **Off tears the prover's state down here, not in the widget that
  /// flips it**, so every route to off gets the same teardown. The
  /// dependency runs one way: this reads the prover's providers and they
  /// never read this.
  ExperimentalProverNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'experimentalProverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$experimentalProverNotifierHash();

  @$internal
  @override
  ExperimentalProverNotifier create() => ExperimentalProverNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$experimentalProverNotifierHash() =>
    r'a4f28f3d468998fd3463ecd67a6d5008d2f2fcbd';

/// Whether the prover is on: "Prover" under the Experimental header of
/// the geometry menu, off on every fresh load (DECISIONS §"The prover is an
/// experimental toggle in the geometry menu").
///
/// On *is* the prover's panel being open — docked where there is room,
/// a sheet where there is not — so there is no separate Proof button to
/// lose. Session state, like the object tree's visibility, and not
/// stored: a stored "on" would come back on a phone as a prover with no
/// sheet showing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.

abstract class _$ExperimentalProverNotifier extends $Notifier<bool> {
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
