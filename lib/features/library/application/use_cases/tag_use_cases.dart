// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/repositories/tag_facet_repository_provider.dart';
import 'package:private_shelf/features/library/data/repositories/tag_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_facet_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';

part 'tag_use_cases.g.dart';

// --- GetTagsUseCase ---
@Riverpod(keepAlive: true)
GetTagsUseCase getTagsUseCase(Ref ref) {
  return GetTagsUseCase(ref.read(tagRepositoryProvider.future));
}

class GetTagsUseCase {
  final Future<TagRepository> _tagRepositoryFuture;

  GetTagsUseCase(this._tagRepositoryFuture);

  Future<Result<List<Tag>, AppError>> invoke() async {
    try {
      final repo = await _tagRepositoryFuture;
      return await repo.getAll();
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('GetTags failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

@Riverpod(keepAlive: true)
EnsureTagDefaultsUseCase ensureTagDefaultsUseCase(
  Ref ref,
) {
  return EnsureTagDefaultsUseCase(
    ref.read(tagRepositoryProvider.future),
    ref.read(tagFacetRepositoryProvider.future),
  );
}

class EnsureTagDefaultsUseCase {
  final Future<TagRepository> _tagRepositoryFuture;
  final Future<TagFacetRepository> _facetRepositoryFuture;

  EnsureTagDefaultsUseCase(
    this._tagRepositoryFuture,
    this._facetRepositoryFuture,
  );

  Future<Result<void, AppError>> invoke() async {
    try {
      final tagRepo = await _tagRepositoryFuture;
      final facetRepo = await _facetRepositoryFuture;
      final defaultFacet = await _ensureDefaultFacet(facetRepo);

      final tagsResult = await tagRepo.getAll();
      if (tagsResult is Failure<List<Tag>, AppError>) {
        return Result.failure(tagsResult.error);
      }

      final tags = (tagsResult as Success<List<Tag>, AppError>).data;
      final updatedTags = <Tag>[];
      for (final tag in tags) {
        var changed = false;
        if (tag.facetId == null) {
          tag.facetId = defaultFacet.id;
          changed = true;
        }
        if (tag.key.isEmpty) {
          tag.key = Tag.buildKey(tag.facetId!, tag.name);
          changed = true;
        }
        if (tag.level <= 0) {
          tag.level = 100;
          changed = true;
        }
        if (tag.parentId != null && tag.ancestorIds.isEmpty) {
          tag.ancestorIds = await _resolveAncestorIds(tagRepo, tag.parentId);
          changed = true;
        }
        if (changed) {
          updatedTags.add(tag);
        }
      }

      if (updatedTags.isNotEmpty) {
        final saveResult = await tagRepo.saveAll(updatedTags);
        if (saveResult is Failure<void, AppError>) {
          return Result.failure(saveResult.error);
        }
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'EnsureTagDefaults failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}

@Riverpod(keepAlive: true)
GetTagFacetsUseCase getTagFacetsUseCase(Ref ref) {
  return GetTagFacetsUseCase(ref.read(tagFacetRepositoryProvider.future));
}

class GetTagFacetsUseCase {
  final Future<TagFacetRepository> _facetRepositoryFuture;

  GetTagFacetsUseCase(this._facetRepositoryFuture);

  Future<Result<List<TagFacet>, AppError>> invoke() async {
    try {
      final repo = await _facetRepositoryFuture;
      return await repo.getAll();
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'GetTagFacets failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}

@Riverpod(keepAlive: true)
CreateTagFacetUseCase createTagFacetUseCase(Ref ref) {
  return CreateTagFacetUseCase(ref.read(tagFacetRepositoryProvider.future));
}

class CreateTagFacetUseCase {
  final Future<TagFacetRepository> _facetRepositoryFuture;

  CreateTagFacetUseCase(this._facetRepositoryFuture);

  Future<Result<TagFacet, AppError>> invoke(
    String name, {
    int? colorValue,
    int? sortOrder,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Result.failure(AppError.validation('Facet name cannot be empty'));
    }

    try {
      final repo = await _facetRepositoryFuture;
      final existingResult = await repo.getByName(trimmedName);
      if (existingResult is Success<TagFacet?, AppError> &&
          existingResult.data != null) {
        return Result.failure(AppError.validation('Facet already exists'));
      }
      final resolvedSortOrder = sortOrder ?? await _nextSortOrder(repo);
      final facet = TagFacet()
        ..name = trimmedName
        ..colorValue = colorValue
        ..sortOrder = resolvedSortOrder
        ..createdAt = DateTime.now();
      final saveResult = await repo.save(facet);
      if (saveResult is Failure<void, AppError>) {
        return Result.failure(saveResult.error);
      }
      return Result.success(facet);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('CreateFacet failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

@Riverpod(keepAlive: true)
UpdateTagFacetUseCase updateTagFacetUseCase(Ref ref) {
  return UpdateTagFacetUseCase(ref.read(tagFacetRepositoryProvider.future));
}

class UpdateTagFacetUseCase {
  final Future<TagFacetRepository> _facetRepositoryFuture;

  UpdateTagFacetUseCase(this._facetRepositoryFuture);

  Future<Result<void, AppError>> invoke(
    TagFacet facet, {
    required String name,
    int? colorValue,
    int? sortOrder,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Result.failure(AppError.validation('Facet name cannot be empty'));
    }

    try {
      final repo = await _facetRepositoryFuture;
      final existingResult = await repo.getByName(trimmedName);
      if (existingResult is Success<TagFacet?, AppError> &&
          existingResult.data != null &&
          existingResult.data!.id != facet.id) {
        return Result.failure(AppError.validation('Facet already exists'));
      }
      facet
        ..name = trimmedName
        ..colorValue = colorValue
        ..sortOrder = sortOrder ?? facet.sortOrder;
      final saveResult = await repo.save(facet);
      if (saveResult is Failure<void, AppError>) {
        return Result.failure(saveResult.error);
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('UpdateFacet failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

@Riverpod(keepAlive: true)
DeleteTagFacetUseCase deleteTagFacetUseCase(Ref ref) {
  return DeleteTagFacetUseCase(ref.read(tagFacetRepositoryProvider.future));
}

class DeleteTagFacetUseCase {
  final Future<TagFacetRepository> _facetRepositoryFuture;

  DeleteTagFacetUseCase(this._facetRepositoryFuture);

  Future<Result<void, AppError>> invoke(int id) async {
    try {
      final facetRepo = await _facetRepositoryFuture;
      final defaultFacet = await _ensureDefaultFacet(facetRepo);

      if (defaultFacet.id == id) {
        return Result.failure(
          AppError.validation('Default facet cannot be deleted'),
        );
      }

      return await facetRepo.deleteAndReassignTags(id, defaultFacet);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('DeleteFacet failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

// --- CreateTagUseCase ---
@Riverpod(keepAlive: true)
CreateTagUseCase createTagUseCase(Ref ref) {
  return CreateTagUseCase(
    ref.read(tagRepositoryProvider.future),
    ref.read(tagFacetRepositoryProvider.future),
  );
}

class CreateTagUseCase {
  final Future<TagRepository> _tagRepositoryFuture;
  final Future<TagFacetRepository> _facetRepositoryFuture;

  CreateTagUseCase(this._tagRepositoryFuture, this._facetRepositoryFuture);

  Future<Result<Tag, AppError>> invoke(
    String name, {
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool isHidden = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Result.failure(AppError.validation('Tag name cannot be empty'));
    }

    try {
      final repo = await _tagRepositoryFuture;
      final facetRepo = await _facetRepositoryFuture;
      final resolvedFacet =
          facetId ?? (await _ensureDefaultFacet(facetRepo)).id;
      int? resolvedParentLevel;

      if (parentId != null) {
        final parentResult = await repo.getById(parentId);
        if (parentResult is Failure<Tag?, AppError>) {
          return Result.failure(parentResult.error);
        }
        final parent = (parentResult as Success<Tag?, AppError>).data;
        if (parent == null) {
          return Result.failure(AppError.validation('Parent tag not found'));
        }
        if (parent.facetId != resolvedFacet) {
          return Result.failure(
            AppError.validation('Parent tag is in different facet'),
          );
        }
        resolvedParentLevel = parent.level;
      }

      final key = Tag.buildKey(resolvedFacet, trimmedName);
      final existingResult = await repo.getByKey(key);
      if (existingResult is Success<Tag?, AppError> &&
          existingResult.data != null) {
        return Result.failure(AppError.validation('Tag already exists'));
      }

      final resolvedLevel =
          level ??
          (resolvedParentLevel != null ? resolvedParentLevel + 1 : 100);
      final newTag = Tag()
        ..key = key
        ..name = trimmedName
        ..facetId = resolvedFacet
        ..parentId = parentId
        ..level = resolvedLevel
        ..ancestorIds = await _resolveAncestorIds(repo, parentId)
        ..colorValue = colorValue
        ..isHidden = isHidden
        ..createdAt = DateTime.now();
      final saveResult = await repo.save(newTag);
      if (saveResult is Failure<void, AppError>) {
        return Result.failure(saveResult.error);
      }

      return Result.success(newTag);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('CreateTag failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

// --- UpdateTagUseCase ---
@Riverpod(keepAlive: true)
UpdateTagUseCase updateTagUseCase(Ref ref) {
  return UpdateTagUseCase(
    ref.read(tagRepositoryProvider.future),
    ref.read(tagFacetRepositoryProvider.future),
  );
}

class UpdateTagUseCase {
  final Future<TagRepository> _tagRepositoryFuture;
  final Future<TagFacetRepository> _facetRepositoryFuture;

  UpdateTagUseCase(this._tagRepositoryFuture, this._facetRepositoryFuture);

  Future<Result<void, AppError>> invoke(
    Tag tag, {
    required String name,
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool? isHidden,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Result.failure(AppError.validation('Tag name cannot be empty'));
    }

    try {
      final repo = await _tagRepositoryFuture;
      final facetRepo = await _facetRepositoryFuture;
      final resolvedFacet =
          facetId ?? tag.facetId ?? (await _ensureDefaultFacet(facetRepo)).id;
      int? resolvedParentLevel;

      if (parentId != null && parentId == tag.id) {
        return Result.failure(AppError.validation('Tag cannot be its parent'));
      }

      if (parentId != null) {
        // 循環参照チェック（自身および子孫が親に指定されていないか）
        if (await _detectCycle(repo, tag.id, parentId)) {
          return Result.failure(
            AppError.validation('Circular parent-child relationship detected'),
          );
        }

        final parentResult = await repo.getById(parentId);
        if (parentResult is Failure<Tag?, AppError>) {
          return Result.failure(parentResult.error);
        }
        final parent = (parentResult as Success<Tag?, AppError>).data;
        if (parent == null) {
          return Result.failure(AppError.validation('Parent tag not found'));
        }
        if (parent.facetId != resolvedFacet) {
          return Result.failure(
            AppError.validation('Parent tag is in different facet'),
          );
        }
        resolvedParentLevel = parent.level;
      }

      final key = Tag.buildKey(resolvedFacet, trimmedName);
      final existingResult = await repo.getByKey(key);
      if (existingResult is Success<Tag?, AppError> &&
          existingResult.data != null &&
          existingResult.data!.id != tag.id) {
        return Result.failure(AppError.validation('Tag already exists'));
      }

      final parentChanged = tag.parentId != parentId;

      final resolvedLevel =
          level ??
          (parentId != null && parentChanged
              ? (resolvedParentLevel ?? tag.level + 1)
              : tag.level);
      tag
        ..key = key
        ..name = trimmedName
        ..facetId = resolvedFacet
        ..parentId = parentId
        ..level = resolvedLevel
        ..ancestorIds = await _resolveAncestorIds(repo, parentId)
        ..colorValue = colorValue;

      if (isHidden != null) {
        tag.isHidden = isHidden;
      }

      var descendants = <Tag>[];
      if (parentChanged) {
        descendants = await _recalculateDescendants(repo, tag);
      }
      return await repo.saveTree(tag, descendants);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('UpdateTag failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

// --- DeleteTagUseCase ---
@Riverpod(keepAlive: true)
DeleteTagUseCase deleteTagUseCase(Ref ref) {
  return DeleteTagUseCase(
    ref.read(tagRepositoryProvider.future),
    ref.read(tagFacetRepositoryProvider.future),
    ref.read(mediaRepositoryProvider.future),
  );
}

class DeleteTagUseCase {
  final Future<TagRepository> _tagRepositoryFuture;
  final Future<TagFacetRepository> _facetRepositoryFuture;
  final Future<MediaRepository> _mediaRepositoryFuture;

  DeleteTagUseCase(
    this._tagRepositoryFuture,
    this._facetRepositoryFuture,
    this._mediaRepositoryFuture,
  );

  Future<Result<void, AppError>> invoke(int id) async {
    try {
      final mediaRepo = await _mediaRepositoryFuture;
      final repo = await _tagRepositoryFuture;
      final facetRepo = await _facetRepositoryFuture;

      final childrenResult = await repo.getChildren(id);
      if (childrenResult is Success<List<Tag>, AppError> &&
          childrenResult.data.isNotEmpty) {
        return Result.failure(AppError.validation('Tag has child tags'));
      }
      final tagResult = await repo.getById(id);
      if (tagResult is Failure<Tag?, AppError>) {
        return Result.failure(tagResult.error);
      }
      final tag = (tagResult as Success<Tag?, AppError>).data;
      if (tag != null) {
        if (tag.facetId == null) {
          final defaultFacet = await _ensureDefaultFacet(facetRepo);
          tag.facetId = defaultFacet.id;
        }
        final itemsResult = await mediaRepo.getAll(
          filter: MediaFilter(tagIds: [id]),
        );
        if (itemsResult is Failure<List<MediaItem>, AppError>) {
          return Result.failure(itemsResult.error);
        }
        final items = (itemsResult as Success<List<MediaItem>, AppError>).data;
        final collections = <MediaCollection>{};
        for (final item in items) {
          await item.collection.load();
          if (item.collection.value != null) {
            collections.add(item.collection.value!);
          }
        }
        for (final collection in collections) {
          await collection.tags.load();
          if (collection.tags.contains(tag)) {
            collection.tags.remove(tag);
            final saveResult = await mediaRepo.saveCollection(collection);
            if (saveResult is Failure<void, AppError>) {
              return Result.failure(saveResult.error);
            }
          }
        }
      }
      return await repo.delete(id);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('DeleteTag failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

// --- ToggleTagUseCase ---
@Riverpod(keepAlive: true)
ToggleTagUseCase toggleTagUseCase(Ref ref) {
  return ToggleTagUseCase(ref.read(mediaRepositoryProvider.future));
}

class ToggleTagUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;

  ToggleTagUseCase(this._mediaRepositoryFuture);

  Future<Result<void, AppError>> invoke(MediaItem item, Tag tag) async {
    try {
      final repo = await _mediaRepositoryFuture;

      var collection = item.collection.value;
      if (collection == null) {
        try {
          await item.collection.load();
          collection = item.collection.value;
        } catch (_) {
          collection = item.collection.value;
        }
      }
      if (collection == null) {
        return Result.failure(
          AppError.validation('Item does not belong to a collection'),
        );
      }

      return await repo.toggleTagOnCollection(collection, tag);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('ToggleTag failed: $e', original: e, stackTrace: st),
      );
    }
  }
}

// --- SyncCollectionTagsUseCase ---
@Riverpod(keepAlive: true)
SyncCollectionTagsUseCase syncCollectionTagsUseCase(
  Ref ref,
) {
  return SyncCollectionTagsUseCase(ref.read(mediaRepositoryProvider.future));
}

class SyncCollectionTagsUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;

  SyncCollectionTagsUseCase(this._mediaRepositoryFuture);

  Future<Result<void, AppError>> invoke(
    MediaItem item,
    List<Tag> targetTags,
  ) async {
    try {
      final repo = await _mediaRepositoryFuture;

      var collection = item.collection.value;
      if (collection == null) {
        try {
          await item.collection.load();
          collection = item.collection.value;
        } catch (_) {
          collection = item.collection.value;
        }
      }
      if (collection == null) {
        return Result.failure(
          AppError.validation('Item does not belong to a collection'),
        );
      }

      return await repo.syncTagsOnCollection(collection, targetTags);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'SyncCollectionTags failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}

Future<TagFacet> _ensureDefaultFacet(TagFacetRepository repo) async {
  const defaultName = '未分類';
  final existing = await repo.getByName(defaultName);
  if (existing is Success<TagFacet?, AppError> && existing.data != null) {
    return existing.data!;
  }
  final facet = TagFacet()
    ..name = defaultName
    ..createdAt = DateTime.now();
  final saveResult = await repo.save(facet);
  if (saveResult is Failure<void, AppError>) {
    throw saveResult.error;
  }
  return facet;
}

/// 循環参照の検出（targetTagId が candidateParentId の先祖に存在するか）
Future<bool> _detectCycle(
  TagRepository repo,
  int targetTagId,
  int candidateParentId,
) async {
  var currentId = candidateParentId as int?;
  final visited = <int>{};
  while (currentId != null) {
    if (currentId == targetTagId) return true;
    if (visited.contains(currentId)) return true;
    visited.add(currentId);
    final parentResult = await repo.getById(currentId);
    if (parentResult is! Success<Tag?, AppError> || parentResult.data == null) {
      break;
    }
    currentId = parentResult.data!.parentId;
  }
  return false;
}

Future<List<int>> _resolveAncestorIds(TagRepository repo, int? parentId) async {
  final ancestors = <int>[];
  final visited = <int>{};
  var currentId = parentId;
  while (currentId != null) {
    if (visited.contains(currentId)) {
      break;
    }
    visited.add(currentId);
    final parentResult = await repo.getById(currentId);
    if (parentResult is Failure<Tag?, AppError>) {
      break;
    }
    final parent = (parentResult as Success<Tag?, AppError>).data;
    if (parent == null) {
      break;
    }
    ancestors.add(parent.id);
    currentId = parent.parentId;
  }
  return ancestors;
}

Future<int> _nextSortOrder(TagFacetRepository repo) async {
  final existing = await repo.getAll();
  if (existing is Failure<List<TagFacet>, AppError>) {
    throw existing.error;
  }
  final facets = (existing as Success<List<TagFacet>, AppError>).data;
  if (facets.isEmpty) return 0;
  final maxOrder = facets
      .map((facet) => facet.sortOrder)
      .reduce((a, b) => a > b ? a : b);
  return maxOrder + 1;
}

Future<List<Tag>> _recalculateDescendants(
  TagRepository repo,
  Tag parentTag,
) async {
  final updatedDescendants = <Tag>[];
  final childrenResult = await repo.getChildren(parentTag.id);
  if (childrenResult is! Success<List<Tag>, AppError>) {
    return updatedDescendants;
  }
  final children = childrenResult.data;
  for (final child in children) {
    child.ancestorIds = [parentTag.id, ...parentTag.ancestorIds];
    child.level = parentTag.level + 1;
    updatedDescendants.add(child);
    final subDescendants = await _recalculateDescendants(repo, child);
    updatedDescendants.addAll(subDescendants);
  }
  return updatedDescendants;
}
