import '../construction/construction.dart';
import '../construction/geo_object.dart';
import 'command.dart';

/// Adds a single object to the construction; undo removes it again.
///
/// The command holds the [object] instance itself (not a description of
/// it), so redo re-adds the very same instance and dependents created
/// later keep pointing at it.
class AddObjectCommand implements Command {
  AddObjectCommand(this.object);

  final GeoObject object;

  @override
  void apply(Construction construction) => construction.add(object);

  @override
  void undo(Construction construction) {
    final removed = construction.removeWithDependents(object.id);
    // LIFO undo means nothing built on this object can still exist: any
    // dependent was added by a later command, which was undone first.
    assert(
      removed.length == 1,
      'Undo of AddObjectCommand(${object.id}) removed dependents '
      '${removed.map((o) => o.id).skip(1).toList()} — commands were undone '
      'out of order',
    );
  }
}
