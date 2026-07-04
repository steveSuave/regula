// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [SharedPreferences] instance.
///
/// Loading it is async, so `main()` awaits `SharedPreferences.getInstance`
/// once before `runApp` and injects it via a `ProviderScope` override —
/// settings providers (theme choice, …) then read stored values
/// synchronously in their `build`. Unoverridden access throws: it means a
/// missing override in `main()` or in a test's container.

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

/// The app's [SharedPreferences] instance.
///
/// Loading it is async, so `main()` awaits `SharedPreferences.getInstance`
/// once before `runApp` and injects it via a `ProviderScope` override —
/// settings providers (theme choice, …) then read stored values
/// synchronously in their `build`. Unoverridden access throws: it means a
/// missing override in `main()` or in a test's container.

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          SharedPreferences,
          SharedPreferences,
          SharedPreferences
        >
    with $Provider<SharedPreferences> {
  /// The app's [SharedPreferences] instance.
  ///
  /// Loading it is async, so `main()` awaits `SharedPreferences.getInstance`
  /// once before `runApp` and injects it via a `ProviderScope` override —
  /// settings providers (theme choice, …) then read stored values
  /// synchronously in their `build`. Unoverridden access throws: it means a
  /// missing override in `main()` or in a test's container.
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'651ca8c07c7a0267605c4421554ee2ffc9467875';
