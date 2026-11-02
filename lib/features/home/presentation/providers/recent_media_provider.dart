import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/application/use_cases/get_recent_media_use_case.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';

part 'recent_media_provider.g.dart';

@riverpod
Stream<List<MediaItem>> recentMedia(Ref ref) async* {
  final mode = ref.watch(appModeProvider);
  final sourceType = switch (mode) {
    AppMode.internal => MediaSourceType.localCopy,
    AppMode.external => MediaSourceType.externalReference,
  };

  try {
    final useCase = await ref.watch(getRecentMediaUseCaseProvider.future);
    final showHidden = ref.watch(secretModeProvider).value ?? false;

    yield* useCase.watch(
      limit: 10,
      sourceType: sourceType,
      includeHidden: showHidden,
    );
  } catch (error, stack) {
    if (error is AppError) {
      final enriched = error
          .withContext('recentMediaProvider.watch')
          .withAdditionalData({'mode': mode.name});
      AppLogger.w(LogTag.provider, '最近メディア取得失敗: mode=${mode.name}', enriched);
      throw enriched;
    }

    final appError = AppError.unknown(
      '最近メディアの取得で予期せぬエラーが発生しました',
      severity: ErrorSeverity.warning,
      original: error,
      stackTrace: stack,
      context: 'recentMediaProvider.catch',
    ).withAdditionalData({'mode': mode.name});
    AppLogger.e(LogTag.provider, '最近メディア取得で例外発生', error, stack);
    throw appError;
  }
}
