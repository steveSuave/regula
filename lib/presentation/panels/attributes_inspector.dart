import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../domain/commands/change_attributes_command.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/object_attributes.dart';
import 'delete_selection.dart';
import 'object_kind_label.dart';

/// Side panel showing the current selection's attributes; collapses to
/// nothing while the selection is empty.
///
/// A single selected object gets its kind as the header plus editable
/// fields (name, visibility, label visibility, color, width). A
/// multi-selection shows the count, the same controls applied to the
/// whole selection (a dash or no highlight means the values are mixed;
/// a tap sets everything), and a read-only list of what's in it. Width
/// is two controls — stroke width for line-like kinds, point size for
/// points — each shown only when the selection contains that kind and
/// applied only to it.
///
/// Hiding a selected object does not deselect it: hidden objects can't
/// be hit on the canvas, so staying in the inspector is the way back to
/// un-hiding until the object tree panel lands.
///
/// Every edit is one [ChangeAttributesCommand] on the shared stack, so
/// attribute changes undo exactly like geometry changes. The panel also
/// carries the Delete button — deletion acts on the selection, and the
/// panel exists exactly while there is one (see
/// [deleteSelectionWithConfirmation] for the cascade confirmation).
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
    // Width means different things per kind, so the two selectors each
    // target their own slice of the selection.
    final points = [
      for (final object in objects)
        if (object is GeoPoint) object,
    ];
    final strokes = [
      for (final object in objects)
        if (object is! GeoPoint) object,
    ];
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
                const SizedBox(height: 8),
                _ColorRow(
                  values: [
                    for (final object in objects) object.attributes.colorArgb,
                  ],
                  onChanged: (argb) => _setForAll(
                    ref,
                    objects,
                    (attributes) => attributes.copyWith(colorArgb: argb),
                  ),
                ),
                if (strokes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _WidthSelector(
                    key: const ValueKey('stroke-width'),
                    label: 'Stroke width',
                    options: const [1, 2, 4, 6],
                    values: [
                      for (final object in strokes)
                        object.attributes.strokeWidth,
                    ],
                    onChanged: (width) => _setForAll(
                      ref,
                      strokes,
                      (attributes) => attributes.copyWith(strokeWidth: width),
                    ),
                  ),
                ],
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _WidthSelector(
                    key: const ValueKey('point-size'),
                    label: 'Point size',
                    options: const [3, 4, 6, 8],
                    values: [
                      for (final object in points) object.attributes.pointSize,
                    ],
                    onChanged: (size) => _setForAll(
                      ref,
                      points,
                      (attributes) => attributes.copyWith(pointSize: size),
                    ),
                  ),
                ],
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('delete-button'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    single != null
                        ? 'Delete'
                        : 'Delete ${objects.length} objects',
                  ),
                  onPressed: () =>
                      deleteSelectionWithConfirmation(context, ref, objects),
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

/// The colors the inspector offers, as (tooltip, raw ARGB) pairs; null
/// is "Auto" — inherit the theme default, the portable choice that
/// adapts when light/dark themes land in Phase 9.
const _palette = <(String, int?)>[
  ('Auto', null),
  ('Red', 0xFFE53935),
  ('Orange', 0xFFFB8C00),
  ('Green', 0xFF43A047),
  ('Blue', 0xFF1E88E5),
  ('Purple', 0xFF8E24AA),
];

/// The selection's color as a row of tappable swatches.
///
/// A swatch is highlighted only when the whole selection carries exactly
/// its color — a mixed selection highlights nothing. The Auto swatch is
/// drawn in the theme primary (what the canvas paints for `null`) with a
/// reset glyph to tell it apart from the fixed blues and purples.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.values, required this.onChanged});

  final List<int?> values;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uniform = values.toSet().length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (name, argb) in _palette)
              Tooltip(
                message: name,
                child: InkWell(
                  onTap: () => onChanged(argb),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(argb ?? scheme.primary.toARGB32()),
                      border: Border.all(
                        color: uniform && argb == values.first
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                        width: uniform && argb == values.first ? 3 : 1,
                      ),
                    ),
                    child: argb == null
                        ? Icon(
                            Icons.format_color_reset,
                            size: 16,
                            color: scheme.onPrimary,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One width attribute over (a slice of) the selection, as a row of
/// discrete choices — discrete so each tap is exactly one command on the
/// undo stack, where a live slider would emit one per frame.
///
/// Nothing is highlighted when the values are mixed, or uniform but not
/// among [options] (possible once saved files arrive).
class _WidthSelector extends StatelessWidget {
  const _WidthSelector({
    super.key,
    required this.label,
    required this.options,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final List<double> options;
  final List<double> values;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final uniform = values.toSet().length == 1;
    final selected = uniform && options.contains(values.first)
        ? {values.first}
        : const <double>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SegmentedButton<double>(
          segments: [
            for (final option in options)
              ButtonSegment(
                value: option,
                label: Text('${option.round()}'),
              ),
          ],
          selected: selected,
          // Allowing empty lets `selected` model the mixed state; a tap
          // on the already-selected segment then arrives as an empty set,
          // which is a no-op rather than a "no width".
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onChanged(selection.first);
            }
          },
        ),
      ],
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
