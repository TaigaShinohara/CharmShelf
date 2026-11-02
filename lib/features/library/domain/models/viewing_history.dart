import 'package:isar/isar.dart';

part 'viewing_history.g.dart';

/// Device-local navigation history. Content and file paths remain in MediaItem.
@collection
class ViewingHistory {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String itemUid = '';

  @Index()
  DateTime openedAt = DateTime(2000);
}
