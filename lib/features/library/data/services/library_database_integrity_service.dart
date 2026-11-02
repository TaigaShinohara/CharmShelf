import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/library_integrity_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';

class LibraryDatabaseIntegrityService {
  LibraryDatabaseIntegrityService(this._isar, {this._uuid = const Uuid()});

  final Isar _isar;
  final Uuid _uuid;

  Future<Result<LibraryIntegrityReport, AppError>> audit() async {
    try {
      final snapshot = await _loadSnapshot();
      return Result.success(_auditSnapshot(snapshot));
    } catch (error, stackTrace) {
      AppLogger.e(LogTag.db, 'ライブラリDBの整合性検査に失敗', error, stackTrace);
      return Result.failure(
        AppError.database(
          'Library database integrity audit failed',
          original: error,
          stackTrace: stackTrace,
          context: 'LibraryDatabaseIntegrityService.audit',
        ),
      );
    }
  }

  Future<Result<LibraryIntegrityRepairResult, AppError>>
  repairSafeIssues() async {
    try {
      late LibraryIntegrityReport before;
      final changedRecords = <String>{};
      await _isar.writeTxn(() async {
        final snapshot = await _loadSnapshot();
        before = _auditSnapshot(snapshot);
        final linkRepairs = CollectionItemLinkService.planRepairs(
          snapshot.collections,
          snapshot.items,
        );
        final linkService = CollectionItemLinkService(_isar);
        for (final repair in linkRepairs) {
          await linkService.applyRepair(repair);
          changedRecords.add('collection:${repair.target.id}');
          if (repair.previousParent != null) {
            changedRecords.add('collection:${repair.previousParent!.id}');
          }
        }

        final collectionUids = snapshot.collections
            .map((collection) => collection.uid)
            .whereType<String>()
            .where((uid) => uid.isNotEmpty)
            .toSet();
        final itemUids = snapshot.items
            .map((item) => item.uid)
            .whereType<String>()
            .where((uid) => uid.isNotEmpty)
            .toSet();

        final orphanStorageRefIds = snapshot.storageRefs
            .where((ref) {
              if (ref.ownerUid.isEmpty) return true;
              return switch (ref.ownerType) {
                StorageOwnerType.collection => !collectionUids.contains(
                  ref.ownerUid,
                ),
                StorageOwnerType.item => !itemUids.contains(ref.ownerUid),
              };
            })
            .map((ref) => ref.id)
            .toSet();

        final primaryGroups = _primaryStorageRefGroups(snapshot.storageRefs);
        final primaryRefsToDemote = <StorageRef>[];
        for (final refs in primaryGroups.values.where(
          (group) => group.length > 1,
        )) {
          final newestTimestamp = refs
              .map((ref) => ref.updatedAt)
              .reduce((left, right) => left.isAfter(right) ? left : right);
          final newestRefs = refs
              .where((ref) => ref.updatedAt.isAtSameMomentAs(newestTimestamp))
              .toList(growable: false);
          if (newestRefs.length != 1) continue;
          final newestId = newestRefs.single.id;
          primaryRefsToDemote.addAll(
            refs.where(
              (ref) =>
                  ref.id != newestId && !orphanStorageRefIds.contains(ref.id),
            ),
          );
        }

        final expectedHierarchy = _expectedTagHierarchy(snapshot.tags);
        final tagsToUpdate = <Tag>[];
        final expectedUsageCounts = _expectedTagUsageCounts(
          snapshot.collections,
        );
        for (final tag in snapshot.tags) {
          var changed = false;
          final hierarchy = expectedHierarchy[tag.id];
          if (hierarchy != null &&
              (tag.level != hierarchy.level ||
                  !_sameIds(tag.ancestorIds, hierarchy.ancestorIds))) {
            tag
              ..level = hierarchy.level
              ..ancestorIds = hierarchy.ancestorIds;
            changed = true;
          }
          final expectedUsageCount = expectedUsageCounts[tag.id] ?? 0;
          if (tag.usageCount != expectedUsageCount) {
            tag.usageCount = expectedUsageCount;
            changed = true;
          }
          if (changed) tagsToUpdate.add(tag);
        }

        final itemsById = {for (final item in snapshot.items) item.id: item};
        final invalidLastViewedCollections = snapshot.collections
            .where((collection) {
              final itemId = collection.lastViewedItemId;
              if (itemId == null) return false;
              final item = itemsById[itemId];
              return item == null || !_isItemInCollection(collection, item);
            })
            .toList(growable: false);

        final collectionsWithMissingUid = snapshot.collections
            .where(
              (collection) => collection.uid == null || collection.uid!.isEmpty,
            )
            .toList(growable: false);
        final itemsWithMissingUid = snapshot.items
            .where((item) => item.uid == null || item.uid!.isEmpty)
            .toList(growable: false);
        final usedCollectionUids = Set<String>.from(collectionUids);
        for (final collection in collectionsWithMissingUid) {
          collection.uid = _newUniqueUid(usedCollectionUids);
        }
        final usedItemUids = Set<String>.from(itemUids);
        for (final item in itemsWithMissingUid) {
          item.uid = _newUniqueUid(usedItemUids);
        }

        if (orphanStorageRefIds.isNotEmpty) {
          await _isar.storageRefs.deleteAll(orphanStorageRefIds.toList());
          changedRecords.addAll(
            orphanStorageRefIds.map((id) => 'storageRef:$id'),
          );
        }

        for (final ref in primaryRefsToDemote) {
          ref.isPrimary = false;
        }
        if (primaryRefsToDemote.isNotEmpty) {
          await _isar.storageRefs.putAll(primaryRefsToDemote);
          changedRecords.addAll(
            primaryRefsToDemote.map((ref) => 'storageRef:${ref.id}'),
          );
        }

        if (tagsToUpdate.isNotEmpty) {
          await _isar.tags.putAll(tagsToUpdate);
          changedRecords.addAll(tagsToUpdate.map((tag) => 'tag:${tag.id}'));
        }

        for (final collection in invalidLastViewedCollections) {
          collection.lastViewedItemId = null;
        }
        final changedCollections = <MediaCollection>{
          ...invalidLastViewedCollections,
          ...collectionsWithMissingUid,
        };
        if (changedCollections.isNotEmpty) {
          await _isar.mediaCollections.putAll(changedCollections.toList());
          changedRecords.addAll(
            changedCollections.map(
              (collection) => 'collection:${collection.id}',
            ),
          );
        }

        if (itemsWithMissingUid.isNotEmpty) {
          await _isar.mediaItems.putAll(itemsWithMissingUid);
          changedRecords.addAll(
            itemsWithMissingUid.map((item) => 'mediaItem:${item.id}'),
          );
        }
      });

      final afterSnapshot = await _loadSnapshot();
      final after = _auditSnapshot(afterSnapshot);
      if (!after.isHealthy) {
        AppLogger.w(
          LogTag.db,
          'ライブラリDBに自動修復対象外の不整合が${after.issues.length}件あります',
        );
      }
      return Result.success(
        LibraryIntegrityRepairResult(
          before: before,
          after: after,
          changedRecordCount: changedRecords.length,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e(LogTag.db, 'ライブラリDBの整合性修復に失敗', error, stackTrace);
      return Result.failure(
        AppError.database(
          'Library database integrity repair failed',
          original: error,
          stackTrace: stackTrace,
          context: 'LibraryDatabaseIntegrityService.repairSafeIssues',
        ),
      );
    }
  }

  Future<_IntegritySnapshot> _loadSnapshot() async {
    final collections = await _isar.mediaCollections.where().findAll();
    final items = await _isar.mediaItems.where().findAll();
    final tags = await _isar.tags.where().findAll();
    final facets = await _isar.tagFacets.where().findAll();
    final storageRefs = await _isar.storageRefs.where().findAll();
    for (final collection in collections) {
      await collection.items.load();
      await collection.tags.load();
    }
    return _IntegritySnapshot(
      collections: collections,
      items: items,
      tags: tags,
      facets: facets,
      storageRefs: storageRefs,
    );
  }

  LibraryIntegrityReport _auditSnapshot(_IntegritySnapshot snapshot) {
    final issues = <LibraryIntegrityIssue>[];
    for (final repair in CollectionItemLinkService.planRepairs(
      snapshot.collections,
      snapshot.items,
    )) {
      issues.add(
        LibraryIntegrityIssue(
          type: LibraryIntegrityIssueType.missingMediaItemCollectionLink,
          entityType: LibraryIntegrityEntityType.mediaItem,
          entityId: repair.item.id,
          entityUid: repair.item.uid,
          isRepairable: true,
          relatedEntityIds: [repair.target.id],
        ),
      );
    }
    final collectionUids = snapshot.collections
        .map((collection) => collection.uid)
        .whereType<String>()
        .where((uid) => uid.isNotEmpty)
        .toSet();
    final itemUids = snapshot.items
        .map((item) => item.uid)
        .whereType<String>()
        .where((uid) => uid.isNotEmpty)
        .toSet();

    for (final collection in snapshot.collections) {
      if (collection.uid == null || collection.uid!.isEmpty) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.missingUid,
            entityType: LibraryIntegrityEntityType.collection,
            entityId: collection.id,
            isRepairable: true,
          ),
        );
      }
    }
    for (final item in snapshot.items) {
      if (item.uid == null || item.uid!.isEmpty) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.missingUid,
            entityType: LibraryIntegrityEntityType.mediaItem,
            entityId: item.id,
            isRepairable: true,
          ),
        );
      }
    }

    for (final ref in snapshot.storageRefs) {
      final ownerExists =
          ref.ownerUid.isNotEmpty &&
          switch (ref.ownerType) {
            StorageOwnerType.collection => collectionUids.contains(
              ref.ownerUid,
            ),
            StorageOwnerType.item => itemUids.contains(ref.ownerUid),
          };
      if (!ownerExists) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.orphanStorageRef,
            entityType: LibraryIntegrityEntityType.storageRef,
            entityId: ref.id,
            entityUid: ref.uid,
            isRepairable: true,
          ),
        );
      }
    }

    for (final refs in _primaryStorageRefGroups(snapshot.storageRefs).values) {
      if (refs.length < 2) continue;
      final newestTimestamp = refs
          .map((ref) => ref.updatedAt)
          .reduce((left, right) => left.isAfter(right) ? left : right);
      final hasSingleNewest =
          refs
              .where((ref) => ref.updatedAt.isAtSameMomentAs(newestTimestamp))
              .length ==
          1;
      issues.add(
        LibraryIntegrityIssue(
          type: LibraryIntegrityIssueType.duplicatePrimaryStorageRef,
          entityType: LibraryIntegrityEntityType.storageRef,
          entityId: refs.first.id,
          entityUid: refs.first.ownerUid,
          isRepairable: hasSingleNewest,
          relatedEntityIds: refs.map((ref) => ref.id).toList(growable: false),
        ),
      );
    }

    final facetsById = {for (final facet in snapshot.facets) facet.id: facet};
    final tagsById = {for (final tag in snapshot.tags) tag.id: tag};
    final expectedHierarchy = _expectedTagHierarchy(snapshot.tags);
    for (final tag in snapshot.tags) {
      final facetId = tag.facetId;
      if (facetId == null || !facetsById.containsKey(facetId)) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.missingTagFacet,
            entityType: LibraryIntegrityEntityType.tag,
            entityId: tag.id,
            isRepairable: false,
          ),
        );
      }

      final parentId = tag.parentId;
      final parent = parentId == null ? null : tagsById[parentId];
      if (parentId != null && parent == null) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.missingTagParent,
            entityType: LibraryIntegrityEntityType.tag,
            entityId: tag.id,
            isRepairable: false,
            relatedEntityIds: [parentId],
          ),
        );
      } else if (parent != null && parent.facetId != tag.facetId) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.tagParentFacetMismatch,
            entityType: LibraryIntegrityEntityType.tag,
            entityId: tag.id,
            isRepairable: false,
            relatedEntityIds: [parent.id],
          ),
        );
      }

      if (_tagHasCycle(tag.id, tagsById)) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.tagCycle,
            entityType: LibraryIntegrityEntityType.tag,
            entityId: tag.id,
            isRepairable: false,
          ),
        );
      } else {
        final hierarchy = expectedHierarchy[tag.id];
        if (hierarchy != null &&
            (tag.level != hierarchy.level ||
                !_sameIds(tag.ancestorIds, hierarchy.ancestorIds))) {
          issues.add(
            LibraryIntegrityIssue(
              type: LibraryIntegrityIssueType.invalidTagHierarchy,
              entityType: LibraryIntegrityEntityType.tag,
              entityId: tag.id,
              isRepairable: true,
            ),
          );
        }
      }
    }

    final expectedUsageCounts = _expectedTagUsageCounts(snapshot.collections);
    for (final tag in snapshot.tags) {
      if (tag.usageCount != (expectedUsageCounts[tag.id] ?? 0)) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.incorrectTagUsageCount,
            entityType: LibraryIntegrityEntityType.tag,
            entityId: tag.id,
            isRepairable: true,
          ),
        );
      }
    }

    final itemsById = {for (final item in snapshot.items) item.id: item};
    final ownerCollectionIdsByItemId = <int, List<int>>{};
    for (final collection in snapshot.collections) {
      final lastViewedItemId = collection.lastViewedItemId;
      final lastViewedItem = lastViewedItemId == null
          ? null
          : itemsById[lastViewedItemId];
      if (lastViewedItemId != null &&
          (lastViewedItem == null ||
              !_isItemInCollection(collection, lastViewedItem))) {
        issues.add(
          LibraryIntegrityIssue(
            type: LibraryIntegrityIssueType.invalidLastViewedItem,
            entityType: LibraryIntegrityEntityType.collection,
            entityId: collection.id,
            entityUid: collection.uid,
            isRepairable: true,
            relatedEntityIds: [lastViewedItemId],
          ),
        );
      }
      for (final item in collection.items) {
        ownerCollectionIdsByItemId
            .putIfAbsent(item.id, () => <int>[])
            .add(collection.id);
      }
    }
    for (final entry in ownerCollectionIdsByItemId.entries) {
      if (entry.value.length < 2) continue;
      issues.add(
        LibraryIntegrityIssue(
          type: LibraryIntegrityIssueType.multiplyOwnedMediaItem,
          entityType: LibraryIntegrityEntityType.mediaItem,
          entityId: entry.key,
          isRepairable: false,
          relatedEntityIds: entry.value,
        ),
      );
    }

    return LibraryIntegrityReport(List.unmodifiable(issues));
  }

  Map<String, List<StorageRef>> _primaryStorageRefGroups(
    List<StorageRef> refs,
  ) {
    final groups = <String, List<StorageRef>>{};
    for (final ref in refs.where((ref) => ref.isPrimary)) {
      final key = '${ref.ownerType.name}:${ref.ownerUid}';
      groups.putIfAbsent(key, () => <StorageRef>[]).add(ref);
    }
    return groups;
  }

  Map<int, int> _expectedTagUsageCounts(List<MediaCollection> collections) {
    final counts = <int, int>{};
    for (final collection in collections) {
      for (final tag in collection.tags) {
        counts[tag.id] = (counts[tag.id] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<int, _ExpectedTagHierarchy?> _expectedTagHierarchy(List<Tag> tags) {
    final tagsById = {for (final tag in tags) tag.id: tag};
    final cache = <int, _ExpectedTagHierarchy?>{};

    _ExpectedTagHierarchy? resolve(int tagId, Set<int> visiting) {
      if (cache.containsKey(tagId)) return cache[tagId];
      if (!visiting.add(tagId)) return null;
      final tag = tagsById[tagId];
      if (tag == null) return null;
      final parentId = tag.parentId;
      if (parentId == null) {
        final result = _ExpectedTagHierarchy(
          level: tag.level,
          ancestorIds: const [],
        );
        cache[tagId] = result;
        visiting.remove(tagId);
        return result;
      }
      final parent = tagsById[parentId];
      if (parent == null || parent.facetId != tag.facetId) {
        cache[tagId] = null;
        visiting.remove(tagId);
        return null;
      }
      final parentHierarchy = resolve(parentId, visiting);
      if (parentHierarchy == null) {
        cache[tagId] = null;
        visiting.remove(tagId);
        return null;
      }
      final result = _ExpectedTagHierarchy(
        level: parentHierarchy.level + 1,
        ancestorIds: [parentId, ...parentHierarchy.ancestorIds],
      );
      cache[tagId] = result;
      visiting.remove(tagId);
      return result;
    }

    for (final tag in tags) {
      cache[tag.id] = resolve(tag.id, <int>{});
    }
    return cache;
  }

  bool _tagHasCycle(int tagId, Map<int, Tag> tagsById) {
    final visited = <int>{};
    var currentId = tagId;
    while (true) {
      if (!visited.add(currentId)) return true;
      final parentId = tagsById[currentId]?.parentId;
      if (parentId == null || !tagsById.containsKey(parentId)) return false;
      currentId = parentId;
    }
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _isItemInCollection(MediaCollection collection, MediaItem item) {
    return collection.items.any((linkedItem) => linkedItem.id == item.id) ||
        item.path == collection.path ||
        item.parentPath == collection.path;
  }

  String _newUniqueUid(Set<String> usedUids) {
    for (var attempt = 0; attempt < 10; attempt++) {
      final uid = _uuid.v4();
      if (uid.isNotEmpty && usedUids.add(uid)) return uid;
    }
    throw StateError('Could not generate a unique non-empty UID');
  }
}

class _IntegritySnapshot {
  const _IntegritySnapshot({
    required this.collections,
    required this.items,
    required this.tags,
    required this.facets,
    required this.storageRefs,
  });

  final List<MediaCollection> collections;
  final List<MediaItem> items;
  final List<Tag> tags;
  final List<TagFacet> facets;
  final List<StorageRef> storageRefs;
}

class _ExpectedTagHierarchy {
  const _ExpectedTagHierarchy({required this.level, required this.ancestorIds});

  final int level;
  final List<int> ancestorIds;
}
