import 'package:isar/isar.dart';
part 'reference_migration.g.dart';

/// Durable, private migration journal. Snapshot retained after completion.
@collection
class ReferenceMigration {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String key;
  late String snapshot;
  String checkpoints = '{}';
  bool committed = false;
  bool cleanupPending = true;
}
