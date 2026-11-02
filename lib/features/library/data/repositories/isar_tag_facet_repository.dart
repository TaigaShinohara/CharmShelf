import 'package:isar/isar.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_facet_repository.dart';

class IsarTagFacetRepository implements TagFacetRepository {
  final Isar _isar;

  IsarTagFacetRepository(this._isar);

  @override
  Future<Result<void, AppError>> save(TagFacet facet) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.tagFacets.put(facet);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Save failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> saveAll(List<TagFacet> facets) async {
    try {
      if (facets.isEmpty) return Result.success(null);
      await _isar.writeTxn(() async {
        await _isar.tagFacets.putAll(facets);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('SaveAll failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<TagFacet?, AppError>> getById(int id) async {
    try {
      final facet = await _isar.tagFacets.get(id);
      return Result.success(facet);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetById failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<TagFacet?, AppError>> getByName(String name) async {
    try {
      final facet = await _isar.tagFacets
          .filter()
          .nameEqualTo(name)
          .findFirst();
      return Result.success(facet);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetByName failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<TagFacet>, AppError>> getAll() async {
    try {
      final facets = await _isar.tagFacets.where().sortBySortOrder().findAll();
      return Result.success(facets);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetAll failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Stream<List<TagFacet>> watchFacets() {
    return _isar.tagFacets.where().sortBySortOrder().watch(
      fireImmediately: true,
    );
  }

  @override
  Future<Result<void, AppError>> delete(int id) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.tagFacets.delete(id);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Delete failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> deleteAndReassignTags(
    int id,
    TagFacet replacement,
  ) async {
    try {
      await _isar.writeTxn(() async {
        final tags = await _isar.tags.filter().facetIdEqualTo(id).findAll();
        for (final tag in tags) {
          tag
            ..facetId = replacement.id
            ..key = Tag.buildKey(replacement.id, tag.name);
        }
        if (tags.isNotEmpty) {
          await _isar.tags.putAll(tags);
        }
        await _isar.tagFacets.delete(id);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database(
          'DeleteAndReassignTags failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}
