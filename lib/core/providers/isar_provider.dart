import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';

part 'isar_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  final dir = await getPrivateStorageDirectory();

  final existing = Isar.getInstance();
  if (existing != null) {
    return existing;
  }

  final instance = await Isar.open(
    [
      MediaItemSchema,
      TagSchema,
      TagFacetSchema,
      MediaCollectionSchema,
      StorageRefSchema,
      ViewingHistorySchema,
      ReferenceMigrationSchema,
    ],
    directory: dir.path,
    inspector: kDebugMode, // デバッグ時のみ有効
  );

  try {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await CollectionItemLinkService(instance).migrateOnce(prefs);
    return instance;
  } catch (_) {
    await instance.close();
    rethrow;
  }
}
