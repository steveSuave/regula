import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container the editor can be mounted on: device preferences mocked
/// empty (a fresh install) and injected the way `main()` injects the real
/// ones, so `sharedPreferencesProvider` never throws. Disposed at the end
/// of the test that created it.
Future<ProviderContainer> editorContainer() async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}
