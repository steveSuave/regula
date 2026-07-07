import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/label_layout.dart';

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

  test('a non-default labelFontSize grows the rect', () {
    final normal = labelScreenRect(
      point(const ObjectAttributes(name: 'A')),
      viewport,
    )!;
    final large = labelScreenRect(
      point(const ObjectAttributes(name: 'A', labelFontSize: 22)),
      viewport,
    )!;
    expect(large.width, greaterThan(normal.width));
    expect(large.height, greaterThan(normal.height));
    expect(large.topLeft, normal.topLeft,
        reason: 'size changes the extent, not the anchor offset');
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
