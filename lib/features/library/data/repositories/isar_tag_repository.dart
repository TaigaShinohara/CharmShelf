import 'package:isar/isar.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';

class IsarTagRepository implements TagRepository {
  final Isar _isar;

  IsarTagRepository(this._isar);

  @override
  Future<Result<void, AppError>> save(Tag tag) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.tags.put(tag);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Save failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> saveAll(List<Tag> tags) async {
    try {
      if (tags.isEmpty) return Result.success(null);
      await _isar.writeTxn(() async {
        await _isar.tags.putAll(tags);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('SaveAll failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> saveTree(
    Tag tag,
    List<Tag> descendants,
  ) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.tags.put(tag);
        if (descendants.isNotEmpty) {
          await _isar.tags.putAll(descendants);
        }
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('SaveTree failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Tag?, AppError>> getById(int id) async {
    try {
      final tag = await _isar.tags.get(id);
      return Result.success(tag);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetById failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Tag?, AppError>> getByKey(String key) async {
    try {
      final tag = await _isar.tags.filter().keyEqualTo(key).findFirst();
      return Result.success(tag);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetByKey failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Tag>, AppError>> getAll() async {
    try {
      final tags = await _isar.tags.where().sortByUsageCountDesc().findAll();
      return Result.success(tags);
    } catch (e, st) {
      return Result.failure(
        AppError.database('GetAll failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Stream<List<Tag>> watchTags() {
    return _isar.tags.where().sortByUsageCountDesc().watch(
      fireImmediately: true,
    );
  }

  @override
  Future<Result<List<Tag>, AppError>> getByFacetId(int facetId) async {
    try {
      final tags = await _isar.tags
          .filter()
          .facetIdEqualTo(facetId)
          .sortByName()
          .findAll();
      return Result.success(tags);
    } catch (e, st) {
      return Result.failure(
        AppError.database(
          'GetByFacetId failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<Tag>, AppError>> getByFacetAndLevel(
    int facetId,
    int level,
  ) async {
    try {
      final tags = await _isar.tags
          .filter()
          .facetIdEqualTo(facetId)
          .levelEqualTo(level)
          .sortByName()
          .findAll();
      return Result.success(tags);
    } catch (e, st) {
      return Result.failure(
        AppError.database(
          'GetByFacetAndLevel failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<Tag>, AppError>> getChildren(int parentId) async {
    try {
      final tags = await _isar.tags
          .filter()
          .parentIdEqualTo(parentId)
          .sortByName()
          .findAll();
      return Result.success(tags);
    } catch (e, st) {
      return Result.failure(
        AppError.database(
          'GetChildren failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void, AppError>> delete(int id) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.tags.delete(id);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Delete failed: $e', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> recalculateUsageCounts() async {
    try {
      await _isar.writeTxn(() async {
        final allTags = await _isar.tags.where().findAll();
        final allCollections = await _isar.mediaCollections.where().findAll();

        final usageMap = <int, int>{};
        for (final col in allCollections) {
          await col.tags.load();
          for (final tag in col.tags) {
            usageMap[tag.id] = (usageMap[tag.id] ?? 0) + 1;
          }
        }

        final updatedTags = <Tag>[];
        for (final tag in allTags) {
          final newCount = usageMap[tag.id] ?? 0;
          if (tag.usageCount != newCount) {
            tag.usageCount = newCount;
            updatedTags.add(tag);
          }
        }

        if (updatedTags.isNotEmpty) {
          await _isar.tags.putAll(updatedTags);
        }
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database(
          'RecalculateUsageCounts failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}
