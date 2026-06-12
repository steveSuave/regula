import '../construction/construction.dart';
import '../construction/object_attributes.dart';
import 'command.dart';

/// Replaces the attributes of one or more objects; undo restores what
/// each object had before.
///
/// Multi-select edits ("make these five red") are one command: the
/// inspector computes each object's new attributes (typically
/// `copyWith` on its current ones) and passes them keyed by id. The
/// previous attributes are captured at apply time so redo recaptures.
class ChangeAttributesCommand implements Command {
  ChangeAttributesCommand(this.newAttributes);

  final Map<String, ObjectAttributes> newAttributes;

  final Map<String, ObjectAttributes> _previous = {};

  @override
  void apply(Construction construction) {
    // Validate everything up front so a bad id cannot leave the set
    // half-edited.
    for (final id in newAttributes.keys) {
      if (!construction.contains(id)) {
        throw ArgumentError('Unknown object id: $id');
      }
    }
    _previous.clear();
    newAttributes.forEach((id, attributes) {
      _previous[id] = construction.byId(id)!.attributes;
      construction.setAttributes(id, attributes);
    });
  }

  @override
  void undo(Construction construction) {
    _previous.forEach(construction.setAttributes);
  }
}
