import 'package:fgex/application/providers/viewport_provider.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/presentation/canvas/canvas_viewport.dart';
import 'package:fgex/presentation/canvas/label_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = CanvasViewport(ViewportState());

  FreePoint point(ObjectAttributes attributes) =>
      FreePoint(id: 'p', position: const Vec2(10, -20), attributes: attributes);

  test('the rect sits at worldToScreen(anchor) + the stored offset', () {
    final named = point(
      const ObjectAttributes(name: 'A', labelDx: 14, labelDy: 9),
    );
    final rect = labelScreenRect(named, viewport)!;
    final anchor = viewport.worldToScreen(const Vec2(10, -20));
    expect(rect.topLeft, anchor + const Offset(14, 9));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
  });

  test('the default offset matches the painter\'s historical (6, -18)', () {
    final named = point(const ObjectAttributes(name: 'A'));
    final rect = labelScreenRect(named, viewport)!;
    expect(
      rect.topLeft,
      viewport.worldToScreen(const Vec2(10, -20)) + const Offset(6, -18),
    );
  });

  test('a longer name widens the rect', () {
    final short = labelScreenRect(
      point(const ObjectAttributes(name: 'A')),
      viewport,
    )!;
    final long = labelScreenRect(
      point(const ObjectAttributes(name: 'circumcircle')),
      viewport,
    )!;
    expect(long.width, greaterThan(short.width));
  });

  test('unpainted labels have no rect', () {
    expect(
      labelScreenRect(point(const ObjectAttributes()), viewport),
      isNull,
      reason: 'unnamed',
    );
    expect(
      labelScreenRect(
        point(const ObjectAttributes(name: 'A', labelVisible: false)),
        viewport,
      ),
      isNull,
      reason: 'label hidden',
    );
    expect(
      labelScreenRect(
        point(const ObjectAttributes(name: 'A', visible: false)),
        viewport,
      ),
      isNull,
      reason: 'object hidden',
    );
  });
}
