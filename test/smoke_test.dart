import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/preferences_provider.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/canvas/geometry_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wide_window.dart';

void main() {
  testWidgets('app scaffold renders the editor', (tester) async {
    // The 'regula' title only renders in the wide chrome.
    useWideTestWindow(tester);
    // MainApp reads the theme choice, so it needs the same preferences
    // override main() installs.
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MainApp(),
      ),
    );
    expect(find.text('regula'), findsOneWidget);
    expect(find.byType(GeometryCanvas), findsOneWidget);
  });
}
