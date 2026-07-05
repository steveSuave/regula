import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../domain/commands/change_attributes_command.dart';
import '../../domain/construction/geo_object.dart';
import 'object_kind_label.dart';

/// Side panel listing every object in the construction, grouped by
/// sealed kind (points, lines, circles, angles) in insertion order.
///
/// The tree is the selection surface of last resort: rows select on tap
/// and toggle on shift-tap — the canvas gestures exactly — which makes
/// it the only way to reach objects the canvas can't hit, i.e. hidden
/// ones. Each row also carries an eye toggle flipping `visible` as one
/// [ChangeAttributesCommand], so un-hiding is one tap rather than
/// select-then-inspector.
///
/// Collapsing lives with the parent: the editor's app bar shows and
/// hides the whole panel, so an empty construction here still renders
/// (with a hint) rather than collapsing to nothing like the inspector.
class ObjectTreePanel extends ConsumerWidget {
  const ObjectTreePanel({super.key});

  static const double panelWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so undo/redo, deletes and attribute edits refresh the rows.
    final construction = ref.watch(constructionProvider).construction;
    final selectedIds = ref.watch(selectionProvider);
    final theme = Theme.of(context);

    // Group headers appear in fixed kind order; rows within a group keep
    // insertion order, like every other listing of objects.
    final groups = <String, List<GeoObject>>{
      'Points': [],
      'Lines': [],
      'Circles': [],
      'Angles': [],
    };
    for (final object in construction.objects) {
      groups[switch (object) {
        GeoPoint() => 'Points',
        GeoLine() => 'Lines',
        GeoCircle() => 'Circles',
        GeoAngle() => 'Angles',
      }]!
          .add(object);
    }

    return SizedBox(
      width: panelWidth,
      child: Row(
        children: [
          Expanded(
            child: construction.objects.isEmpty
                ? Center(
                    child: Text(
                      'No objects yet',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final MapEntry(key: label, value: objects)
                          in groups.entries)
                        if (objects.isNotEmpty) ...[
                          _GroupHeader(
                            label: label,
                            ids: [for (final object in objects) object.id],
                          ),
                          for (final object in objects)
                            _ObjectRow(
                              object: object,
                              selected: selectedIds.contains(object.id),
                            ),
                        ],
                    ],
                  ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
        ],
      ),
    );
  }
}

/// A kind's group header doubling as select-by-kind: tap replaces the
/// selection with every object of the kind — hidden ones included, this
/// being the panel whose point is reaching them — shift-tap unions
/// (band semantics), and long-press unions too, the touch stand-in for
/// shift. Union rather than the canvas long-press's toggle: headers
/// select groups, the canvas toggles individuals.
class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.label, required this.ids});

  final String label;
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    void select({required bool additive}) => ref
        .read(selectionProvider.notifier)
        .selectMany(ids, additive: additive);
    return Tooltip(
      message: 'Select all ${label.toLowerCase()}',
      child: InkWell(
        onTap: () =>
            select(additive: HardwareKeyboard.instance.isShiftPressed),
        onLongPress: () {
          HapticFeedback.selectionClick();
          select(additive: true);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            label,
            style: theme.textTheme.labelLarge!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// One object's row: tap selects, shift-tap toggles (canvas semantics),
/// and the trailing eye flips visibility as one undoable command.
class _ObjectRow extends ConsumerWidget {
  const _ObjectRow({required this.object, required this.selected});

  final GeoObject object;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attributes = object.attributes;
    final named = attributes.name.isNotEmpty;
    return ListTile(
      dense: true,
      selected: selected,
      title: Text(named ? attributes.name : objectKindLabel(object)),
      subtitle: named ? Text(objectKindLabel(object)) : null,
      onTap: () {
        final notifier = ref.read(selectionProvider.notifier);
        if (HardwareKeyboard.instance.isShiftPressed) {
          notifier.toggle(object.id);
        } else {
          notifier.select(object.id);
        }
      },
      trailing: IconButton(
        tooltip: attributes.visible ? 'Hide' : 'Show',
        icon: Icon(
          attributes.visible ? Icons.visibility : Icons.visibility_off,
          size: 18,
        ),
        onPressed: () => ref.read(commandStackProvider.notifier).execute(
              ChangeAttributesCommand({
                object.id:
                    attributes.copyWith(visible: !attributes.visible),
              }),
            ),
      ),
    );
  }
}
