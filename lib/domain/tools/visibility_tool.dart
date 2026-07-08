import '../commands/change_attributes_command.dart';
import 'tool.dart';

/// Which way a [VisibilityTool] flips the `visible` flag.
enum VisibilityMode { hide, showHide }

/// The Phase 30 tap-driven visibility tool, replacing the old
/// hide-selection / reveal-all key actions (the named-constructor
/// variants follow the `TransformObjectTool` precedent).
///
/// **Hide** (`H`): each tap on a visible object hides it; hidden objects
/// are not hit-testable in this mode, so taps can only ever hide.
/// **Show/Hide** (`Shift+H`): the canvas renders hidden objects dimmed
/// and lets them be hit (see [revealsHidden]), and each tap *toggles*
/// the hit object's flag — a dimmed object reappears, tap again re-hides.
///
/// Every tap is exactly one `ChangeAttributesCommand` = one undo step;
/// empty-canvas taps do nothing. The tool is stateless — there is
/// nothing to collect, so [reset] is a no-op and no previews render.
class VisibilityTool implements Tool {
  VisibilityTool.hide() : mode = VisibilityMode.hide;

  VisibilityTool.showHide() : mode = VisibilityMode.showHide;

  final VisibilityMode mode;

  /// Whether hidden objects should be visible to the user while this
  /// tool is active: the canvas draws them dimmed and includes them in
  /// hit testing. Show/Hide's whole point; Hide leaves them untouchable.
  bool get revealsHidden => mode == VisibilityMode.showHide;

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (hit == null) {
      return const ToolIgnored();
    }
    // Hide never un-hides. Unreachable through the canvas (hidden objects
    // aren't hit-testable in this mode), but the tool must not rely on
    // its caller's hit-test policy.
    if (mode == VisibilityMode.hide && !hit.attributes.visible) {
      return const ToolIgnored();
    }
    return ToolCommitted(
      ChangeAttributesCommand({
        hit.id: hit.attributes.copyWith(visible: !hit.attributes.visible),
      }),
    );
  }

  @override
  void reset() {
    // Stateless: every tap stands alone.
  }
}
