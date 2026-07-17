// Temporary: render a document's locus samples to SVG for eyeballing.
// Run: dart run tool/locus_render.dart <doc.json> <out.svg>
import 'dart:convert';
import 'dart:io';

import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/locus.dart';
import 'package:regula/domain/math/vec2.dart';

void main(List<String> args) {
  final json =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final construction = decodeDocument(json).construction;
  final locus = construction.objects.whereType<Locus>().single;
  final samples = locus.samples!;
  // Frame on the core (focus-window) samples: a projective line-host
  // sweep carries diverging arms astronomically far out, and a frame
  // fit to those shrinks the figure to a dot.
  final points = locus.coreSamples!;
  var minX = points.first.x, maxX = points.first.x;
  var minY = points.first.y, maxY = points.first.y;
  for (final p in points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  final pad = 0.1 * ((maxX - minX) + (maxY - minY)) / 2 + 10;
  final sb = StringBuffer()
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" width="800" '
        'height="800" viewBox="${minX - pad} ${-maxY - pad} '
        '${maxX - minX + 2 * pad} ${maxY - minY + 2 * pad}">')
    ..writeln('<rect x="${minX - pad}" y="${-maxY - pad}" width="100%" '
        'height="100%" fill="white"/>');
  final width = (maxX - minX + 2 * pad) / 400;
  var path = StringBuffer();
  void flush() {
    if (path.isNotEmpty) {
      sb.writeln('<path d="$path" fill="none" stroke="#1a56c4" '
          'stroke-width="$width"/>');
      path = StringBuffer();
    }
  }

  for (final s in samples) {
    if (s == null) {
      flush();
    } else {
      path.write('${path.isEmpty ? 'M' : 'L'}${s.x},${-s.y} ');
    }
  }
  flush();
  for (final p in construction.objects.whereType<FreePoint>()) {
    sb.writeln('<circle cx="${p.position.x}" cy="${-p.position.y}" '
        'r="${2 * width}" fill="#c41a1a"/>');
  }
  sb.writeln('</svg>');
  File(args[1]).writeAsStringSync(sb.toString());
  stdout.writeln('components: '
      '${samples.fold<int>(1, (n, s) => s == null ? n + 1 : n)}, '
      'samples: ${samples.whereType<Vec2>().length}, '
      'core: ${points.length}');
}
