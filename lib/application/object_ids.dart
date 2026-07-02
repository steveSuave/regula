import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fresh unique id for a new construction object.
///
/// The domain layer has no id source of its own — tools and commands take
/// ids (or an id generator) from their caller. This is the app's one real
/// generator; pass it as `newId` when constructing tools.
String newObjectId() => _uuid.v4();
