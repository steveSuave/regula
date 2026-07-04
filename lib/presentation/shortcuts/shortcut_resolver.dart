import 'package:flutter/services.dart';

import 'shortcut_table.dart';

/// What the resolver decided about one key stroke; see
/// [ShortcutResolver.onStroke].
sealed class ShortcutResolution {
  const ShortcutResolution();
}

/// The stroke completed a binding: perform [binding]'s action.
class ShortcutMatched extends ShortcutResolution {
  const ShortcutMatched(this.binding);

  final ShortcutBinding binding;
}

/// The stroke was a chord leader (`G`, `X`): consumed, awaiting the
/// second stroke.
class ShortcutPending extends ShortcutResolution {
  const ShortcutPending();
}

/// The stroke was consumed without effect — a second chord stroke that
/// matched no binding, or Esc cancelling a pending leader. Swallowed
/// rather than re-resolved standalone: firing the segment tool because
/// `G S` missed would be a surprise, not a convenience.
class ShortcutSwallowed extends ShortcutResolution {
  const ShortcutSwallowed();
}

/// Not a shortcut: let the event propagate (focus traversal, the
/// canvas's held-space pan, button activation).
class ShortcutUnmatched extends ShortcutResolution {
  const ShortcutUnmatched();
}

/// Pure modifier presses never resolve and never cancel a pending
/// leader — holding Shift while aiming for the chord's second stroke is
/// legitimate.
final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
};

/// Matches key strokes against a shortcut table, one stroke at a time,
/// carrying the state a two-stroke leader chord needs in between.
///
/// Pure Dart-level logic (no widgets, no `HardwareKeyboard`): the
/// caller passes the modifier state alongside each key, which keeps the
/// resolver unit-testable and the widget layer trivial.
///
/// A pending leader has no timeout — like a Vim leader, it waits until
/// the next non-modifier stroke or Esc. There is deliberately no
/// visible pending-state UI yet; add one if chords prove hard to trust.
class ShortcutResolver {
  ShortcutResolver(this.table);

  final List<ShortcutBinding> table;

  /// Chord bindings whose leader stroke was consumed; empty when idle.
  List<ShortcutBinding> _pending = const [];

  bool get hasPendingLeader => _pending.isNotEmpty;

  /// Forgets a consumed leader (tool switches by mouse, focus loss).
  void reset() => _pending = const [];

  ShortcutResolution onStroke(
    LogicalKeyboardKey key, {
    required bool shiftDown,
    required bool controlDown,
    required bool metaDown,
    required bool altDown,
  }) {
    if (_modifierKeys.contains(key)) {
      return const ShortcutUnmatched();
    }

    bool matches(KeyStroke stroke) => stroke.matches(
      key,
      shiftDown: shiftDown,
      controlDown: controlDown,
      metaDown: metaDown,
      altDown: altDown,
    );

    if (_pending.isNotEmpty) {
      final candidates = _pending;
      _pending = const [];
      if (key == LogicalKeyboardKey.escape) {
        return const ShortcutSwallowed();
      }
      for (final binding in candidates) {
        if (matches(binding.sequence[1])) {
          return ShortcutMatched(binding);
        }
      }
      return const ShortcutSwallowed();
    }

    // Single-stroke bindings win over same-key leaders, so a leader key
    // could still be bound standalone if a future table wants that; the
    // table test currently keeps G and X chord-only.
    for (final binding in table) {
      if (binding.sequence.length == 1 && matches(binding.sequence[0])) {
        return ShortcutMatched(binding);
      }
    }
    final chords = [
      for (final binding in table)
        if (binding.sequence.length == 2 && matches(binding.sequence[0]))
          binding,
    ];
    if (chords.isNotEmpty) {
      _pending = chords;
      return const ShortcutPending();
    }
    return const ShortcutUnmatched();
  }
}
