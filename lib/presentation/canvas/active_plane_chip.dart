import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/providers/active_plane_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/space_view_provider.dart';
import '../../application/providers/tool_provider.dart';
import '../../domain/tools/plane_scope.dart';

/// Says which plane the tools are working in, and returns to the base
/// plane on a tap (intent 004, milestone 2).
///
/// A tap with a tool lands in the active plane, so the active plane is
/// the one piece of state a user must never have to guess. It is said
/// twice: the plane's patch is outlined in the selection colour, and
/// this chip names it. The chip is shown only while the active plane is
/// not the base plane, which is where every document starts and needs no
/// announcement. It is a 48 px target, and on a phone it is the way
/// back.
class ActivePlaneChip extends ConsumerWidget {
  const ActivePlaneChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(spaceViewProvider)) {
      return const SizedBox.shrink();
    }
    final plane = activePlaneOf(
      ref.watch(activePlaneProvider),
      ref.watch(constructionProvider).construction.objects,
    );
    if (plane == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final name = plane.attributes.name;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Tooltip(
          message: 'Back to the base plane',
          child: Material(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ref.read(activePlaneProvider.notifier).set(null),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 20,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name.isEmpty ? 'In a plane' : 'In plane $name',
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says why a tap was turned away (intent 004, milestone 2): the tapped
/// object does not lie in the active plane by construction, so a tool
/// that builds in that plane cannot take it. Shown until the next tap
/// that goes through, or a change of tool.
///
/// A refusal with no reason reads as a broken tool. This one has a rule
/// behind it that the user can act on: work in a plane that holds the
/// object, or build the plane through it.
class ScopeRefusalHint extends ConsumerWidget {
  const ScopeRefusalHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tool state's revision bumps on every refusal and every input
    // that clears one.
    ref.watch(toolProvider);
    final refusal = ref.read(toolProvider.notifier).lastRefusal;
    if (refusal == null) {
      return const SizedBox.shrink();
    }
    final base =
        !ref.watch(spaceViewProvider) ||
        activePlaneOf(
              ref.watch(activePlaneProvider),
              ref.watch(constructionProvider).construction.objects,
            ) ==
            null;
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
                switch (refusal) {
                  ScopeRefusal.notInPlane =>
                    base
                        ? 'That is not in the base plane, where this tool is '
                              'working'
                        : 'That is not in the active plane by construction',
                },
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
