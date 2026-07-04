import 'package:fgex/application/providers/preferences_provider.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/canvas/geometry_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app scaffold renders the editor', (tester) async {
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
    expect(find.text('fgex'), findsOneWidget);
    expect(find.byType(GeometryCanvas), findsOneWidget);
  });
}
