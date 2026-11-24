@TestOn('browser')
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/plane_frame.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/sheet_canvas.dart';

/// Phase 126d: the handful of things whose answer differs between the VM
/// harness and the renderer the app actually ships on.
///
/// This file exists because a bug got all the way to a user through a
/// green suite. The hyperbolic absolute's wash is the canvas minus the
/// disc, and it was built with
/// `Path.combine(PathOperation.difference, rect, oval)` — which on the
/// **web** renderer returns the outer rect *unbroken* whenever the oval
/// lies entirely inside it, and the correct annulus as soon as any part
/// of the oval crosses an edge. So a hyperbolic document showed a
/// uniformly washed canvas with the rim floating on it, and repaired
/// itself the moment the user zoomed far enough to push the boundary off
/// screen. Every VM test was green, because `dart:ui`'s path ops on the
/// VM and CanvasKit's are different implementations.
///
/// Run with `flutter test --platform chrome`. Web is the primary target
/// (DECISIONS §compile target), so anything whose correctness depends on the
/// rasterizer rather than on our own arithmetic belongs here.
void main() {
  const size = Size(400, 300);

  group('a filled region with a hole in it', () {
    test('even-odd cuts the hole wherever the disc sits', () {
      // The property the app needs, stated on the real renderer. The
      // fully-contained case is the one that used to fail.
      for (final (name, centre, radius) in [
        ('fully contained', const Offset(200, 150), 80.0),
        ('touching an edge', const Offset(200, 150), 150.0),
        ('overhanging', const Offset(200, 150), 170.0),
        ('larger than the canvas', const Offset(200, 150), 600.0),
      ]) {
        final path = outsideDiscPath(size, centre, radius);
        expect(path.contains(centre), isFalse, reason: '$name: centre');
        for (var i = 0; i < 8; i++) {
          final t = i * math.pi / 4;
          final unit = Offset(math.cos(t), math.sin(t));
          final inside = centre + unit * (radius * 0.9);
          final outside = centre + unit * (radius * 1.1);
          if ((Offset.zero & size).contains(inside)) {
            expect(path.contains(inside), isFalse, reason: '$name in @$i');
          }
          if ((Offset.zero & size).contains(outside)) {
            expect(path.contains(outside), isTrue, reason: '$name out @$i');
          }
        }
      }
    });

    test('the boolean difference is why this file exists', () {
      // Kept as evidence rather than as a requirement: it documents the
      // platform behaviour that cost a release, and it fails loudly if a
      // future engine fixes it (at which point this test can go, and the
      // even-odd path stays anyway — it needs no boolean op at all).
      final byDifference = Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addOval(
          Rect.fromCircle(center: const Offset(200, 150), radius: 80),
        ),
      );
      expect(
        byDifference.contains(const Offset(200, 150)),
        isTrue,
        reason:
            'web path-ops difference leaves no hole for a contained '
            'shape; if this now fails the engine has been fixed',
      );
    });
  });

  // Intent 004, milestone 1. The space view draws a circle by handing
  // the renderer an oval path through an affine `Path.transform`, and
  // dashes it by walking that transformed path's metrics. Both steps are
  // the renderer's arithmetic, not ours, so they are checked here on the
  // renderer the app ships on, by the pixels it produces.
  group('a circle on a tilted sheet', () {
    const tilt = 1.0;
    const viewport = CanvasViewport(ViewportState(tilt: tilt));
    final squash = math.cos(tilt);
    const centre = Offset(200, 200);
    const radius = 100.0;
    const ink = Color(0xFFFF0000);

    Future<bool Function(Offset)> inked(
      void Function(SheetCanvas sheet, Paint paint) draw,
    ) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      draw(
        SheetCanvas(canvas, viewport),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..isAntiAlias = false,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.round(),
        size.height.round(),
      );
      final data = (await image.toByteData())!;
      picture.dispose();
      image.dispose();
      return (Offset at) {
        final offset = (at.dy.round() * size.width.round() + at.dx.round()) * 4;
        return data.getUint8(offset) > 200 && data.getUint8(offset + 3) > 200;
      };
    }

    /// Where the rim point at flat angle [t] lands on screen.
    Offset rim(double t) => viewport.sheetToScreen(
      centre + Offset(math.cos(t), math.sin(t)) * radius,
    );

    test('its rim is the ellipse the sheet map says, at full stroke '
        'width', () async {
      final isInk = await inked(
        (sheet, paint) => sheet.drawCircle(centre, radius, paint),
      );
      for (var i = 0; i < 16; i++) {
        expect(isInk(rim(i * math.pi / 8)), isTrue, reason: 'rim @$i');
      }
      final mapped = viewport.sheetToScreen(centre);
      expect(isInk(mapped), isFalse, reason: 'the centre is not stroked');
      // Where an unsquashed circle's top and bottom would have been.
      expect(isInk(mapped - const Offset(0, radius)), isFalse);
      expect(isInk(mapped + const Offset(0, radius - 20)), isFalse);
      // The stroke is 4 px wide across the squashed top as well: a
      // transformed *canvas* would have thinned it to 4·cos(tilt) ≈ 2.
      final top = rim(-math.pi / 2);
      expect(top.dy, closeTo(200 * squash - 100 * squash, 1e-9));
      expect(isInk(top + const Offset(0, 1.4)), isTrue);
      expect(isInk(top - const Offset(0, 1.4)), isTrue);
      expect(isInk(top + const Offset(0, 4)), isFalse);
    });

    test('dashed, about half of that ellipse is inked, in runs', () async {
      final isInk = await inked(
        (sheet, paint) => sheet.drawPath(
          Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
          paint,
          dashPeriod: 40,
        ),
      );
      const samples = 720;
      var inkedSamples = 0;
      var runs = 0;
      var previous = isInk(rim(-2 * math.pi / samples));
      for (var i = 0; i < samples; i++) {
        final now = isInk(rim(i * 2 * math.pi / samples));
        if (now) inkedSamples += 1;
        if (now && !previous) runs += 1;
        previous = now;
      }
      expect(inkedSamples / samples, inInclusiveRange(0.35, 0.65));
      // The squashed rim is about 480 px round: a dozen 40-px periods.
      expect(runs, inInclusiveRange(9, 15));
    });
  });

  // Intent 004, milestone 2: a plane of the construction is drawn through
  // a general affine sheet map — shear and rotation, not only the squash
  // above. `Path.transform` of an oval under such a matrix is, again, the
  // renderer's arithmetic.
  group('a circle on a plane seen obliquely', () {
    // A face leaning toward the viewer: strongly foreshortened, and
    // turned by the azimuth, so the sheet map shears.
    final frame = PlaneFrame.throughPoints(
      const Vec3(60, -220, 0),
      const Vec3(240, -220, 0),
      const Vec3(150, -320, 120),
    )!;
    final view = PlaneViewport(
      const CanvasViewport(
        ViewportState(pan: Vec2(-20, 90), tilt: 1.0, rotation: 0.3),
      ),
      frame,
    );
    // In the plane's own frame at unit scale: the centre and a radius.
    const centre = Offset(110, -50);
    const radius = 60.0;
    const ink = Color(0xFFFF0000);

    Offset rim(double t) =>
        view.sheetToScreen(centre + Offset(math.cos(t), math.sin(t)) * radius);

    test('its rim is the ellipse the sheet map says, at full stroke '
        'width', () async {
      final recorder = PictureRecorder();
      SheetCanvas(Canvas(recorder), view).drawCircle(
        centre,
        radius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..isAntiAlias = false,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.round(),
        size.height.round(),
      );
      final data = (await image.toByteData())!;
      picture.dispose();
      image.dispose();
      bool isInk(Offset at) {
        final x = at.dx.round();
        final y = at.dy.round();
        if (x < 0 || y < 0 || x >= size.width || y >= size.height) {
          return false;
        }
        final offset = (y * size.width.round() + x) * 4;
        return data.getUint8(offset) > 200 && data.getUint8(offset + 3) > 200;
      }

      // The picture is on the canvas, and it is not a circle.
      final images = [for (var i = 0; i < 16; i++) rim(i * math.pi / 8)];
      for (final at in images) {
        expect(
          (Offset.zero & size).deflate(4).contains(at),
          isTrue,
          reason: 'on the canvas: $at',
        );
      }
      final mapped = view.sheetToScreen(centre);
      final reaches = [for (final at in images) (at - mapped).distance];
      expect(
        reaches.reduce(math.max) / reaches.reduce(math.min),
        greaterThan(1.3),
        reason: 'a sheared ellipse, or this tests nothing',
      );

      for (var i = 0; i < images.length; i++) {
        expect(isInk(images[i]), isTrue, reason: 'rim @$i');
        // Full stroke width across the rim, wherever it is: measured
        // along the ellipse's own normal there, 4.5 px either side of the
        // centre line is clear. A transformed *canvas* would have fattened
        // the stroke where the map stretches and thinned it where it
        // squeezes.
        final t = i * math.pi / 8;
        final along = rim(t + 1e-3) - rim(t - 1e-3);
        final normal = Offset(-along.dy, along.dx) / along.distance;
        expect(isInk(images[i] + normal * 4.5), isFalse, reason: 'out @$i');
        expect(isInk(images[i] - normal * 4.5), isFalse, reason: 'in @$i');
      }
      expect(isInk(mapped), isFalse, reason: 'the centre is not stroked');
    });
  });
}
