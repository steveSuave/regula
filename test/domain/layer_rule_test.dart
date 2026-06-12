import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the architectural invariant from CLAUDE.md: `lib/domain/` is
/// pure Dart and must never import `package:flutter/*`.
void main() {
  test('lib/domain contains no Flutter imports', () {
    final domainDir = Directory('lib/domain');
    expect(domainDir.existsSync(), isTrue, reason: 'lib/domain must exist');

    final offenders = domainDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:flutter'))
        .map((f) => f.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'domain layer must stay free of Flutter imports (see CLAUDE.md)',
    );
  });
}
