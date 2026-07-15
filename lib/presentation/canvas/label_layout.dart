import 'package:flutter/rendering.dart';

import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/segment.dart';
import 'canvas_viewport.dart';
import 'label_anchor.dart';
import 'measure_format.dart';

/// The text [object]'s label paints, or null when it paints no label.
///
/// Two independent parts (Phase 35): the *name* part exists while
/// `labelVisible` and the object is named; the *value* part while
/// `showValue` and the object has a measurable value (a segment's
/// length, an angle's degrees). Both → `A = 3.00`; one → just it;
/// neither → null. Visibility and definedness are deliberately *not*
/// consulted — callers already gate on them, and the painter's
/// show-hidden mode paints labels this helper must still compose.
String? labelText(GeoObject object) {
  final attributes = object.attributes;
  final value = switch (object) {
    Segment(:final start?, :final end?) when attributes.showValue =>
      formatLength(start.distanceTo(end)),
    GeoAngle(:final angle?) when attributes.showValue =>
      formatAngle(angle.measure),
    _ => null,
  };
  final name = attributes.labelVisible && attributes.name.isNotEmpty
      ? attributes.name
      : null;
  if (name == null || value == null) {
    return value ?? name;
  }
  return '$name = $value';
}

/// The screen rectangle [object]'s label occupies: the text laid out at
/// `worldToScreen(labelAnchor) + (labelDx, labelDy)`. Null when the
/// object paints no label (hidden, undefined, or no [labelText] parts)
/// — the label drag in `GeometryCanvas` hit-tests against this, so an
/// invisible label must never be grabbable.
Rect? labelScreenRect(GeoObject object, CanvasViewport viewport) {
  final attributes = object.attributes;
  if (!attributes.visible || !object.isDefined) {
    return null;
  }
  final text = labelText(object);
  if (text == null) {
    return null;
  }
  // Font size comes off the object (Phase 28); the painter's _drawLabel
  // reads the same attribute so the hit rect and the painted text can't
  // drift apart.
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
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
