import 'package:isar/isar.dart';

part 'storage_ref.g.dart';

@collection
class StorageRef {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? uid;

  @Index(type: IndexType.value)
  late String ownerUid;

  @enumerated
  late StorageOwnerType ownerType;

  @enumerated
  late StorageSourceType sourceType;

  @Index(type: IndexType.value)
  late String locator;

  String? normalizedLocator;

  bool isPrimary = true;

  String? parentUid;

  late DateTime createdAt;

  late DateTime updatedAt;
}

enum StorageOwnerType { collection, item }

enum StorageSourceType { local, external }
