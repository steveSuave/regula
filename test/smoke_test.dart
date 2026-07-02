import 'package:fgex/main.dart';
import 'package:fgex/presentation/canvas/geometry_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app scaffold renders the editor', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    expect(find.text('fgex'), findsOneWidget);
    expect(find.byType(GeometryCanvas), findsOneWidget);
  });
}
