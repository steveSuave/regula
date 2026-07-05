import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/object_ids.dart';

void main() {
  test('newObjectId returns non-empty, unique ids', () {
    final ids = {for (var i = 0; i < 1000; i++) newObjectId()};
    expect(ids.length, 1000);
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });
}
