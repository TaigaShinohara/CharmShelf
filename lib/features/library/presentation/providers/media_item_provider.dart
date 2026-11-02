import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

part 'media_item_provider.g.dart';

@riverpod
Future<MediaItem?> mediaItem(Ref ref, int id) async {
  final repo = await ref.watch(mediaRepositoryProvider.future);
  final result = await repo.getById(id);
  return result.when(
    success: (item) async {
      if (item != null) {
        await item.collection.load();
        await item.collection.value?.tags.load();
      }
      return item;
    },
    failure: (_) => null,
  );
}
