import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/move_text_anchor_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/expression_text.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  test('apply moves the anchor, undo restores it float-exactly', () {
    final construction = Construction();
    final text = ExpressionText(
      id: 't',
      content: 'note',
      anchor: const Vec2(1.25, -3.5),
      references: const [],
    );
    construction.add(text);

    final command = MoveTextAnchorCommand(
      textId: 't',
      from: const Vec2(1.25, -3.5),
      to: const Vec2(40, 17),
    );
    command.apply(construction);
    expect(text.anchor, const Vec2(40, 17));

    command.undo(construction);
    expect(text.anchor, const Vec2(1.25, -3.5));

    command.apply(construction);
    expect(text.anchor, const Vec2(40, 17), reason: 'redo replays forward');
  });

  test('moveTextAnchor rejects non-text targets', () {
    final construction = Construction()
      ..add(FreePoint(id: 'p', position: Vec2.zero));
    expect(
      () => construction.moveTextAnchor('p', const Vec2(1, 1)),
      throwsArgumentError,
    );
    expect(
      () => construction.moveTextAnchor('missing', const Vec2(1, 1)),
      throwsArgumentError,
    );
  });

  test('moving the anchor never touches the rendered value', () {
    final construction = Construction();
    final a = FreePoint(id: 'a', position: Vec2.zero);
    final b = FreePoint(id: 'b', position: const Vec2(3, 4));
    construction
      ..add(a)
      ..add(b);
    final text = ExpressionText(
      id: 't',
      content: '{dist(A, B)}',
      anchor: Vec2.zero,
      references: [a, b],
    );
    construction.add(text);
    expect(text.renderedText, '5.00');

    construction.moveTextAnchor('t', const Vec2(100, 100));
    expect(text.renderedText, '5.00');
    expect(a.position, Vec2.zero, reason: 'referenced geometry stays put');
    expect(b.position, const Vec2(3, 4));
  });
}
