import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/application/use_cases/get_recently_viewed_collections_use_case.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';

part 'recently_viewed_collections_provider.g.dart';

@riverpod
Stream<List<MediaCollection>> recentlyViewedCollections(
  Ref ref,
) async* {
  yield* _watchCollections(ref, 5);
}

final recentCollectionsHistoryProvider =
    StreamProvider.autoDispose<List<MediaCollection>>(
      (ref) => _watchCollections(ref, 20),
    );

Stream<List<MediaCollection>> _watchCollections(Ref ref, int limit) async* {
  final mode = ref.watch(appModeProvider);
  final showHidden = ref.watch(secretModeProvider).value ?? false;
  final isExternal = mode == AppMode.external;

  try {
    final useCase = await ref.watch(
      getRecentlyViewedCollectionsUseCaseProvider.future,
    );

    yield* useCase.watch(
      limit: limit,
      isExternal: isExternal,
      includeHidden: showHidden,
    );
  } catch (error, stack) {
    if (error is AppError) {
      final enriched = error
          .withContext('recentlyViewedCollectionsProvider.watch')
          .withAdditionalData({'mode': mode.name});
      AppLogger.w(
        LogTag.provider,
        '最近閲覧コレクション取得失敗: mode=${mode.name}',
        enriched,
      );
      throw enriched;
    }

    final appError = AppError.unknown(
      '最近閲覧コレクションの取得で予期せぬエラーが発生しました',
      severity: ErrorSeverity.warning,
      original: error,
      stackTrace: stack,
      context: 'recentlyViewedCollectionsProvider.catch',
    ).withAdditionalData({'mode': mode.name});
    AppLogger.e(LogTag.provider, '最近閲覧コレクション取得で例外発生', error, stack);
    throw appError;
  }
}
