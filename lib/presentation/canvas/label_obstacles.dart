import 'dart:ui';

import '../../domain/construction/construction.dart';
import 'canvas_viewport.dart';
import 'label_declutter.dart';
import 'label_layout.dart';
import 'screen_figure.dart';

/// Everything the declutter solver needs to see, in screen space.
typedef DeclutterScene = ({
  List<LabelBox> labels,
  List<RectObstacle> rects,
  List<Capsule> capsules,
});

/// Converts the construction's visible ink and labels into the solver's
/// screen-space scene from each object's [screenInkOf] — the painter's
/// per-kind geometry: curves become chord runs, strokes
/// become capsules at `strokeWidth / 2 + 1` px half-width, point dots
/// become rects. Fills are deliberately not obstacles — a label on a
/// translucent interior stays legible. Hidden and undefined objects
/// contribute nothing, like they paint nothing. Label rects come from
/// [labelScreenRect] — the same measurement the painter and the drag
/// hit test use — so the solver can never disagree with the screen.
DeclutterScene buildDeclutterScene(
  Construction construction,
  CanvasViewport viewport,
  Size canvasSize,
) {
  final labels = <LabelBox>[];
  final rects = <RectObstacle>[];
  final capsules = <Capsule>[];

  for (final object in construction.objects) {
    if (!object.attributes.visible || !object.isDefined || object.isInternal) {
      continue;
    }
    final halfWidth = object.attributes.strokeWidth / 2 + 1;
    final ink = screenInkOf(construction.objects, viewport, canvasSize, object);
    final dot = ink.dot;
    if (dot != null) {
      rects.add(
        RectObstacle(
          Rect.fromCircle(center: dot, radius: object.attributes.pointSize + 1),
          ownerId: object.id,
        ),
      );
    }
    for (final (a, b) in ink.segments) {
      capsules.add(Capsule(a, b, halfWidth, ownerId: object.id));
    }

    final rect = labelScreenRect(object, viewport);
    if (rect != null) {
      final offset = Offset(
        object.attributes.labelDx,
        object.attributes.labelDy,
      );
      labels.add(
        LabelBox(
          id: object.id,
          // Recover the offset origin from the rect the label actually
          // occupies — for angles that's the bisector base, not the
          // anchor (labelBaseTopLeft needs the text size, which only
          // the rect knows here).
          anchor: rect.topLeft - offset,
          size: rect.size,
          offset: offset,
        ),
      );
    }
  }

  return (labels: labels, rects: rects, capsules: capsules);
}
