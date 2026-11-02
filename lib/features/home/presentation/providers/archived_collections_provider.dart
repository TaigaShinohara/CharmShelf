import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

part 'archived_collections_provider.g.dart';

@riverpod
Future<List<MediaCollection>> archivedCollections(
  Ref ref,
) async {
  final mode = ref.watch(appModeProvider);
  try {
    final repository = await ref.watch(mediaRepositoryProvider.future);

    final type = mode == AppMode.external
        ? CollectionType.externalFolder
        : null;

    final result = await repository.getArchivedCollections(type: type);

    final collections = result.when(
      success: (collections) {
        if (mode == AppMode.internal) {
          return collections
              .where((c) => c.type != CollectionType.externalFolder)
              .toList();
        }
        return collections;
      },
      failure: (error) {
        final enriched = error
            .withContext('archivedCollectionsProvider.invoke')
            .withAdditionalData({'mode': mode.name});
        AppLogger.w(
          LogTag.provider,
          'アーカイブコレクション取得失敗: mode=${mode.name}',
          enriched,
        );
        throw enriched;
      },
    );
    return collections;
  } catch (error, stack) {
    if (error is AppError) rethrow;

    final appError = AppError.unknown(
      'アーカイブコレクションの取得で予期せぬエラーが発生しました',
      severity: ErrorSeverity.warning,
      original: error,
      stackTrace: stack,
      context: 'archivedCollectionsProvider.catch',
    ).withAdditionalData({'mode': mode.name});
    AppLogger.e(LogTag.provider, 'アーカイブコレクション取得で例外発生', error, stack);
    throw appError;
  }
}
