import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('viewportProvider', () {
    test('defaults to origin at 100 %', () {
      expect(container.read(viewportProvider), const ViewportState());
      expect(container.read(viewportProvider).pan, Vec2.zero);
      expect(container.read(viewportProvider).scale, 1);
    });

    test('panBy accumulates, zoomBy multiplies, independently', () {
      final notifier = container.read(viewportProvider.notifier);
      notifier
        ..panBy(const Vec2(3, 4))
        ..panBy(const Vec2(-1, 1))
        ..zoomBy(2)
        ..zoomBy(2);

      final state = container.read(viewportProvider);
      expect(state.pan, const Vec2(2, 5));
      expect(state.scale, 4);
    });

    test('set replaces wholesale; reset restores defaults', () {
      final notifier = container.read(viewportProvider.notifier);
      notifier.set(const ViewportState(pan: Vec2(10, -10), scale: 0.5));
      expect(
        container.read(viewportProvider),
        const ViewportState(pan: Vec2(10, -10), scale: 0.5),
      );

      notifier.reset();
      expect(container.read(viewportProvider), const ViewportState());
    });
  });

  group('ViewportState', () {
    test('value equality', () {
      expect(
        const ViewportState(pan: Vec2(1, 2), scale: 3),
        const ViewportState(pan: Vec2(1, 2), scale: 3),
      );
      expect(
        const ViewportState(pan: Vec2(1, 2), scale: 3),
        isNot(const ViewportState(pan: Vec2(1, 2), scale: 4)),
      );
      expect(
        const ViewportState(pan: Vec2(1, 2), scale: 3),
        isNot(const ViewportState(pan: Vec2(2, 1), scale: 3)),
      );
    });
  });
}
