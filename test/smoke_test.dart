import 'package:fgex/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app scaffold renders', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
