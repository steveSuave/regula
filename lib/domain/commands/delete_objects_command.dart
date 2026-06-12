import '../construction/construction.dart';
import '../construction/geo_object.dart';
import 'command.dart';

/// Deletes the objects with [ids], cascading to everything that depends on
/// them; undo restores the full removed set.
///
/// The cascade output is captured during [apply] (not at construction
/// time), so redo recaptures against the construction's then-current
/// state. An id already swept away by an earlier id's cascade — or listed
/// twice — is skipped silently: selections routinely contain both a parent
/// and its dependents.
class DeleteObjectsCommand implements Command {
  DeleteObjectsCommand(this.ids);

  final List<String> ids;

  final List<List<GeoObject>> _removedBatches = [];

  @override
  void apply(Construction construction) {
    _removedBatches.clear();
    for (final id in ids) {
      if (construction.contains(id)) {
        _removedBatches.add(construction.removeWithDependents(id));
      }
    }
  }

  @override
  void undo(Construction construction) {
    // Reverse batch order re-enters each intermediate state of the apply,
    // so every restored object finds its parents already present.
    for (final batch in _removedBatches.reversed) {
      construction.restore(batch);
    }
    _removedBatches.clear();
  }
}
