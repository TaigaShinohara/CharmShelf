import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart' hide Collection;

import '../../domain/models/collection.dart';
import '../../domain/models/library_backup.dart';
import '../../domain/models/media_filter.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/storage_ref.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/tag_facet.dart';
import '../../domain/models/viewing_history.dart';
import 'library_backup_archive.dart';

class LibraryBackupDatabase {
  LibraryBackupDatabase(this.isar);
  final Isar isar;

  static String identity(String? uid, String type, String path) =>
      uid?.isNotEmpty == true
      ? uid!
      : 'legacy-$type-${sha256.convert(utf8.encode(path))}';

  Future<Map<String, dynamic>> snapshot() => isar.txn(() async {
    final items = await isar.mediaItems.where().findAll();
    final collections = await isar.mediaCollections.where().findAll();
    if (items.any((item) => item.sourceType != MediaSourceType.localCopy) ||
        collections.any(
          (collection) => collection.type == CollectionType.externalFolder,
        )) {
      throw const FormatException(
        'External references must be copied into the library before backup',
      );
    }
    final tags = await isar.tags.where().findAll();
    final facets = await isar.tagFacets.where().findAll();
    final history = await isar.viewingHistorys.where().findAll();
    final itemUids = {
      for (final item in items) item.id: identity(item.uid, 'item', item.path),
    };
    final tagKeys = {for (final tag in tags) tag.id: tag.key};
    final knownItemUids = itemUids.values.toSet();
    final facetNames = {for (final facet in facets) facet.id: facet.name};
    final ownedItems = <String>{};
    final collectionRecords = <Map<String, dynamic>>[];
    for (final collection in collections) {
      await collection.items.load();
      await collection.tags.load();
      final linked = collection.items
          .map((item) => itemUids[item.id])
          .whereType<String>()
          .toList();
      ownedItems.addAll(linked);
      collectionRecords.add({
        'uid': identity(collection.uid, 'collection', collection.path),
        'path': collection.path,
        'title': collection.title,
        'alias': collection.alias,
        'type': collection.type.name,
        'isCatalog': collection.isCatalog,
        'createdAt': collection.createdAt.toIso8601String(),
        'updatedAt': collection.updatedAt.toIso8601String(),
        'itemUids': linked,
        'tagKeys': collection.tags.map((tag) => tag.key).toList(),
        'coverImagePath': collection.coverImagePath,
        'isFavorite': collection.isFavorite,
        'notes': collection.notes,
        'lastViewedAt': collection.lastViewedAt?.toIso8601String(),
        'lastViewedItemUid': itemUids[collection.lastViewedItemId],
        'isPinned': collection.isPinned,
        'isArchived': collection.isArchived,
        'isHidden': collection.isHidden,
        'isTrashed': collection.isTrashed,
        'trashRootPath': collection.trashRootPath,
        'defaultSortOrder': collection.defaultSortOrder.name,
        'defaultViewMode': collection.defaultViewMode.name,
        'splitSpreadView': collection.splitSpreadView,
        'isHeaderExpanded': collection.isHeaderExpanded,
        'tier': collection.tier,
      });
    }
    // Preserve old shelves whose ownership link was missing but display worked
    // by path. Only an unambiguous exact-path collection is eligible.
    for (final item in items) {
      final uid = itemUids[item.id]!;
      if (ownedItems.contains(uid)) continue;
      final matching = collectionRecords
          .where((record) => record['path'] == item.path)
          .toList();
      if (matching.length == 1) {
        (matching.single['itemUids'] as List<String>).add(uid);
      }
    }
    return {
      'format': 'TagShelf library',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'facets': facets
          .map(
            (facet) => {
              'name': facet.name,
              'colorValue': facet.colorValue,
              'sortOrder': facet.sortOrder,
              'createdAt': facet.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'tags': tags
          .map(
            (tag) => {
              'key': tag.key,
              'name': tag.name,
              'facetName': facetNames[tag.facetId],
              'parentKey': tagKeys[tag.parentId],
              'level': tag.level,
              'colorValue': tag.colorValue,
              'usageCount': tag.usageCount,
              'isHidden': tag.isHidden,
              'createdAt': tag.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'collections': collectionRecords,
      'items': items
          .map(
            (item) => {
              'uid': itemUids[item.id],
              'path': item.path,
              'type': item.type.name,
              'addedAt': item.addedAt.toIso8601String(),
              'updatedAt': item.updatedAt.toIso8601String(),
              'size': item.size,
              'thumbnailPath': item.thumbnailPath,
              'parentPath': item.parentPath,
              'isMissing': item.isMissing,
              'missingCheckedAt': item.missingCheckedAt?.toIso8601String(),
              'isArchived': item.isArchived,
              'isHidden': item.isHidden,
              'isFavorite': item.isFavorite,
              'isTrashed': item.isTrashed,
              'isTrashRoot': item.isTrashRoot,
              'trashedAt': item.trashedAt?.toIso8601String(),
              'trashPath': item.trashPath,
              'trashRootPath': item.trashRootPath,
            },
          )
          .toList(),
      'history': history
          .where((entry) => knownItemUids.contains(entry.itemUid))
          .map(
            (entry) => {
              'itemUid': entry.itemUid,
              'openedAt': entry.openedAt.toIso8601String(),
            },
          )
          .toList(),
    };
  });

  /// Merge only new identities. Existing library data always wins. Publication
  /// of items, links, facets, history and storage references is one transaction.
  Future<LibraryRestoreResult> merge(
    Map<String, dynamic> document,
    String Function(String path) remapPath, {
    Future<void> Function()? beforeCommit,
    Map<String, String> restoreContainers = const {},
    Set<String> contextFolderPaths = const {},
  }) async {
    LibraryBackupArchive.validateDocument(document);
    var added = 0;
    var skipped = 0;
    await isar.writeTxn(() async {
      final itemByUid = <String, MediaItem>{};
      for (final item in await isar.mediaItems.where().findAll()) {
        itemByUid[identity(item.uid, 'item', item.path)] = item;
      }
      final collectionByUid = <String, MediaCollection>{};
      for (final collection in await isar.mediaCollections.where().findAll()) {
        collectionByUid[identity(
              collection.uid,
              'collection',
              collection.path,
            )] =
            collection;
      }
      final facetByName = {
        for (final facet in await isar.tagFacets.where().findAll())
          facet.name: facet,
      };
      for (final entry in restoreContainers.entries) {
        final now = DateTime.now();
        final folder = MediaItem()
          ..uid = 'backup-container-${entry.key}'
          ..path = entry.key
          ..type = MediaType.folder
          ..addedAt = now
          ..updatedAt = now;
        await isar.mediaItems.put(folder);
        final shelf = MediaCollection()
          ..uid = 'backup-container-shelf-${entry.key}'
          ..path = entry.key
          ..title = entry.value
          ..alias = entry.value
          ..type = CollectionType.folder
          ..isCatalog = true
          ..createdAt = now
          ..updatedAt = now;
        await isar.mediaCollections.put(shelf);
        shelf.items.add(folder);
        await shelf.items.save();
        await _storageRef(folder.uid!, StorageOwnerType.item, folder.path, now);
        await _storageRef(
          shelf.uid!,
          StorageOwnerType.collection,
          shelf.path,
          now,
        );
      }
      for (final record in _records(document, 'facets')) {
        final name = record['name'] as String;
        if (facetByName.containsKey(name)) continue;
        final facet = TagFacet()
          ..name = name
          ..colorValue = record['colorValue'] as int?
          ..sortOrder = record['sortOrder'] as int
          ..createdAt = LibraryBackupArchive.date(record, 'createdAt');
        await isar.tagFacets.put(facet);
        facetByName[name] = facet;
      }
      final tagByKey = {
        for (final tag in await isar.tags.where().findAll()) tag.key: tag,
      };
      final newTags = <String>{};
      final tagKeyMapping = <String, String>{};
      for (final record in _records(document, 'tags')) {
        final facet = facetByName[record['facetName']];
        final originalKey = record['key'] as String;
        final name = record['name'] as String;
        // Database IDs are device-local; rebuild the unique key with the
        // restored facet ID rather than carrying another device's integer.
        final key = Tag.buildKey(facet?.id ?? 0, name);
        tagKeyMapping[originalKey] = key;
        if (tagByKey.containsKey(key)) continue;
        final tag = Tag()
          ..key = key
          ..name = name
          ..facetId = facet?.id
          ..level = record['level'] as int
          ..colorValue = record['colorValue'] as int?
          ..isHidden = record['isHidden'] as bool
          ..createdAt = LibraryBackupArchive.date(record, 'createdAt');
        await isar.tags.put(tag);
        tagByKey[key] = tag;
        newTags.add(key);
      }
      for (final record in _records(document, 'tags')) {
        final key = tagKeyMapping[record['key']]!;
        if (!newTags.contains(key)) continue;
        tagByKey[key]!.parentId = record['parentKey'] == null
            ? null
            : tagByKey[tagKeyMapping[record['parentKey']]]!.id;
      }
      final tagById = {for (final tag in tagByKey.values) tag.id: tag};
      final initializedTags = <int>{};
      final newTagIds = {for (final key in newTags) tagByKey[key]!.id};
      void initializeHierarchy(Tag tag, Set<int> visiting) {
        if (!newTagIds.contains(tag.id) || initializedTags.contains(tag.id)) {
          return;
        }
        if (!visiting.add(tag.id)) {
          throw const FormatException('Invalid merged tag hierarchy');
        }
        final parent = tagById[tag.parentId];
        if (parent != null) {
          initializeHierarchy(parent, visiting);
          tag.level = parent.level + 1;
        }
        final ancestors = <int>[];
        final seen = <int>{tag.id};
        var current = parent;
        while (current != null) {
          if (!seen.add(current.id) || seen.length > 100) {
            throw const FormatException('Invalid merged tag hierarchy');
          }
          ancestors.add(current.id);
          if (current.parentId != null &&
              !tagById.containsKey(current.parentId)) {
            throw const FormatException('Missing tag parent');
          }
          current = tagById[current.parentId];
        }
        tag.ancestorIds = ancestors.reversed.toList();
        visiting.remove(tag.id);
        initializedTags.add(tag.id);
      }

      for (final key in newTags) {
        final tag = tagByKey[key]!;
        initializeHierarchy(tag, <int>{});
        await isar.tags.put(tag);
      }
      final newItemUids = <String>{};
      final contextItems = <String, MediaItem>{};
      for (final record in _records(document, 'items')) {
        final uid = record['uid'] as String;
        final isContext =
            itemByUid.containsKey(uid) &&
            record['type'] == 'folder' &&
            contextFolderPaths.contains(record['path']) &&
            remapPath(record['path'] as String) != itemByUid[uid]!.path;
        if (itemByUid.containsKey(uid) && !isContext) {
          skipped++;
          continue;
        }
        final item = MediaItem()
          ..uid = isContext
              ? 'backup-context-${remapPath(record['path'] as String)}-$uid'
              : uid
          ..path = remapPath(record['path'] as String)
          ..sourceType = MediaSourceType.localCopy
          ..type = MediaType.values.byName(record['type'] as String)
          ..addedAt = LibraryBackupArchive.date(record, 'addedAt')
          ..updatedAt = LibraryBackupArchive.date(record, 'updatedAt')
          ..size = record['size'] as int?
          ..thumbnailPath = _remapOptional(record, 'thumbnailPath', remapPath)
          ..parentPath = _remapParent(record, remapPath)
          ..isMissing = record['isMissing'] as bool
          ..missingCheckedAt = LibraryBackupArchive.optionalDate(
            record,
            'missingCheckedAt',
          )
          ..isArchived = record['isArchived'] as bool
          ..isHidden = record['isHidden'] as bool
          ..isFavorite = record['isFavorite'] as bool
          ..isTrashed = record['isTrashed'] as bool
          ..isTrashRoot = record['isTrashRoot'] as bool
          ..trashedAt = LibraryBackupArchive.optionalDate(record, 'trashedAt')
          ..trashPath = _remapOptional(record, 'trashPath', remapPath)
          ..trashRootPath = _remapOptional(record, 'trashRootPath', remapPath);
        await isar.mediaItems.put(item);
        if (isContext) {
          contextItems[uid] = item;
          skipped++;
        } else {
          itemByUid[uid] = item;
          newItemUids.add(uid);
          added++;
        }
        await _storageRef(
          item.uid!,
          StorageOwnerType.item,
          item.path,
          item.addedAt,
        );
      }
      for (final record in _records(document, 'collections')) {
        final uid = record['uid'] as String;
        final existing = collectionByUid[uid];
        if (existing != null) {
          final children = LibraryBackupArchive.stringList(record, 'itemUids');
          if (!children.any(
            (uid) => newItemUids.contains(uid) || contextItems.containsKey(uid),
          )) {
            continue;
          }
        }
        final collection = MediaCollection()
          ..uid = existing == null
              ? uid
              : 'backup-context-shelf-${remapPath(record['path'] as String)}-$uid'
          ..path = remapPath(record['path'] as String)
          ..title = record['title'] as String
          ..alias = record['alias'] as String?
          ..type = CollectionType.values.byName(record['type'] as String)
          ..isCatalog = record['isCatalog'] as bool
          ..createdAt = LibraryBackupArchive.date(record, 'createdAt')
          ..updatedAt = LibraryBackupArchive.date(record, 'updatedAt')
          ..coverImagePath = _remapOptional(record, 'coverImagePath', remapPath)
          ..isFavorite = record['isFavorite'] as bool
          ..notes = record['notes'] as String?
          ..lastViewedAt = LibraryBackupArchive.optionalDate(
            record,
            'lastViewedAt',
          )
          ..lastViewedItemId =
              (contextItems[record['lastViewedItemUid']] ??
                      (existing == null ||
                              newItemUids.contains(record['lastViewedItemUid'])
                          ? itemByUid[record['lastViewedItemUid']]
                          : null))
                  ?.id
          ..isPinned = record['isPinned'] as bool
          ..isArchived = record['isArchived'] as bool
          ..isHidden = record['isHidden'] as bool
          ..isTrashed = record['isTrashed'] as bool
          ..trashRootPath = _remapOptional(record, 'trashRootPath', remapPath)
          ..defaultSortOrder = SortOrder.values.byName(
            record['defaultSortOrder'] as String,
          )
          ..defaultViewMode = ViewMode.values.byName(
            record['defaultViewMode'] as String,
          )
          ..splitSpreadView = record['splitSpreadView'] as bool
          ..isHeaderExpanded = record['isHeaderExpanded'] as bool
          ..tier = record['tier'] as int;
        final collision = await isar.mediaCollections
            .filter()
            .pathEqualTo(collection.path)
            .findFirst();
        if (collision != null) {
          throw const FormatException(
            'A restored shelf conflicts with existing data',
          );
        }
        await isar.mediaCollections.put(collection);
        collection.tags.addAll(
          LibraryBackupArchive.stringList(
            record,
            'tagKeys',
          ).map((key) => tagByKey[tagKeyMapping[key]]!),
        );
        // An imported collection must never steal an existing item's owner.
        for (final itemUid in LibraryBackupArchive.stringList(
          record,
          'itemUids',
        )) {
          final context = contextItems[itemUid];
          if (context != null) {
            collection.items.add(context);
          } else if (newItemUids.contains(itemUid)) {
            collection.items.add(itemByUid[itemUid]!);
          } else if (existing == null) {
            final item = itemByUid[itemUid]!;
            await item.collection.load();
            if (item.collection.value == null) collection.items.add(item);
          }
        }
        await collection.tags.save();
        await collection.items.save();
        if (existing == null) collectionByUid[uid] = collection;
        await _storageRef(
          collection.uid!,
          StorageOwnerType.collection,
          collection.path,
          collection.createdAt,
        );
      }
      for (final record in _records(document, 'history')) {
        final uid = record['itemUid'] as String;
        if (!newItemUids.contains(uid)) continue;
        await isar.viewingHistorys.put(
          ViewingHistory()
            ..itemUid = uid
            ..openedAt = LibraryBackupArchive.date(record, 'openedAt'),
        );
      }
      // Counts are derived from the merged links, not trusted archive counters.
      for (final tag in tagByKey.values) {
        tag.usageCount = await isar.mediaCollections
            .filter()
            .tags((q) => q.idEqualTo(tag.id))
            .count();
        await isar.tags.put(tag);
      }
      await beforeCommit?.call();
    });
    return LibraryRestoreResult(addedItems: added, skippedItems: skipped);
  }

  Future<void> _storageRef(
    String uid,
    StorageOwnerType type,
    String path,
    DateTime createdAt,
  ) async {
    await isar.storageRefs.put(
      StorageRef()
        ..uid = 'backup-$uid'
        ..ownerUid = uid
        ..ownerType = type
        ..sourceType = StorageSourceType.local
        ..locator = path
        ..normalizedLocator = path
        ..createdAt = createdAt
        ..updatedAt = DateTime.now(),
    );
  }

  static List<Map<String, dynamic>> _records(
    Map<String, dynamic> document,
    String key,
  ) => (document[key] as List).cast<Map<String, dynamic>>();
  static String? _remapOptional(
    Map<String, dynamic> record,
    String key,
    String Function(String) remap,
  ) => LibraryBackupArchive.optionalText(record, key) == null
      ? null
      : remap(record[key] as String);
  static String? _remapParent(
    Map<String, dynamic> record,
    String Function(String) remap,
  ) {
    final parent = LibraryBackupArchive.optionalText(record, 'parentPath');
    return parent == null || parent == 'library' || parent == 'folders'
        ? remap((record['path'] as String).split('/').first)
        : remap(parent);
  }
}
