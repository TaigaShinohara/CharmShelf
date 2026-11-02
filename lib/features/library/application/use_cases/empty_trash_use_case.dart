// Application layer: coordinates domain contracts with repository providers.
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/permanently_delete_trashed_media_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'empty_trash_use_case.g.dart';

@Riverpod(keepAlive: true)
EmptyTrashUseCase emptyTrashUseCase(Ref ref) {
  return EmptyTrashUseCase(
    ref.read(mediaRepositoryProvider.future),
    ref.read(permanentlyDeleteTrashedMediaUseCaseProvider),
  );
}

class EmptyTrashUseCase {
  EmptyTrashUseCase(this._repositoryFuture, this._delete);

  final Future<MediaRepository> _repositoryFuture;
  final PermanentlyDeleteTrashedMediaUseCase _delete;

  /// Deletes roots sequentially so a failure leaves the failed and remaining
  /// entries recoverable. Already deleted entries are reported to the caller.
  Future<Result<int, AppError>> invoke() async {
    try {
      return await _invoke();
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to empty Trash',
          original: e,
          stackTrace: st,
          context: 'EmptyTrashUseCase.invoke',
        ),
      );
    }
  }

  Future<Result<int, AppError>> _invoke() async {
    final repository = await _repositoryFuture;
    final rootsResult = await repository.getTrashedRoots();
    if (rootsResult.isFailure) {
      return Result.failure(rootsResult.errorOrNull!);
    }
    final roots = rootsResult.dataOrNull ?? const [];
    var deleted = 0;
    for (final root in roots) {
      final result = await _delete.invoke(root);
      if (result.isFailure) {
        return Result.failure(
          result.errorOrNull!.withAdditionalData({
            'deletedCount': deleted,
            'totalCount': roots.length,
            'failedItems': [
              {
                'path': root.path,
                'displayName': p.basename(root.path),
                'type': root.type.name,
              },
            ],
          }),
        );
      }
      deleted++;
    }
    return Result.success(deleted);
  }
}
