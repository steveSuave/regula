import 'package:fgex/application/object_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newObjectId returns non-empty, unique ids', () {
    final ids = {for (var i = 0; i < 1000; i++) newObjectId()};
    expect(ids.length, 1000);
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });
}
