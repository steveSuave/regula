import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/change_attributes_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('ChangeAttributesCommand', () {
    Construction buildPair() {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b)
        ..add(Midpoint(id: 'm', point1: a, point2: b));
      return c;
    }

    test('apply edits several objects at once, undo restores each', () {
      final c = buildPair();
      c.setAttributes('a', c.byId('a')!.attributes.copyWith(name: 'A'));
      final cmd = ChangeAttributesCommand({
        'a': c.byId('a')!.attributes.copyWith(colorArgb: 0xFFFF0000),
        'm': c.byId('m')!.attributes.copyWith(colorArgb: 0xFFFF0000),
      });

      cmd.apply(c);
      expect(c.byId('a')!.attributes.colorArgb, 0xFFFF0000);
      expect(c.byId('a')!.attributes.name, 'A');
      expect(c.byId('m')!.attributes.colorArgb, 0xFFFF0000);
      expect(c.byId('b')!.attributes.colorArgb, isNull);

      cmd.undo(c);
      expect(c.byId('a')!.attributes.colorArgb, isNull);
      expect(c.byId('a')!.attributes.name, 'A');
      expect(c.byId('m')!.attributes.colorArgb, isNull);
    });

    test('undo then apply restores the same state (redo)', () {
      final c = buildPair();
      final cmd = ChangeAttributesCommand({
        'b': c.byId('b')!.attributes.copyWith(visible: false, name: 'B'),
      });

      cmd.apply(c);
      cmd.undo(c);
      cmd.apply(c);
      expect(c.byId('b')!.attributes.visible, isFalse);
      expect(c.byId('b')!.attributes.name, 'B');
    });

    test('rejects unknown ids before editing anything', () {
      final c = buildPair();
      final cmd = ChangeAttributesCommand({
        'a': c.byId('a')!.attributes.copyWith(name: 'A'),
        'ghost': const ObjectAttributes(),
      });

      expect(() => cmd.apply(c), throwsArgumentError);
      // Up-front validation: `a` was not edited.
      expect(c.byId('a')!.attributes.name, isEmpty);
    });
  });
}
