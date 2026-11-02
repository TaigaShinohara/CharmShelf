import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:isar/isar.dart';

import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/services/data_restore_service.dart';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';

final legacyMigrationServiceProvider = FutureProvider<LegacyMigrationService>((
  ref,
) async {
  final root = await ref
      .read(localStorageManagerProvider)
      .getPrivateRootDirectory();
  final isar = await ref.read(isarProvider.future);
  final prefs = await ref.read(sharedPreferencesProvider.future);
  final language =
      prefs.getString(AppPreferences.localeKey) ?? Platform.localeName;
  return LegacyMigrationService(
    restoredCatalogTitle: lookupAppLocalizations(
      Locale(language.startsWith('ja') ? 'ja' : 'en'),
    ).legacyRestoredCatalog,
    root: root,
    storage: AndroidLegacyStorage(),
    checkReferences: (tree) async {
      final refs = await isar.storageRefs.where().findAll();
      final items = await isar.mediaItems.where().findAll();
      if (items.any(
        (item) =>
            item.sourceType == MediaSourceType.externalReference &&
            isLegacyFolderReference(item.path),
      )) {
        throw const LegacyMigrationException(LegacyIssue.linkedFolder);
      }
      final collections = await isar.mediaCollections.where().findAll();
      for (final collection in collections.where((c) => c.isExternal)) {
        refs.add(
          StorageRef()
            ..sourceType = StorageSourceType.external
            ..locator = collection.path,
        );
      }
      for (final item in refs.where(
        (r) => r.sourceType == StorageSourceType.external,
      )) {
        if (isLegacyFolderReference(item.locator)) {
          throw const LegacyMigrationException(LegacyIssue.linkedFolder);
        }
      }
    },
    restorePrepared: (prepared) async {
      await for (final entry in prepared.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is Directory) {
          final relative = p.relative(entry.path, from: prepared.path);
          if (relative == 'library' || relative.startsWith('library/')) {
            await Directory(
              p.join(root.path, relative),
            ).create(recursive: true);
          }
        }
      }
      final service = await ref.read(dataRestoreServiceProvider.future);
      final result = await service.restore(
        preparedSource: prepared,
        preserveExistingTags: true,
      );
      if (result.isFailure) throw result.errorOrNull!;
      final document =
          jsonDecode(
                await File(
                  p.join(prepared.path, '.tagshelf/metadata.json'),
                ).readAsString(),
              )
              as Map;
      for (final raw in document['tags'] as List) {
        if (await isar.tags
                .where()
                .keyEqualTo(raw['key'] as String)
                .findFirst() ==
            null) {
          throw StateError('Restored charm is missing');
        }
      }
      for (final raw in document['collections'] as List) {
        final col = await isar.mediaCollections
            .where()
            .pathEqualTo(raw['relativePath'] as String)
            .findFirst();
        if (col == null || col.isCatalog != (raw['isCatalog'] == true)) {
          throw StateError('Restored catalog is missing');
        }
        await col.tags.load();
        final expected = ((raw['tagKeys'] as List?) ?? [])
            .cast<String>()
            .toSet();
        if (!col.tags.map((tag) => tag.key).toSet().containsAll(expected)) {
          throw StateError('Restored charm links are missing');
        }
      }
      for (final raw in document['mediaItems'] as List) {
        final item = await isar.mediaItems
            .where()
            .pathEqualTo(raw['relativePath'] as String)
            .findFirst();
        if (item == null ||
            (raw['isHidden'] != null && item.isHidden != raw['isHidden']) ||
            (raw['isArchived'] != null &&
                item.isArchived != raw['isArchived']) ||
            (raw['isFavorite'] != null &&
                item.isFavorite != raw['isFavorite'])) {
          throw StateError('Restored item state is missing');
        }
      }
    },
    verifyDatabase: (paths) async {
      for (final path in paths) {
        final item = await isar.mediaItems
            .where()
            .pathEqualTo(path)
            .findFirst();
        if (item == null || item.isMissing) {
          throw StateError('Restored file is not registered');
        }
      }
    },
  );
});

/// Read-only status. Opening Settings must not perform cleanup or scan files.
final legacyMigrationRecordProvider = FutureProvider<LegacyMigrationRecord?>((
  ref,
) async {
  return (await ref.watch(legacyMigrationServiceProvider.future)).load();
});

/// Keeps deep links deferred while the settings transfer route is visible.
final legacyScreenOpenProvider = StateProvider<bool>((ref) => false);

/// Recovery-only list: no background sync or new imports while the gate is open.
final legacyLinkedCollectionsProvider = FutureProvider<List<MediaCollection>>((
  ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  final collections = await isar.mediaCollections.where().findAll();
  return collections
      .where((collection) => isLegacyFolderReference(collection.path))
      .toList();
});

final legacyLinkedItemsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  final items = await isar.mediaItems.where().findAll();
  return items
      .where(
        (item) =>
            item.sourceType == MediaSourceType.externalReference &&
            isLegacyFolderReference(item.path),
      )
      .toList();
});

bool isLegacyFolderReference(String locator) {
  if (locator == '/storage/emulated/0/Documents' ||
      locator == '/storage/emulated/0/Documents/CharmShelf' ||
      locator.startsWith('/storage/emulated/0/Documents/CharmShelf/')) {
    return true;
  }
  final uri = Uri.tryParse(locator);
  if (uri?.authority != 'com.android.externalstorage.documents') return false;
  final segments = uri!.pathSegments;
  final index = segments.lastIndexOf('document');
  final treeIndex = segments.indexOf('tree');
  final idIndex = index >= 0
      ? index + 1
      : treeIndex >= 0
      ? treeIndex + 1
      : -1;
  if (idIndex < 0 || idIndex >= segments.length) return false;
  final id = segments[idIndex];
  return id == 'primary:Documents' ||
      id == 'primary:Documents/CharmShelf' ||
      id.startsWith('primary:Documents/CharmShelf/');
}
