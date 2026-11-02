import '../error/app_error.dart';
import '../error/result.dart';

abstract class BaseRepository<T> {
  Future<Result<T, AppError>> getById(int id);
  Future<Result<List<T>, AppError>> getAll();
  Future<Result<T, AppError>> save(T entity);
  Future<Result<void, AppError>> delete(int id);
}
