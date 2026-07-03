import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../domain/commands/change_attributes_command.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/object_attributes.dart';
import 'object_kind_label.dart';

/// Side panel showing the current selection's attributes; collapses to
/// nothing while the selection is empty.
///
/// A single selected object gets its kind as the header plus editable
/// fields (name, visibility, label visibility — color and stroke arrive
/// with their own Phase 7 items). A multi-selection shows the count, the
/// same toggles applied to the whole selection (a dash means the values
/// are mixed; a tap resolves mixed to all-on), and a read-only list of
/// what's in it.
///
/// Hiding a selected object does not deselect it: hidden objects can't
/// be hit on the canvas, so staying in the inspector is the way back to
/// un-hiding until the object tree panel lands.
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
                if (single != null) ...[
                  _NameField(
                    // Keyed by id *and* name: an external change (undo,
                    // selecting another object) swaps the field out for a
                    // fresh one; the user's own typing changes neither.
                    key: ValueKey((single.id, single.attributes.name)),
                    initialName: single.attributes.name,
                    onCommit: (text) => _renameTo(ref, single.id, text),
                  ),
                  const SizedBox(height: 8),
                ],
                _AttributeToggle(
                  label: 'Visible',
                  values: [
                    for (final object in objects) object.attributes.visible,
                  ],
                  onChanged: (value) => _setForAll(
                    ref,
                    objects,
                    (attributes) => attributes.copyWith(visible: value),
                  ),
                ),
                _AttributeToggle(
                  label: 'Show label',
                  values: [
                    for (final object in objects)
                      object.attributes.labelVisible,
                  ],
                  onChanged: (value) => _setForAll(
                    ref,
                    objects,
                    (attributes) => attributes.copyWith(labelVisible: value),
                  ),
                ),
                if (single == null) ...[
                  const Divider(),
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

  /// Applies [change] to every selected object in one command, so a
  /// multi-object toggle undoes as a single step. Objects re-read by id
  /// at commit time (cf. [_renameTo]); ones the change leaves untouched
  /// stay out of the command.
  void _setForAll(
    WidgetRef ref,
    List<GeoObject> objects,
    ObjectAttributes Function(ObjectAttributes) change,
  ) {
    final construction = ref.read(constructionProvider).construction;
    final updates = <String, ObjectAttributes>{};
    for (final stale in objects) {
      final object = construction.byId(stale.id);
      if (object == null) {
        continue;
      }
      final updated = change(object.attributes);
      if (updated != object.attributes) {
        updates[object.id] = updated;
      }
    }
    if (updates.isEmpty) {
      return;
    }
    ref
        .read(commandStackProvider.notifier)
        .execute(ChangeAttributesCommand(updates));
  }
}

/// One boolean attribute over the whole selection, as a checkbox row.
///
/// All-on shows checked, all-off unchecked, mixed the tristate dash.
/// Tapping ignores Flutter's three-way cycle: anything but all-on turns
/// everything on; all-on turns everything off.
class _AttributeToggle extends StatelessWidget {
  const _AttributeToggle({
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final List<bool> values;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final allOn = values.every((value) => value);
    final anyOn = values.any((value) => value);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      tristate: true,
      value: allOn || !anyOn ? allOn : null,
      onChanged: (_) => onChanged(!allOn),
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
