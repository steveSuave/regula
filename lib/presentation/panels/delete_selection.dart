import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../domain/commands/delete_objects_command.dart';
import '../../domain/construction/geo_object.dart';
import 'object_kind_label.dart';

/// Deletes [objects] as one [DeleteObjectsCommand] (one undo step).
/// Shared by the inspector's Delete button and the Del/Backspace
/// shortcut, so both give the same cascade warning.
///
/// Deletion cascades to everything depending on the selection, so when
/// the cascade reaches *beyond* it, a dialog lists exactly which
/// unselected objects would go too and asks first. A self-contained
/// selection (dependents all selected, or none) deletes immediately —
/// the user already sees everything that will disappear.
Future<void> deleteSelectionWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  List<GeoObject> objects,
) async {
  final construction = ref.read(constructionProvider).construction;
  final ids = [for (final object in objects) object.id];
  final doomed = {
    for (final id in ids) ...construction.transitiveDependentsOf(id),
  }..removeAll(ids);
  if (doomed.isNotEmpty) {
    // Insertion order, like every other listing of objects.
    final casualties = [
      for (final object in construction.objects)
        if (doomed.contains(object.id)) object,
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete dependent objects too?'),
        content: Text(
          '${casualties.length == 1 ? 'This object depends' : 'These '
                    '${casualties.length} objects depend'} on the selection '
          'and will also be deleted:\n\n'
          '${casualties.map(_displayLabel).join(', ')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
  }
  // The construction can have changed while the dialog was up; an
  // all-gone selection must not put an empty delete on the undo stack.
  if (!ids.any(construction.contains)) {
    return;
  }
  ref.read(commandStackProvider.notifier).execute(DeleteObjectsCommand(ids));
}

String _displayLabel(GeoObject object) => object.attributes.name.isEmpty
    ? objectKindLabel(object)
    : object.attributes.name;
