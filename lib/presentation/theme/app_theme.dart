import 'package:flutter/material.dart';

/// Light and dark themes with a palette tuned for canvas contrast.
///
/// The canvas has no background of its own — it paints over the scaffold —
/// so `scaffoldBackgroundColor` *is* the drawing surface. Objects without
/// an explicit color draw in [ColorScheme.primary], selection halos and
/// the rubber band in [ColorScheme.tertiary]; both are pinned to explicit
/// values (rather than whatever `fromSeed` derives) so geometry keeps a
/// guaranteed contrast against the canvas in both themes — see the
/// contrast-ratio test in `test/presentation/theme/`.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1565C0);

  /// Default object color on the light canvas: a deep blue.
  static const Color _lightPrimary = Color(0xFF1565C0);

  /// Selection color on the light canvas: a deep pink, clearly distinct
  /// from any of the inspector's swatch colors at a glance.
  static const Color _lightTertiary = Color(0xFFC2185B);

  static const Color _lightCanvas = Colors.white;

  /// Dark-canvas counterparts: light enough to read on near-black.
  static const Color _darkPrimary = Color(0xFF90CAF9);
  static const Color _darkTertiary = Color(0xFFF48FB1);

  /// Slightly blue near-black — softer than pure black under halos and
  /// hairlines, still far from every object color.
  static const Color _darkCanvas = Color(0xFF14181D);

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed).copyWith(
          primary: _lightPrimary,
          tertiary: _lightTertiary,
        ),
        scaffoldBackgroundColor: _lightCanvas,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkPrimary,
          tertiary: _darkTertiary,
        ),
        scaffoldBackgroundColor: _darkCanvas,
      );
}
