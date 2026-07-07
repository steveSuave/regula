import 'package:flutter/rendering.dart';

import '../../domain/construction/geo_object.dart';
import 'canvas_viewport.dart';
import 'label_anchor.dart';

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
  // Font size comes off the object (Phase 28); the painter's _drawLabel
  // reads the same attribute so the hit rect and the painted text can't
  // drift apart.
  final textPainter = TextPainter(
    text: TextSpan(
      text: attributes.name,
      style: TextStyle(fontSize: attributes.labelFontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final size = textPainter.size;
  textPainter.dispose();
  final topLeft = viewport.worldToScreen(labelAnchor(object)) +
      Offset(attributes.labelDx, attributes.labelDy);
  return topLeft & size;
}
