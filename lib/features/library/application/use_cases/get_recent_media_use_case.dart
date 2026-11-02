// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';

part 'get_recent_media_use_case.g.dart';

class GetRecentMediaUseCase {
  final MediaRepository _repository;

  GetRecentMediaUseCase(this._repository);

  Future<Result<List<MediaItem>, AppError>> invoke({
    int limit = 10,
    MediaSourceType? sourceType,
    bool includeHidden = false,
  }) async {
    return _repository.getRecentMedia(
      limit: limit,
      sourceType: sourceType,
      isHidden: includeHidden ? null : false,
    );
  }

  Stream<List<MediaItem>> watch({
    int limit = 10,
    MediaSourceType? sourceType,
    bool includeHidden = false,
  }) {
    return _repository.watchRecentMedia(
      limit: limit,
      sourceType: sourceType,
      isHidden: includeHidden ? null : false,
    );
  }
}

@riverpod
Future<GetRecentMediaUseCase> getRecentMediaUseCase(
  Ref ref,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  return GetRecentMediaUseCase(repository);
}
