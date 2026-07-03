import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../domain/commands/change_attributes_command.dart';
import '../../domain/construction/geo_object.dart';
import 'object_kind_label.dart';

/// Side panel showing the current selection's attributes; collapses to
/// nothing while the selection is empty.
///
/// A single selected object gets its kind as the header plus editable
/// fields (just the name so far — hide/show, color and stroke arrive
/// with their own Phase 7 items). A multi-selection shows the count and
/// a read-only list of what's in it.
///
/// Every edit is one [ChangeAttributesCommand] on the shared stack, so
/// attribute changes undo exactly like geometry changes.
class AttributesInspector extends ConsumerWidget {
  const AttributesInspector({super.key});

  static const double panelWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectionProvider);
    // Watched (not read) so undo/redo of attribute edits refreshes the
    // fields — the revision bumps on every construction change.
    final construction = ref.watch(constructionProvider).construction;
    // The selection prunes deleted ids by *listening*, which can lag this
    // build by a frame — byId's null filters casualties out meanwhile.
    final objects = [
      for (final id in selectedIds)
        if (construction.byId(id) case final GeoObject object) object,
    ];
    if (objects.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final single = objects.length == 1 ? objects.first : null;
    return SizedBox(
      width: panelWidth,
      child: Row(
        children: [
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  single != null
                      ? objectKindLabel(single)
                      : '${objects.length} selected',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (single != null)
                  _NameField(
                    // Keyed by id *and* name: an external change (undo,
                    // selecting another object) swaps the field out for a
                    // fresh one; the user's own typing changes neither.
                    key: ValueKey((single.id, single.attributes.name)),
                    initialName: single.attributes.name,
                    onCommit: (text) => _renameTo(ref, single.id, text),
                  )
                else
                  for (final object in objects)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        object.attributes.name.isEmpty
                            ? objectKindLabel(object)
                            : object.attributes.name,
                      ),
                      subtitle: object.attributes.name.isEmpty
                          ? null
                          : Text(objectKindLabel(object)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Commits a rename as one command; unchanged names (and objects that
  /// vanished between the field's build and its commit) do nothing, so
  /// tabbing through the field never pollutes the undo stack.
  void _renameTo(WidgetRef ref, String id, String text) {
    final object = ref.read(constructionProvider).construction.byId(id);
    final name = text.trim();
    if (object == null || object.attributes.name == name) {
      return;
    }
    ref.read(commandStackProvider.notifier).execute(
          ChangeAttributesCommand({
            id: object.attributes.copyWith(name: name),
          }),
        );
  }
}

/// The name editor: commits on submit and on focus loss. Owns its
/// controller; external name changes replace the whole widget via the
/// parent's key instead of mutating the controller mid-edit.
class _NameField extends StatefulWidget {
  const _NameField({
    super.key,
    required this.initialName,
    required this.onCommit,
  });

  final String initialName;
  final ValueChanged<String> onCommit;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // hasFocus covers the descendant TextField, so this fires when the
      // user clicks away; a double commit after submit is a no-op.
      onFocusChange: (focused) {
        if (!focused) {
          widget.onCommit(_controller.text);
        }
      },
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Name',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onSubmitted: widget.onCommit,
      ),
    );
  }
}
