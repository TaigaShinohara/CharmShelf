// Application layer: coordinates domain contracts with repository providers.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';

part 'get_recently_viewed_collections_use_case.g.dart';

class GetRecentlyViewedCollectionsUseCase {
  final MediaRepository _repository;

  GetRecentlyViewedCollectionsUseCase(this._repository);

  Stream<List<MediaCollection>> watch({
    int limit = 8,
    bool isExternal = false,
    bool includeHidden = false,
  }) {
    return _repository.watchRecentlyViewedCollections(
      limit: limit,
      isExternal: isExternal,
      isHidden: includeHidden ? null : false,
    );
  }
}

@riverpod
Future<GetRecentlyViewedCollectionsUseCase> getRecentlyViewedCollectionsUseCase(
  Ref ref,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  return GetRecentlyViewedCollectionsUseCase(repository);
}
