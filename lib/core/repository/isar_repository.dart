import 'package:isar/isar.dart';

import '../error/app_error.dart';
import '../error/result.dart';
import 'base_repository.dart';

abstract class IsarRepository<T> implements BaseRepository<T> {
  final Isar isar;
  IsarCollection<T> get collection;

  IsarRepository(this.isar);

  @override
  Future<Result<T, AppError>> getById(int id) async {
    try {
      final item = await collection.get(id);
      if (item == null) {
        return Result.failure(
          AppError.database('Not found', severity: ErrorSeverity.info),
        );
      }
      return Result.success(item);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Failed to load', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<T>, AppError>> getAll() async {
    try {
      final list = await collection.where().findAll();
      return Result.success(list);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Failed to load list', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<T, AppError>> save(T entity) async {
    try {
      await isar.writeTxn(() async {
        await collection.put(entity);
      });
      return Result.success(entity);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Failed to save', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void, AppError>> delete(int id) async {
    try {
      await isar.writeTxn(() async {
        await collection.delete(id);
      });
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.database('Failed to delete', original: e, stackTrace: st),
      );
    }
  }
}
