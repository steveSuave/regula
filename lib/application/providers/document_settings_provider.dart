import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_settings_provider.g.dart';

/// Per-document display settings: whether the coordinate axes and the
/// background grid are drawn.
///
/// Like the viewport, this is document state outside the undo history —
/// toggling the grid is not an edit to the construction — but it *is*
/// persisted per document (two additive top-level keys in the save format)
/// and File > New resets it to defaults.
class DocumentSettings {
  const DocumentSettings({this.showAxes = false, this.showGrid = false});

  final bool showAxes;
  final bool showGrid;

  @override
  bool operator ==(Object other) =>
      other is DocumentSettings &&
      other.showAxes == showAxes &&
      other.showGrid == showGrid;

  @override
  int get hashCode => Object.hash(showAxes, showGrid);

  @override
  String toString() =>
      'DocumentSettings(showAxes: $showAxes, showGrid: $showGrid)';
}

/// Axes/grid toggles for the current document. Not undoable; replaced
/// wholesale by File > New (defaults) and File > Open (the file's snapshot).
@Riverpod(keepAlive: true, name: 'documentSettingsProvider')
class DocumentSettingsNotifier extends _$DocumentSettingsNotifier {
  @override
  DocumentSettings build() => const DocumentSettings();

  void toggleAxes() => state = DocumentSettings(
    showAxes: !state.showAxes,
    showGrid: state.showGrid,
  );

  void toggleGrid() => state = DocumentSettings(
    showAxes: state.showAxes,
    showGrid: !state.showGrid,
  );

  void set(DocumentSettings settings) => state = settings;

  /// Back to defaults (axes and grid off).
  void reset() => state = const DocumentSettings();
}
