import 'package:isar/isar.dart';

part 'tag.g.dart';

@collection
class Tag {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String key = '';

  @Index()
  String name = '';

  @Index()
  int? facetId;

  @Index()
  int? parentId;

  @Index()
  int level = 100;

  List<int> ancestorIds = [];

  int? colorValue;

  int usageCount = 0;

  @Index()
  bool isHidden = false;

  DateTime createdAt = DateTime(2000);

  static String buildKey(int facetId, String name) {
    return '$facetId::$name';
  }
}
