import 'package:isar/isar.dart';

part 'tag_facet.g.dart';

@collection
class TagFacet {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  int? colorValue;

  int sortOrder = 0;

  late DateTime createdAt;
}
