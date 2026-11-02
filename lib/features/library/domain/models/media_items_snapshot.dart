import 'package:private_shelf/features/library/domain/models/media_item.dart';

// Copy values rather than retaining mutable Isar objects. Category and pin
// changes outside the page still reload the complete ordering before limit;
// only an identical visible result is suppressed.
List<Object?> mediaItemsSnapshot(List<MediaItem> items) => [
  for (final item in items)
    [
      item.id,
      item.uid,
      item.path,
      item.originalPath,
      item.sourceType,
      item.addedAt,
      item.updatedAt,
      item.size,
      item.type,
      item.thumbnailPath,
      item.parentPath,
      item.isMissing,
      item.missingCheckedAt,
      item.isArchived,
      item.isHidden,
      item.isFavorite,
      item.isTrashed,
      item.isTrashRoot,
      item.trashedAt,
      item.trashPath,
      item.trashRootPath,
      item.mimeType,
      if (item.collection.value case final collection?)
        [
          collection.id,
          collection.uid,
          collection.path,
          collection.title,
          collection.alias,
          collection.type,
          collection.isCatalog,
          collection.createdAt,
          collection.updatedAt,
          collection.coverImagePath,
          collection.isFavorite,
          collection.notes,
          collection.lastViewedAt,
          collection.lastViewedItemId,
          collection.isPinned,
          collection.isArchived,
          collection.isHidden,
          collection.isTrashed,
          collection.trashRootPath,
          collection.defaultSortOrder,
          collection.defaultViewMode,
          collection.splitSpreadView,
          collection.isHeaderExpanded,
          collection.tier,
          for (final tag in collection.tags)
            [
              tag.id,
              tag.key,
              tag.name,
              tag.facetId,
              tag.parentId,
              tag.level,
              [...tag.ancestorIds],
              tag.colorValue,
              tag.usageCount,
              tag.isHidden,
              tag.createdAt,
            ],
        ]
      else
        null,
    ],
];
