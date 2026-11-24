import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/space_view_provider.dart';
import 'package:regula/application/providers/viewport_provider.dart';

void main() {
  test('the space view is off at launch and holds what it is set to', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(spaceViewProvider), isFalse);
    container.read(spaceViewProvider.notifier).set(true);
    expect(container.read(spaceViewProvider), isTrue);
    container.read(spaceViewProvider.notifier).set(false);
    expect(container.read(spaceViewProvider), isFalse);
  });

  test('the flag does not move the camera', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(spaceViewProvider.notifier).set(true);
    expect(container.read(viewportProvider), const ViewportState());
  });
}
