import 'package:flutter/rendering.dart';

import '../../domain/construction/geo_object.dart';
import 'canvas_viewport.dart';
import 'label_anchor.dart';

/// Label font size in logical pixels; like stroke widths, it does not
/// scale with zoom. Shared with [GeometryPainter] so the hit rect below
/// and the painted text can't drift apart.
const double labelFontSize = 12;

/// The screen rectangle [object]'s label occupies: the text laid out at
/// `worldToScreen(labelAnchor) + (labelDx, labelDy)`. Null when the
/// object paints no label (hidden, undefined, unnamed, or label-hidden)
/// — the label drag in `GeometryCanvas` hit-tests against this, so an
/// invisible label must never be grabbable.
Rect? labelScreenRect(GeoObject object, CanvasViewport viewport) {
  final attributes = object.attributes;
  if (!attributes.visible ||
      !attributes.labelVisible ||
      attributes.name.isEmpty ||
      !object.isDefined) {
    return null;
  }
  final textPainter = TextPainter(
    text: TextSpan(
      text: attributes.name,
      style: const TextStyle(fontSize: labelFontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final size = textPainter.size;
  textPainter.dispose();
  final topLeft = viewport.worldToScreen(labelAnchor(object)) +
      Offset(attributes.labelDx, attributes.labelDy);
  return topLeft & size;
}
