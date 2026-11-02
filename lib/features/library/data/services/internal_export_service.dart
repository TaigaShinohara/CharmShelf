import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mime/mime.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';

part 'internal_export_service.g.dart';

class InternalExportService {
  final MediaRepository _repository;
  final ExternalStorageService _storageService;
  final bool _isIOS;

  InternalExportService(this._repository, this._storageService, {bool? isIOS})
    : _isIOS = isIOS ?? Platform.isIOS;

  /// 複数のアイテムをエクスポートまたはダウンロードする
  /// [targetFolderUri] が null の場合、システム標準のダウンロードフォルダに保存する
  Future<Result<void, AppError>> exportMediaItems(
    List<MediaItem> items,
    Uri? targetFolderUri, {
    void Function(int processed, int total, String? fileName)? onProgress,
  }) async {
    Uri? temporaryTargetFolderUri;
    try {
      final docsDir = await getPrivateStorageDirectory();
      final tempDir = await getTemporaryDirectory();

      // iOSのDocumentsは公開しない。保存先未指定のダウンロードも、
      // ユーザーが明示的に選んだ外部フォルダへ書き出す。
      var effectiveTargetFolderUri = targetFolderUri;
      if (_isIOS && effectiveTargetFolderUri == null) {
        effectiveTargetFolderUri = await _storageService.pickFolder(
          persistAccess: false,
        );
        if (effectiveTargetFolderUri == null) {
          return Result.failure(AppError.file('保存先フォルダが選択されませんでした'));
        }
        temporaryTargetFolderUri = effectiveTargetFolderUri;
      }

      // 進捗計算のために全件数をカウント（ダウンロードの場合のみ）
      var totalItems = 0;
      if (targetFolderUri == null && onProgress != null) {
        for (final item in items) {
          totalItems += await _countItemsRecursive(item);
        }
        if (totalItems > 0) {
          onProgress(0, totalItems, null);
        }
      }

      var processedItems = 0;
      final downloadRoot = effectiveTargetFolderUri == null
          ? _newDownloadRootName()
          : null;
      final downloadMetadata = <Map<String, dynamic>>[];

      for (final item in items) {
        if (effectiveTargetFolderUri != null) {
          // 指定フォルダへエクスポート（従来通り）
          final result = await _exportItemRecursive(
            item,
            effectiveTargetFolderUri,
            docsDir.path,
          );
          if (result is Failure) return result;
        } else {
          // システムダウンロードフォルダへ直接保存
          final result = await _downloadItemRecursive(
            item,
            docsDir.path,
            downloadRoot ?? '',
            downloadMetadata,
            (fileName) {
              processedItems++;
              onProgress?.call(processedItems, totalItems, fileName);
            },
          );
          if (result is Failure) return result;
        }
      }

      if (downloadRoot != null) {
        final metadataResult = await _saveDownloadMetadata(
          tempDir.path,
          downloadRoot,
          downloadMetadata,
        );
        if (metadataResult is Failure) return metadataResult;
      }
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'Operation failed', e, st);
      final actionName = targetFolderUri != null ? 'エクスポート' : 'ダウンロード';
      return Result.failure(
        AppError.file('$actionNameに失敗しました: $e', original: e, stackTrace: st),
      );
    } finally {
      final temporaryTarget = temporaryTargetFolderUri;
      if (temporaryTarget != null) {
        await _storageService.releaseFolder(temporaryTarget);
      }
    }
  }

  Future<int> _countItemsRecursive(MediaItem item) async {
    if (item.type == MediaType.file) return 1;
    final childrenResult = await _repository.getByParentPath(item.path);
    if (childrenResult is Success<List<MediaItem>, AppError>) {
      var count = 0;
      for (final child in childrenResult.data) {
        count += await _countItemsRecursive(child);
      }
      return count;
    }
    return 0;
  }

  Future<Result<void, AppError>> _downloadItemRecursive(
    MediaItem item,
    String docsPath,
    String relativeSubPath,
    List<Map<String, dynamic>> metadata,
    void Function(String fileName) onFileSaved,
  ) async {
    if (item.type == MediaType.file) {
      final sourceFile = File(p.join(docsPath, item.path));
      if (!await sourceFile.exists()) {
        return Result.failure(
          AppError.file('元ファイルが見つかりません: ${p.basename(item.path)}'),
        );
      }

      final fileName = p.basename(item.path);

      // 直接ダウンロード（階層維持）
      // AndroidのMediaStoreでは、subdirectoryとして "フォルダ名" または "フォルダ/サブ" を渡す
      final success = await _storageService.saveToDownloadFolder(
        sourceFile.path,
        fileName,
        subdirectory: relativeSubPath.isEmpty ? null : relativeSubPath,
      );

      if (!success) {
        return Result.failure(
          AppError.file('ダウンロードフォルダへの保存に失敗しました: $fileName'),
        );
      }
      metadata.add(
        await _buildDownloadMetadata(
          item,
          p.join(relativeSubPath, fileName),
          downloadRoot: relativeSubPath.split(p.separator).first,
        ),
      );
      onFileSaved(fileName);
      return Result.success(null);
    } else {
      // フォルダの場合、子アイテムを再帰的に処理
      final childrenResult = await _repository.getByParentPath(item.path);
      if (childrenResult is Success<List<MediaItem>, AppError>) {
        final folderName = p.basename(item.path);
        // 現在の相対パスに自身のフォルダ名を追加して、子に引き継ぐ
        final newRelativePath = relativeSubPath.isEmpty
            ? folderName
            : p.join(relativeSubPath, folderName);
        metadata.add(
          await _buildDownloadMetadata(
            item,
            newRelativePath,
            downloadRoot: relativeSubPath.split(p.separator).first,
          ),
        );

        for (final child in childrenResult.data) {
          final result = await _downloadItemRecursive(
            child,
            docsPath,
            newRelativePath,
            metadata,
            onFileSaved,
          );
          if (result is Failure) return result;
        }
      } else if (childrenResult is Failure<List<MediaItem>, AppError>) {
        return Result.failure(childrenResult.error);
      }
      return Result.success(null);
    }
  }

  String _newDownloadRootName() {
    final now = DateTime.now();
    final stamp = now.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    return 'CharmShelf_${stamp.substring(0, 15)}';
  }

  Future<Map<String, dynamic>> _buildDownloadMetadata(
    MediaItem item,
    String outputPath, {
    required String downloadRoot,
  }) async {
    final relativePath = outputPath == downloadRoot
        ? ''
        : outputPath.startsWith('$downloadRoot${p.separator}')
        ? outputPath.substring(downloadRoot.length + 1)
        : outputPath;
    final metadata = <String, dynamic>{
      'relativePath': relativePath,
      'type': item.type.name,
      'uid': item.uid,
      'sourcePath': item.path,
      'addedAt': item.addedAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
      'size': item.size,
      'tags': <Map<String, dynamic>>[],
    };

    final collectionResult = await _repository.getCollectionByPath(item.path);
    if (collectionResult is Failure) {
      throw collectionResult.errorOrNull!;
    }
    final collection = collectionResult.dataOrNull;
    if (collection != null) {
      if (collection.tags.isAttached && !collection.tags.isLoaded) {
        await collection.tags.load();
      }
      metadata['collection'] = {
        'uid': collection.uid,
        'title': collection.title,
        'alias': collection.alias,
        'path': collection.path,
        'tier': collection.tier,
        'notes': collection.notes,
        'isCatalog': collection.isCatalog,
      };
      metadata['tags'] = collection.tags
          .map(
            (tag) => {
              'key': tag.key,
              'name': tag.name,
              'facetId': tag.facetId,
              'parentId': tag.parentId,
              'level': tag.level,
              'colorValue': tag.colorValue,
            },
          )
          .toList();
    }
    return metadata;
  }

  Future<Result<void, AppError>> _saveDownloadMetadata(
    String tempPath,
    String downloadRoot,
    List<Map<String, dynamic>> items,
  ) async {
    final metadataFile = File(p.join(tempPath, 'tagshelf-metadata.json'));
    try {
      final document = {
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'items': items,
      };
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(document),
        flush: true,
      );
      final saved = await _storageService.saveToDownloadFolder(
        metadataFile.path,
        'tagshelf-metadata.json',
        subdirectory: downloadRoot,
      );
      if (!saved) {
        return Result.failure(AppError.file('書き出しメタデータの保存に失敗しました'));
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.file('書き出しメタデータの保存に失敗しました: $e', original: e, stackTrace: st),
      );
    } finally {
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
    }
  }

  Future<Result<void, AppError>> _exportItemRecursive(
    MediaItem item,
    Uri currentTargetUri,
    String docsPath,
  ) async {
    if (item.type == MediaType.file) {
      return _exportFile(item, currentTargetUri, docsPath);
    } else {
      // サブフォルダの作成
      final folderName = p.basename(item.path);
      final subFolderUri = await _storageService.createFolder(
        currentTargetUri,
        folderName,
      );
      if (subFolderUri == null) {
        return Result.failure(AppError.file('フォルダの作成に失敗しました: $folderName'));
      }

      // 子アイテムを取得
      final childrenResult = await _repository.getByParentPath(item.path);
      if (childrenResult is Success<List<MediaItem>, AppError>) {
        for (final child in childrenResult.data) {
          final result = await _exportItemRecursive(
            child,
            subFolderUri,
            docsPath,
          );
          if (result is Failure) return result;
        }
      } else if (childrenResult is Failure<List<MediaItem>, AppError>) {
        return Result.failure(childrenResult.error);
      }
      return Result.success(null);
    }
  }

  Future<Result<void, AppError>> _exportFile(
    MediaItem item,
    Uri targetFolderUri,
    String docsPath,
  ) async {
    try {
      final sourceFile = File(p.join(docsPath, item.path));
      if (!await sourceFile.exists()) {
        AppLogger.w(LogTag.storage, 'ソースファイルが見つかりません: ${item.path}');
        return Result.failure(
          AppError.file('元ファイルが見つかりません: ${p.basename(item.path)}'),
        );
      }

      final fileName = p.basename(item.path);
      final mimeType = lookupMimeType(item.path) ?? 'application/octet-stream';

      final targetFileUri = await _storageService.createFile(
        targetFolderUri,
        fileName,
        mimeType,
      );

      if (targetFileUri == null) {
        return Result.failure(AppError.file('ファイルの作成に失敗しました: $fileName'));
      }

      final success = await _storageService.copyFileToUri(
        sourceFile,
        targetFileUri,
      );
      if (!success) {
        return Result.failure(AppError.file('データの書き込みに失敗しました: $fileName'));
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.file('ファイルの出力に失敗しました: $e', original: e, stackTrace: st),
      );
    }
  }
}

@riverpod
Future<InternalExportService> internalExportService(
  Ref ref,
) async {
  final repo = await ref.watch(mediaRepositoryProvider.future);
  final storage = await ref.watch(externalStorageServiceProvider.future);
  return InternalExportService(repo, storage);
}
