import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../domain/construction/construction.dart';
import '../../domain/construction/objects/free_point.dart';

/// How many constructions on the lifted free point [id] are undefined:
/// the plane-bound ones (a circle centred on it, a perpendicular through
/// it) that have no meaning while it is off its plane. 0 for a point in
/// its plane, or one that is not a free point.
int constructionsWaitingOn(Construction construction, String id) {
  final point = construction.byId(id);
  if (point is! FreePoint || !point.isLifted) {
    return 0;
  }
  var waiting = 0;
  for (final dependent in construction.transitiveDependentsOf(id)) {
    if (!(construction.byId(dependent)?.isDefined ?? true)) {
      waiting++;
    }
  }
  return waiting;
}

/// Says why constructions vanished when a point was lifted (intent 004,
/// milestone 2): while the one selected point is off its plane and
/// plane-bound constructions on it are undefined, a chip counts them and
/// says what brings them back. Without it a circle that disappears on a
/// lift reads as a bug; with it, it reads as the rule it is.
class LiftedPointHint extends ConsumerWidget {
  const LiftedPointHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    if (selection.length != 1) {
      return const SizedBox.shrink();
    }
    final construction = ref.watch(constructionProvider).construction;
    final waiting = constructionsWaitingOn(construction, selection.single);
    if (waiting == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                waiting == 1
                    ? '1 construction needs this point back in its plane'
                    : '$waiting constructions need this point back in its '
                          'plane',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
