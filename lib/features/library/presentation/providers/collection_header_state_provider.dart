import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';

part 'collection_header_state_provider.g.dart';

@riverpod
class CollectionHeaderExpanded extends _$CollectionHeaderExpanded {
  @override
  FutureOr<bool> build(int collectionId) async {
    final repository = await ref.watch(mediaRepositoryProvider.future);
    final result = await repository.getCollectionById(collectionId);
    return result.when(
      success: (collection) => collection?.isHeaderExpanded ?? true,
      failure: (_) => true,
    );
  }

  Future<void> toggle() async {
    final currentState = state.value ?? true;
    final newState = !currentState;

    // UI側のラグを防ぐため、即座にデータを更新
    state = AsyncValue.data(newState);

    final repository = await ref.read(mediaRepositoryProvider.future);
    final result = await repository.updateCollectionHeaderExpanded(
      collectionId,
      newState,
    );

    result.when(
      success: (_) {
        // 成功時は何もしない（すでにデータは更新済み）
      },
      failure: (error) {
        // 失敗時は元の状態に戻す
        state = AsyncValue.data(currentState);
      },
    );
  }
}
