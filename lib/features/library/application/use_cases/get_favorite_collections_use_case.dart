// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';

part 'get_favorite_collections_use_case.g.dart';

class GetFavoriteCollectionsUseCase {
  final MediaRepository _repository;

  GetFavoriteCollectionsUseCase(this._repository);

  Future<Result<List<MediaCollection>, AppError>> invoke({
    CollectionType? type,
  }) async {
    return _repository.getFavoriteCollections(type: type);
  }

  Stream<List<MediaCollection>> watch({CollectionType? type}) {
    return _repository.watchFavoriteCollections(type: type);
  }
}

@riverpod
Future<GetFavoriteCollectionsUseCase> getFavoriteCollectionsUseCase(
  Ref ref,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  return GetFavoriteCollectionsUseCase(repository);
}
