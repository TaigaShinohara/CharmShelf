import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/application/use_cases/get_favorite_collections_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:path/path.dart' as p;

part 'favorite_collections_provider.g.dart';

@riverpod
Stream<List<MediaCollection>> favoriteCollections(
  Ref ref,
) async* {
  final mode = ref.watch(appModeProvider);
  try {
    final repository = await ref.watch(mediaRepositoryProvider.future);
    if (!ref.mounted) return;
    final useCase = await ref.watch(
      getFavoriteCollectionsUseCaseProvider.future,
    );
    if (!ref.mounted) return;
    final collectionStream = useCase.watch();
    final itemStream = repository.watchAll(
      filter: MediaFilter(
        sourceType: mode == AppMode.external
            ? MediaSourceType.externalReference
            : MediaSourceType.localCopy,
        isArchived: false,
        isHidden: false,
        isFavorite: true,
      ),
    );

    final controller = StreamController<List<MediaCollection>>();
    var collections = <MediaCollection>[];
    var items = <MediaItem>[];

    void emit() {
      final entries = <MediaCollection>[...collections];
      final catalogPaths = collections
          .map((collection) => collection.path)
          .toSet();
      for (final item in items.where(
        (item) => item.isFavorite && !catalogPaths.contains(item.path),
      )) {
        final entry = MediaCollection()
          ..path = item.path
          ..title = p.basename(item.path)
          ..type = item.sourceType == MediaSourceType.externalReference
              ? CollectionType.externalFolder
              : (item.type == MediaType.folder
                    ? CollectionType.folder
                    : CollectionType.file)
          ..coverImagePath =
              item.thumbnailPath ?? (item.isImage ? item.path : null)
          ..isFavorite = true
          ..favoriteItem = item;
        entries.add(entry);
      }
      controller.add(entries);
    }

    final collectionSubscription = collectionStream.listen((value) {
      collections = mode == AppMode.external
          ? value.where((c) => c.isExternal).toList()
          : value.where((c) => !c.isExternal).toList();
      emit();
    }, onError: controller.addError);
    final itemSubscription = itemStream.listen((value) {
      items = value;
      emit();
    }, onError: controller.addError);
    ref.onDispose(() async {
      await collectionSubscription.cancel();
      await itemSubscription.cancel();
      await controller.close();
    });

    yield* controller.stream;
  } catch (error, stack) {
    if (error is AppError) rethrow;

    final appError = AppError.unknown(
      'お気に入りコレクションの取得で予期せぬエラーが発生しました',
      severity: ErrorSeverity.warning,
      original: error,
      stackTrace: stack,
      context: 'favoriteCollectionsProvider.catch',
    ).withAdditionalData({'mode': mode.name});
    AppLogger.e(LogTag.provider, 'お気に入りコレクション取得で例外発生', error, stack);
    throw appError;
  }
}
