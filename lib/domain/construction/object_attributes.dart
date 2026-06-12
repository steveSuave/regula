import 'package:freezed_annotation/freezed_annotation.dart';

part 'object_attributes.freezed.dart';
part 'object_attributes.g.dart';

/// Display attributes shared by every [GeoObject].
///
/// Immutable; edits go through `copyWith` so a `ChangeAttributesCommand`
/// can hold the before/after values for undo.
///
/// [colorArgb] is a raw ARGB int (e.g. `0xFF2196F3`) rather than a Flutter
/// `Color` — the domain layer is pure Dart. `null` means "use the theme's
/// default color for this object kind", which keeps saved files portable
/// across light/dark themes unless the user explicitly recolors an object.
@freezed
abstract class ObjectAttributes with _$ObjectAttributes {
  const factory ObjectAttributes({
    /// User-facing label, e.g. "A" or "circumcircle". Empty = unnamed.
    @Default('') String name,

    /// Explicit ARGB color, or null to inherit the theme default.
    int? colorArgb,
    @Default(true) bool visible,
    @Default(true) bool labelVisible,

    /// Stroke width in logical pixels (lines, circles, arcs).
    @Default(2.0) double strokeWidth,

    /// Point radius in logical pixels (point kinds only).
    @Default(4.0) double pointSize,

    /// Fill opacity in [0, 1] for filled kinds (sectors); null = unfilled.
    double? fillAlpha,
  }) = _ObjectAttributes;

  factory ObjectAttributes.fromJson(Map<String, dynamic> json) =>
      _$ObjectAttributesFromJson(json);
}
