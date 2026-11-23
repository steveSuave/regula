// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experimental_prover_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the prover's surfaces exist at all: "Experimental: prover" in
/// the view menu, off on a fresh install (DECISIONS §"The prover is
/// behind a device preference").
///
/// A preference of the device, beside [themeModeProvider], not of the
/// document: a file opens the same whoever has the prover on. Writes are
/// fire-and-forget like the theme's, and off is stored as no key at all,
/// so an opted-out device and a fresh one hold the same thing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.

@ProviderFor(ExperimentalProverNotifier)
final experimentalProverProvider = ExperimentalProverNotifierProvider._();

/// Whether the prover's surfaces exist at all: "Experimental: prover" in
/// the view menu, off on a fresh install (DECISIONS §"The prover is
/// behind a device preference").
///
/// A preference of the device, beside [themeModeProvider], not of the
/// document: a file opens the same whoever has the prover on. Writes are
/// fire-and-forget like the theme's, and off is stored as no key at all,
/// so an opted-out device and a fresh one hold the same thing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.
final class ExperimentalProverNotifierProvider
    extends $NotifierProvider<ExperimentalProverNotifier, bool> {
  /// Whether the prover's surfaces exist at all: "Experimental: prover" in
  /// the view menu, off on a fresh install (DECISIONS §"The prover is
  /// behind a device preference").
  ///
  /// A preference of the device, beside [themeModeProvider], not of the
  /// document: a file opens the same whoever has the prover on. Writes are
  /// fire-and-forget like the theme's, and off is stored as no key at all,
  /// so an opted-out device and a fresh one hold the same thing.
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
    r'b7f3ac2fb70224a710b3251170c43d0754f45154';

/// Whether the prover's surfaces exist at all: "Experimental: prover" in
/// the view menu, off on a fresh install (DECISIONS §"The prover is
/// behind a device preference").
///
/// A preference of the device, beside [themeModeProvider], not of the
/// document: a file opens the same whoever has the prover on. Writes are
/// fire-and-forget like the theme's, and off is stored as no key at all,
/// so an opted-out device and a fresh one hold the same thing.
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
