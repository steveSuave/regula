import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/experimental_prover_provider.dart';
import 'package:regula/application/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container the editor can be mounted on: device preferences mocked
/// empty (a fresh install) and injected the way `main()` injects the real
/// ones, so `sharedPreferencesProvider` never throws. Disposed at the end
/// of the test that created it.
///
/// [prover] stores the intent 003 opt-in, for tests of the prover's
/// surfaces, which a fresh install does not show.
Future<ProviderContainer> editorContainer({bool prover = false}) async {
  SharedPreferences.setMockInitialValues({
    if (prover) ExperimentalProverNotifier.prefsKey: true,
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}
