import 'package:fgex/presentation/shortcuts/shortcut_table.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether some physical key press could match both strokes: same key,
/// same primary requirement, and shift requirements that intersect
/// (`null` is a wildcard intersecting everything).
bool _overlaps(KeyStroke a, KeyStroke b) =>
    a.key == b.key &&
    a.primary == b.primary &&
    (a.shift == null || b.shift == null || a.shift == b.shift);

void main() {
  test('no two bindings are ambiguous', () {
    for (var i = 0; i < shortcutTable.length; i++) {
      for (var j = i + 1; j < shortcutTable.length; j++) {
        final a = shortcutTable[i];
        final b = shortcutTable[j];
        if (a.sequence.length != b.sequence.length) {
          continue;
        }
        final collides = [
          for (var k = 0; k < a.sequence.length; k++)
            _overlaps(a.sequence[k], b.sequence[k]),
        ].every((overlap) => overlap);
        expect(
          collides && a.action != b.action,
          isFalse,
          reason:
              '"${a.label}" (${a.display}) and "${b.label}" '
              '(${b.display}) match the same keys for different actions',
        );
        expect(
          collides,
          isFalse,
          reason: '"${a.label}" and "${b.label}" are duplicate bindings',
        );
      }
    }
  });

  test('chord leaders are not shadowed by single-stroke bindings', () {
    // The resolver gives single strokes priority, so a leader that also
    // matched a single-stroke binding would make its chords unreachable.
    final singles = [
      for (final binding in shortcutTable)
        if (binding.sequence.length == 1) binding,
    ];
    for (final binding in shortcutTable) {
      if (binding.sequence.length != 2) {
        continue;
      }
      for (final single in singles) {
        expect(
          _overlaps(binding.sequence[0], single.sequence[0]),
          isFalse,
          reason:
              'Leader of "${binding.label}" (${binding.display}) is '
              'shadowed by "${single.label}" (${single.display})',
        );
      }
    }
  });

  test('every action is bound, and visible in the cheat sheet', () {
    // The nudge directions share one visible row ("← ↑ ↓ →" on the
    // arrow-left binding); the other three are deliberately hidden.
    const foldedIntoASiblingRow = {
      AppAction.nudgeRight,
      AppAction.nudgeUp,
      AppAction.nudgeDown,
    };
    for (final action in AppAction.values) {
      final bindings = [
        for (final binding in shortcutTable)
          if (binding.action == action) binding,
      ];
      expect(bindings, isNotEmpty, reason: '$action has no binding');
      if (!foldedIntoASiblingRow.contains(action)) {
        expect(
          bindings.any((binding) => binding.showInCheatSheet),
          isTrue,
          reason: '$action is invisible in the cheat sheet',
        );
      }
    }
  });

  test('labels and displays are non-empty, sequences one or two strokes', () {
    for (final binding in shortcutTable) {
      expect(binding.label, isNotEmpty);
      expect(binding.display, isNotEmpty);
      expect(binding.sequence.length, inInclusiveRange(1, 2));
    }
  });

  test('only viewport bindings auto-repeat', () {
    for (final binding in shortcutTable) {
      if (binding.repeats) {
        expect(
          binding.section,
          ShortcutSection.viewport,
          reason: '"${binding.label}" repeats but is not a viewport action',
        );
      }
    }
  });

  test('KeyStroke.matches honours each modifier axis', () {
    const plain = KeyStroke(LogicalKeyboardKey.keyH);
    const shifted = KeyStroke(LogicalKeyboardKey.keyH, shift: true);
    const either = KeyStroke(LogicalKeyboardKey.equal, shift: null);
    const primary = KeyStroke(LogicalKeyboardKey.keyZ, primary: true);

    bool match(
      KeyStroke stroke,
      LogicalKeyboardKey key, {
      bool shift = false,
      bool control = false,
      bool meta = false,
      bool alt = false,
    }) => stroke.matches(
      key,
      shiftDown: shift,
      controlDown: control,
      metaDown: meta,
      altDown: alt,
    );

    expect(match(plain, LogicalKeyboardKey.keyH), isTrue);
    expect(match(plain, LogicalKeyboardKey.keyG), isFalse);
    expect(match(plain, LogicalKeyboardKey.keyH, shift: true), isFalse);
    expect(match(plain, LogicalKeyboardKey.keyH, control: true), isFalse);
    expect(match(plain, LogicalKeyboardKey.keyH, alt: true), isFalse);

    expect(match(shifted, LogicalKeyboardKey.keyH, shift: true), isTrue);
    expect(match(shifted, LogicalKeyboardKey.keyH), isFalse);

    expect(match(either, LogicalKeyboardKey.equal), isTrue);
    expect(match(either, LogicalKeyboardKey.equal, shift: true), isTrue);
    expect(match(either, LogicalKeyboardKey.equal, meta: true), isFalse);

    expect(match(primary, LogicalKeyboardKey.keyZ, control: true), isTrue);
    expect(match(primary, LogicalKeyboardKey.keyZ, meta: true), isTrue);
    expect(match(primary, LogicalKeyboardKey.keyZ), isFalse);
    expect(
      match(primary, LogicalKeyboardKey.keyZ, control: true, alt: true),
      isFalse,
    );
  });
}
