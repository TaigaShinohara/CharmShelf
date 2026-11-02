// Application layer: coordinates domain contracts with persistence services.
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/data/services/sidecar_metadata_service.dart';

part 'detect_restorable_data_use_case.g.dart';

@Riverpod(keepAlive: true)
Future<DetectRestorableDataUseCase> detectRestorableDataUseCase(
  Ref ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  final storageManager = ref.watch(localStorageManagerProvider);
  return DetectRestorableDataUseCase(isar, storageManager);
}

/// 端末内に復元可能な CharmShelf データが存在するかを判定するユースケース。
class DetectRestorableDataUseCase {
  final Isar _isar;
  final LocalStorageManager _storageManager;

  DetectRestorableDataUseCase(this._isar, this._storageManager);

  /// 復元可能なデータの概要を検出して返します。
  ///
  /// DB に既にユーザー独自データ（ウェルカム以外のコレクションやメディア、カスタムタグ）が存在する場合は
  /// 復元対象なし（empty）として返します。
  Future<Result<RestorableDataSummary, AppError>> call() async {
    try {
      // 1. 現在のDB状態をチェック（既にデータが存在する場合は復元プロンプトを表示しない）
      final userItemCount = await _isar.mediaItems.count();
      final collectionCountInDb = await _isar.mediaCollections
          .filter()
          .pathIsNotEmpty()
          .and()
          .not()
          .pathEqualTo('library')
          .and()
          .not()
          .pathEqualTo('library/はじめてのCharmShelf')
          .and()
          .not()
          .pathEqualTo('library/Getting Started with CharmShelf')
          .and()
          .not()
          .pathEqualTo('library/Welcome_DocBook')
          .count();

      // すでにユーザー自身が追加したコレクションやアイテムが存在する場合は復元不要
      if (userItemCount > 5 || collectionCountInDb > 0) {
        return Result.success(RestorableDataSummary.empty);
      }

      final rootDir = await _storageManager.getRootDirectory();
      if (!await rootDir.exists()) {
        return Result.success(RestorableDataSummary.empty);
      }

      final metaFile = await _storageManager.getMetadataFile();
      final bakFile = File('${metaFile.path}.bak');
      final legacyMetaFile = await _storageManager.getLegacyMetadataFile();
      final candidateList = <File>[metaFile, bakFile];
      if (legacyMetaFile != null) {
        candidateList.addAll([
          legacyMetaFile,
          File('${legacyMetaFile.path}.bak'),
        ]);
      }
      final metadataCandidates = <String, File>{
        for (final candidate in candidateList) candidate.path: candidate,
      }.values;

      var hasMeta = false;
      var tagCount = 0;
      var metaColCount = 0;
      var metaItemCount = 0;
      DateTime? exportedAt;

      // 2. 私有領域と旧公開領域の全メタデータ候補を確認する。
      // 空の私有メタデータが旧公開サイドカーの実データを隠さないよう、
      // 有効な候補の最大件数と最新日時を集約する。
      for (final candidate in metadataCandidates) {
        if (!await candidate.exists()) continue;
        try {
          final decoded = await SidecarMetadataService.readValidatedDocument(
            candidate,
          );
          if (decoded != null) {
            hasMeta = true;
            final rawTags = decoded['tags'] as List<dynamic>? ?? [];
            final rawCols = decoded['collections'] as List<dynamic>? ?? [];
            final rawItems = decoded['mediaItems'] as List<dynamic>? ?? [];

            final candidateTagCount = rawTags.length;
            final candidateColCount = rawCols.where((c) {
              if (c is! Map<String, dynamic>) return false;
              final relPath = c['relativePath'] as String? ?? '';
              return _isManagedPath(relPath) &&
                  relPath != 'library' &&
                  !relPath.endsWith('はじめてのCharmShelf') &&
                  !relPath.endsWith('Getting Started with CharmShelf') &&
                  !relPath.endsWith('Welcome_DocBook');
            }).length;
            final candidateItemCount = rawItems.where((item) {
              if (item is! Map<String, dynamic>) return false;
              return _isManagedPath(item['relativePath'] as String? ?? '');
            }).length;

            if (candidateTagCount > tagCount) tagCount = candidateTagCount;
            if (candidateColCount > metaColCount) {
              metaColCount = candidateColCount;
            }
            if (candidateItemCount > metaItemCount) {
              metaItemCount = candidateItemCount;
            }

            final exportedAtStr = decoded['exportedAt'] as String?;
            if (exportedAtStr != null) {
              final candidateExportedAt = DateTime.tryParse(exportedAtStr);
              if (candidateExportedAt != null &&
                  (exportedAt == null ||
                      candidateExportedAt.isAfter(exportedAt))) {
                exportedAt = candidateExportedAt;
              }
            }
          }
        } catch (e) {
          AppLogger.w(
            LogTag.storage,
            'メタデータファイルの検査中に警告 (${candidate.path}): $e',
          );
        }
      }

      // 3. フォルダ内の実体ファイル・フォルダを走査
      var diskFileCount = 0;
      var diskDirCount = 0;

      try {
        final managedRoots = [
          Directory(p.join(rootDir.path, 'library')),
          Directory(p.join(rootDir.path, 'folders')),
        ];
        for (final managedRoot in managedRoots) {
          if (!await managedRoot.exists()) continue;
          await for (final entity in managedRoot.list(
            recursive: true,
            followLinks: false,
          )) {
            final relPath = p.relative(entity.path, from: rootDir.path);
            final parts = p.split(relPath);

            // 隠しフォルダ（.tagshelf, .thumbnails など）やウェルカムフォルダは除外
            if (parts.any(MediaFormatUtils.isIgnoredDirectory)) {
              continue;
            }
            if (relPath.startsWith('library/はじめてのCharmShelf') ||
                relPath.startsWith('library/Getting Started with CharmShelf') ||
                relPath.startsWith('library/Welcome_DocBook')) {
              continue;
            }

            if (entity is File) {
              final fileName = p.basename(entity.path);
              if (MediaFormatUtils.isIgnoredFile(fileName)) continue;

              final ext = p.extension(entity.path).toLowerCase();
              if (MediaFormatUtils.allSupportedExtensions.contains(ext)) {
                diskFileCount++;
              }
            } else if (entity is Directory) {
              final dirName = p.basename(entity.path);
              if (!MediaFormatUtils.isIgnoredDirectory(dirName) &&
                  relPath != 'library' &&
                  relPath != '.' &&
                  relPath.isNotEmpty) {
                diskDirCount++;
              }
            }
          }
        }
      } catch (e) {
        AppLogger.w(LogTag.storage, '実体フォルダ走査中に警告: $e');
      }

      final totalCols = metaColCount > diskDirCount
          ? metaColCount
          : diskDirCount;
      final totalItems = metaItemCount > diskFileCount
          ? metaItemCount
          : diskFileCount;

      final hasData = tagCount > 0 || totalCols > 0 || totalItems > 0;

      if (!hasData) {
        return Result.success(RestorableDataSummary.empty);
      }

      final summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: hasMeta,
        tagCount: tagCount,
        collectionCount: totalCols,
        mediaItemCount: totalItems,
        folderCount: diskDirCount,
        storagePath: rootDir.path,
        lastExportedAt: exportedAt,
      );

      AppLogger.i(
        LogTag.storage,
        '復元可能なデータを検出しました (タグ: $tagCount, コレクション: $totalCols, ファイル: $totalItems)',
      );

      return Result.success(summary);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '復元可能データの検出に失敗しました', e, st);
      return Result.failure(
        AppError.file('復元可能データの検出に失敗しました: $e', original: e, stackTrace: st),
      );
    }
  }

  static bool _isManagedPath(String relativePath) {
    final normalized = p.normalize(relativePath);
    if (!p.isRelative(normalized)) return false;
    final parts = p.split(normalized);
    return parts.isNotEmpty &&
        !parts.contains('..') &&
        (parts.first == 'library' || parts.first == 'folders');
  }
}
