import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/features/library/data/services/reference_migration_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'device: verified copy survives database reopen and preserves original',
    (tester) async {
      final root = await (await getTemporaryDirectory()).createTemp(
        'reference_migration_test_',
      );
      final owned = await Directory('${root.path}/owned').create();
      final source = File('${root.path}/original.txt');
      await source.writeAsString('device migration original');
      Future<Isar> open() => Isar.open(
        [
          MediaItemSchema,
          MediaCollectionSchema,
          TagSchema,
          TagFacetSchema,
          StorageRefSchema,
          ViewingHistorySchema,
          ReferenceMigrationSchema,
        ],
        directory: root.path,
        name: 'reference-migration-device',
      );
      var db = await open();
      try {
        final item = MediaItem()
          ..uid = 'device-legacy'
          ..path = source.uri.toString()
          ..originalPath = 'original.txt'
          ..sourceType = MediaSourceType.externalReference
          ..isFavorite = true;
        await db.writeTxn(() async {
          await db.mediaItems.put(item);
        });
        ReferenceMigrationService service({bool stop = false}) =>
            ReferenceMigrationService(
              db,
              owned,
              withSource: (locator, name, read) =>
                  read(File(Uri.parse(locator).toFilePath())),
              releaseAccess: (_) async {},
              checkpoint: (stage) async {
                if (stop && stage == 'materialized') {
                  throw StateError('simulated exit');
                }
              },
            );
        var migration = service(stop: true);
        await expectLater(
          migration.migrate((await migration.inventory()).single),
          throwsStateError,
        );
        final id = item.id;
        await db.close();
        db = await open();
        migration = service();
        await migration.migrate((await migration.inventory()).single);
        final copied = (await db.mediaItems.get(id))!;
        expect(copied.uid, 'device-legacy');
        expect(copied.isFavorite, isTrue);
        expect(copied.sourceType, MediaSourceType.localCopy);
        expect(
          await File('${owned.path}/${copied.path}').readAsString(),
          'device migration original',
        );
        expect(await source.readAsString(), 'device migration original');
        expect(await db.mediaItems.count(), 1);
      } finally {
        await db.close(deleteFromDisk: true);
        await root.delete(recursive: true);
      }
    },
  );
}
