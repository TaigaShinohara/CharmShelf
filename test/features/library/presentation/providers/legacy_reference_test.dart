import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/legacy_migration_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'external reference guard uses actual document rather than broad tree grant',
    () {
      const base =
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments';
      expect(isLegacyFolderReference(base), isTrue);
      expect(
        isLegacyFolderReference(
          '$base/document/primary%3ADocuments%2FCharmShelf%2Flibrary',
        ),
        isTrue,
      );
      expect(
        isLegacyFolderReference('$base/document/primary%3ADocuments%2FOther'),
        isFalse,
      );
      expect(
        isLegacyFolderReference(
          '$base/document/primary%3ADocuments%2FCharmShelf-copy',
        ),
        isFalse,
      );
      expect(
        isLegacyFolderReference(
          '/storage/emulated/0/Documents/CharmShelf/library',
        ),
        isTrue,
      );
      expect(
        isLegacyFolderReference('content://other/tree/primary%3ADocuments'),
        isFalse,
      );
    },
  );
  for (final linked in [true, false]) {
    test(
      'source reference guard protects pre-StorageRef items: linked=$linked',
      () async {
        SharedPreferences.setMockInitialValues({});
        final root = await Directory.systemTemp.createTemp('legacy_reference_');
        final isar = await Isar.open(
          [
            MediaCollectionSchema,
            MediaItemSchema,
            TagSchema,
            TagFacetSchema,
            StorageRefSchema,
          ],
          directory: root.path,
          name: 'reference_${DateTime.now().microsecondsSinceEpoch}',
        );
        final item = MediaItem()
          ..sourceType = MediaSourceType.externalReference
          ..path =
              'content://com.android.externalstorage.documents/tree/primary%3ADocuments/document/primary%3ADocuments%2F${linked ? 'CharmShelf' : 'Other'}%2Fphoto.jpg';
        await isar.writeTxn(() => isar.mediaItems.put(item));
        const channel = MethodChannel('com.tsmusic.privateshelf/legacy');
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              return [
                {
                  'path': 'library/photo.jpg',
                  'directory': false,
                  'size': 1,
                  'hash': 'a' * 64,
                },
              ];
            });
        final container = ProviderContainer(
          overrides: [
            isarProvider.overrideWith((ref) async => isar),
            localStorageManagerProvider.overrideWithValue(
              LocalStorageManager(isAndroid: false, privateRootDirectory: root),
            ),
          ],
        );
        try {
          final service = await container.read(
            legacyMigrationServiceProvider.future,
          );
          final action = service.inspect(
            Uri.parse(
              'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
            ),
          );
          if (linked) {
            await expectLater(
              action,
              throwsA(
                isA<LegacyMigrationException>().having(
                  (e) => e.issue,
                  'issue',
                  LegacyIssue.linkedFolder,
                ),
              ),
            );
            expect(await service.load(), isNull);
          } else {
            expect((await action).phase, LegacyPhase.choice);
          }
          expect(calls, ['scan']);
        } finally {
          container.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          await isar.close(deleteFromDisk: true);
          await root.delete(recursive: true);
        }
      },
    );
  }
}
