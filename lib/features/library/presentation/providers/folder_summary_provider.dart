export 'package:private_shelf/features/library/domain/models/folder_summary.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/folder_summary.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';

part 'folder_summary_provider.g.dart';

/// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー
@riverpod
Future<FolderSummary> folderSummary(
  Ref ref,
  String folderPath,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  final isSecretMode = ref.watch(secretModeProvider).value ?? false;

  final result = await repository.getFolderSummary(
    folderPath,
    isHidden: isSecretMode ? null : false,
  );
  return result.when(
    success: (summary) => summary,
    failure: (_) => const FolderSummary(),
  );
}

/// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）
@riverpod
Future<List<MediaItem>> siblingFolders(
  Ref ref,
  String? parentPath,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  final isSecretMode = ref.watch(secretModeProvider).value ?? false;

  final filter = MediaFilter(
    parentPath: parentPath,
    isHidden: isSecretMode ? null : false,
  );

  final result = await repository.getAll(filter: filter);
  return result.when(
    success: (items) =>
        items.where((i) => !i.isTrashed && i.type == MediaType.folder).toList(),
    failure: (_) => [],
  );
}
