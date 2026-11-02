import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../library/data/repositories/media_repository_provider.dart';
import '../../../library/domain/models/media_filter.dart';
import '../../../library/domain/models/media_item.dart';
import '../../../settings/presentation/providers/app_mode_provider.dart';

part 'home_library_items_provider.g.dart';

@riverpod
Stream<List<MediaItem>> homeLibraryItems(Ref ref) async* {
  final mode = ref.watch(appModeProvider);
  final repository = await ref.watch(mediaRepositoryProvider.future);
  final sourceType = switch (mode) {
    AppMode.internal => MediaSourceType.localCopy,
    AppMode.external => MediaSourceType.externalReference,
  };
  yield* repository.watchAll(
    filter: MediaFilter(sourceType: sourceType, isArchived: false, limit: 1),
  );
}
