import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'shortcut_resolver.dart';
import 'shortcut_table.dart';

/// Whether the user is typing in a text field right now. Keyboard
/// shortcuts must stand down then — `P` in an object's name field names
/// the object, it does not switch tools.
bool editableTextHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// Feeds hardware key events to a [ShortcutResolver] over the whole
/// editor and reports matches to [onAction].
///
/// Sits at the editor root so every focused descendant bubbles its key
/// events through here; the node autofocuses so shortcuts work before
/// the first click. Matches (and consumed chord strokes) are marked
/// handled, everything else propagates — space stays available to the
/// canvas's held-space pan, Tab to focus traversal.
///
/// Key auto-repeat only drives bindings that opt in ([ShortcutBinding.
/// repeats]: viewport nudge and zoom); repeats bypass the resolver
/// entirely so a held leader key cannot cancel its own pending chord.
class AppShortcuts extends StatefulWidget {
  const AppShortcuts({super.key, required this.onAction, required this.child});

  final ValueChanged<AppAction> onAction;
  final Widget child;

  /// Puts keyboard focus back on the shortcut layer. The canvas calls
  /// this on pointer-down so that clicking out of a text field both
  /// commits the field (focus-loss commit) and revives the single-letter
  /// shortcuts its focus was suppressing. `unfocus()` would not do:
  /// focus would land on the enclosing *scope*, and key events dispatch
  /// to the primary focus's ancestors — which a scope's children are
  /// not, so shortcuts would go dead instead.
  static void refocus(BuildContext context) => context
      .findAncestorStateOfType<_AppShortcutsState>()
      ?._focusNode
      .requestFocus();

  @override
  State<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends State<AppShortcuts> {
  final ShortcutResolver _resolver = ShortcutResolver(shortcutTable);
  final FocusNode _focusNode = FocusNode(debugLabel: 'AppShortcuts');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimDroppedFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimDroppedFocus);
    _focusNode.dispose();
    super.dispose();
  }

  /// Text fields drop focus onto their enclosing *scope* when left —
  /// Enter's default `unfocus()`, and disposal of a still-focused field
  /// (the name editor is rebuilt under a new key on rename) both do.
  /// A scope's children are not on the key-event dispatch path, so
  /// shortcuts would go dead until the next canvas click. Whenever the
  /// primary focus lands on a scope above this node — focus fell on
  /// "nothing" — take it back. A foreign scope (a dialog's) is not an
  /// ancestor and is left alone.
  void _reclaimDroppedFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary is FocusScopeNode && _focusNode.ancestors.contains(primary)) {
      _focusNode.requestFocus();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (editableTextHasFocus()) {
      // A leader pressed before entering the field must not ambush the
      // first stroke after leaving it.
      _resolver.reset();
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyRepeatEvent) {
      for (final binding in shortcutTable) {
        if (binding.repeats &&
            binding.sequence.length == 1 &&
            binding.sequence[0].matches(
              event.logicalKey,
              shiftDown: keyboard.isShiftPressed,
              controlDown: keyboard.isControlPressed,
              metaDown: keyboard.isMetaPressed,
              altDown: keyboard.isAltPressed,
            )) {
          widget.onAction(binding.action);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    final resolution = _resolver.onStroke(
      event.logicalKey,
      shiftDown: keyboard.isShiftPressed,
      controlDown: keyboard.isControlPressed,
      metaDown: keyboard.isMetaPressed,
      altDown: keyboard.isAltPressed,
    );
    switch (resolution) {
      case ShortcutMatched(:final binding):
        widget.onAction(binding.action);
        return KeyEventResult.handled;
      case ShortcutPending():
      case ShortcutSwallowed():
        return KeyEventResult.handled;
      case ShortcutUnmatched():
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
