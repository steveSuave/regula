import '../commands/add_object_command.dart';
import '../commands/delete_objects_command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/expression_text.dart';
import '../construction/text_evaluator.dart';
import '../construction/text_template.dart';
import 'tool.dart';

/// The text & calculation tool (Phase 58). Unlike every other tool it
/// consumes *dialog-entered* input: the canvas pre-gate (the `DeleteTool`
/// confirm-dialog precedent) opens the content dialog on tap and
/// dispatches a fresh [ToolInput] carrying the string in
/// [ToolInput.text] — so a raw tap (null [text]) is not for this tool
/// and is ignored, and the command still rides the `handleInput` funnel
/// (auto-naming, revision, one undo step).
///
/// A tap over empty canvas creates an [ExpressionText] at the tap
/// position; a tap whose [ToolInput.hit] is an existing [GeoText] edits
/// it — delete + re-add under one [MacroCommand], keeping the id, anchor
/// and attributes (no re-parent primitive exists, and nothing can depend
/// on a text, so the cascade is exactly the text).
///
/// The dialog validated the content, but the construction may have
/// changed under it (undo, a concurrent delete) — any parse or binding
/// failure here quietly returns [ToolIgnored].
class TextTool implements Tool {
  TextTool({required this.newId});

  final String Function() newId;

  @override
  ToolResult onInput(ToolInput input) {
    final content = input.text;
    if (content == null || content.trim().isEmpty) {
      return const ToolIgnored();
    }
    final List<GeoObject> references;
    try {
      references = bindReferences(
        TextTemplate.parse(content).referenceNames,
        input.objects,
      );
    } on FormatException {
      return const ToolIgnored();
    }
    if (input.hit case final GeoText existing) {
      if (!input.objects.any((object) => identical(object, existing))) {
        return const ToolIgnored();
      }
      return ToolCommitted(
        MacroCommand([
          DeleteObjectsCommand([existing.id]),
          AddObjectCommand(
            ExpressionText(
              id: existing.id,
              content: content,
              anchor: existing.anchor,
              references: references,
              attributes: existing.attributes,
            ),
          ),
        ]),
      );
    }
    return ToolCommitted(
      AddObjectCommand(
        ExpressionText(
          id: newId(),
          content: content,
          anchor: input.position,
          references: references,
          // Texts start exactly where tapped: the default 6/−18 label
          // offset is tuned for captions beside a point dot.
          attributes: const ObjectAttributes(labelDx: 0, labelDy: 0),
        ),
      ),
    );
  }

  @override
  void reset() {}
}
