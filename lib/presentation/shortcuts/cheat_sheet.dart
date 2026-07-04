import 'package:flutter/material.dart';

import 'shortcut_table.dart';

/// Translucent in-tree overlay listing every visible binding from
/// [shortcutTable], grouped by section.
///
/// Deliberately *not* a dialog route: a route's focus scope would cut
/// the `AppShortcuts` layer off from key events, so `?` could not
/// toggle the sheet closed and no shortcut could fire from it. As a
/// plain overlay, keys keep flowing — the editor closes the sheet on
/// Esc/`?` and executes any other shortcut pressed while it is up.
class ShortcutCheatSheet extends StatelessWidget {
  const ShortcutCheatSheet({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.4),
          onDismiss: onDismiss,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 560),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Keyboard shortcuts',
                          style: theme.textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          'Esc or ? closes',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 40,
                          runSpacing: 20,
                          children: [
                            for (final section in ShortcutSection.values)
                              _SectionColumn(section: section),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({required this.section});

  final ShortcutSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bindings = [
      for (final binding in shortcutTable)
        if (binding.section == section && binding.showInCheatSheet) binding,
    ];
    return SizedBox(
      width: 330,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final binding in bindings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      binding.display,
                      style: theme.textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      binding.label,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
