import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/application/use_cases/remove_external_folder_reference_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';

part 'external_library_provider.g.dart';

/// 外部参照フォルダ一覧の状態管理プロバイダー。
@riverpod
class ExternalFolderList extends _$ExternalFolderList {
  @override
  FutureOr<List<MediaCollection>> build() async {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.external));
    final repo = await ref.watch(mediaRepositoryProvider.future);

    final result = await repo.getExternalCollections(filter: filter);
    return result.when(
      success: (collections) =>
          collections.where((c) => _isExternalPath(c.path)).toList(),
      failure: (_) => [],
    );
  }

  /// Compatibility API: no new external references can be registered.
  Future<void> addFiles() async =>
      throw UnsupportedError('External references retired');
  Future<void> addFolder() async =>
      throw UnsupportedError('External references retired');

  Future<RemoveExternalFolderReferenceOutcome> removeFolder(
    MediaCollection folder,
  ) async {
    final storageService = await ref.read(
      externalStorageServiceProvider.future,
    );
    final repo = await ref.read(mediaRepositoryProvider.future);
    final useCase = RemoveExternalFolderReferenceUseCase(
      repo,
      ref.read(operationJournalServiceProvider),
      storageService.releasePersistedAccess,
    );
    final result = await useCase.invoke(folder);
    if (result.isFailure) throw result.errorOrNull!;

    AppLogger.d(LogTag.storage, '外部フォルダ登録解除: ${folder.title}');
    ref.invalidateSelf();
    ref.invalidate(collectionNotifierProvider(folder.path));
    ref.invalidate(externalFolderItemsProvider(folder.path));
    ref.invalidate(externalRootItemsProvider);

    return result.dataOrNull!;
  }

  Future<({int added, int missing})?> syncFolder(
    MediaCollection folder,
  ) async =>
      throw UnsupportedError('External reference synchronization retired');
}

/// 特定の外部参照フォルダ内のファイル一覧プロバイダー。
@riverpod
class ExternalFolderItems extends _$ExternalFolderItems {
  @override
  FutureOr<List<MediaItem>> build(String? folderPath) async {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.external));
    final repo = await ref.watch(mediaRepositoryProvider.future);

    final effectiveFilter = filter.copyWith(
      parentPath: folderPath ?? filter.parentPath,
      rootOnly: folderPath == null,
    );

    final result = await repo.getAll(filter: effectiveFilter);
    return result.when(
      success: (items) async {
        final filtered = items
            .where(
              (item) =>
                  item.sourceType == MediaSourceType.externalReference &&
                  _isExternalPath(item.path),
            )
            .toList();
        // コレクション情報をロードする（_updateLastViewedAtで必要）
        for (final item in filtered) {
          await item.collection.load();
        }
        return filtered;
      },
      failure: (_) => [],
    );
  }
}

/// 外部参照のルート階層にある個別ファイル一覧プロバイダー。
@riverpod
class ExternalRootItems extends _$ExternalRootItems {
  @override
  FutureOr<List<MediaItem>> build() async {
    final filter = ref.watch(mediaFilterNotifierProvider(AppMode.external));
    final repo = await ref.watch(mediaRepositoryProvider.future);

    final hasSearchQuery = filter.searchQuery?.trim().isNotEmpty ?? false;
    final searchTarget = filter.effectiveSearchTarget;
    if (hasSearchQuery && searchTarget == SearchTarget.catalogsOnly) {
      return <MediaItem>[];
    }

    final result = await repo.getAll(filter: filter.copyWith(rootOnly: true));
    final items = result.when(
      success: (items) => items,
      failure: (_) => <MediaItem>[],
    );

    final filtered = <MediaItem>[];
    for (final item in items) {
      if (item.sourceType != MediaSourceType.externalReference ||
          !_isExternalPath(item.path)) {
        continue;
      }
      await item.collection.load();
      if (hasSearchQuery || item.collection.value == null) {
        filtered.add(item);
      }
    }
    return filtered;
  }

  /// ルート階層の個別ファイル群を同期する。
  Future<void> sync() async =>
      throw UnsupportedError('External reference synchronization retired');
}

bool _isExternalPath(String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'file') return true;
    return p.isAbsolute(uri.toFilePath());
  }
  return p.isAbsolute(rawPath);
}
