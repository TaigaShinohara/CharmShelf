import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

part 'local_thumbnail_provider.g.dart';

/// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー
@riverpod
Future<String?> localThumbnail(Ref ref, MediaItem item) async {
  // 既に thumbnailPath がある場合はそれをそのまま返す
  if (item.thumbnailPath != null && item.thumbnailPath!.isNotEmpty) {
    return item.thumbnailPath;
  }

  // 画像ファイル以外は対象外
  if (!item.isImage || item.sourceType != MediaSourceType.localCopy) {
    return null;
  }

  final docsPath = ref.watch(appDocumentsPathSyncProvider);
  final originalFile = File(p.join(docsPath, item.path));
  if (!await originalFile.exists()) {
    return null;
  }

  try {
    // 1. キャッシュ用ディレクトリの確認
    final thumbDir = Directory(p.join(docsPath, '.thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    final hash = item.path.hashCode.toRadixString(16);
    final targetFileName = 'thumb_${item.id}_$hash.jpg';
    final targetPath = p.join(thumbDir.path, targetFileName);
    final targetFile = File(targetPath);

    // 2. すでにキャッシュファイルが生成されている場合は即座に相対パスを返す
    final relativeThumbPath = p.relative(targetPath, from: docsPath);
    if (await targetFile.exists() && await targetFile.length() > 0) {
      return relativeThumbPath;
    }

    // 3. オンデマンドで圧縮サムネイル（256x256, 品質75）を生成
    AppLogger.d(LogTag.ui, 'オンデマンドサムネイル生成開始: id=${item.id}, path=${item.path}');

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      originalFile.path,
      targetPath,
      minWidth: 256,
      minHeight: 256,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (compressedFile != null) {
      AppLogger.d(
        LogTag.ui,
        'オンデマンドサムネイル生成完了: id=${item.id}, target=$relativeThumbPath',
      );

      // 一覧の再クエリを起こさずに生成済みパスだけを保存する
      try {
        final repo = await ref.read(mediaRepositoryProvider.future);
        final result = await repo.saveGeneratedThumbnailPath(
          item.id,
          item.path,
          relativeThumbPath,
        );
        if (result.isFailure) {
          AppLogger.w(
            LogTag.db,
            'MediaItemサムネイルパス更新スキップ: id=${item.id}',
            result.errorOrNull,
          );
        }
      } catch (e) {
        // DB更新失敗は非致命的
        AppLogger.w(LogTag.db, 'MediaItemサムネイルパス更新スキップ: id=${item.id}', e);
      }

      return relativeThumbPath;
    }
  } catch (e, st) {
    AppLogger.w(
      LogTag.ui,
      'オンデマンドサムネイル生成失敗: id=${item.id}, path=${item.path}',
      e,
      st,
    );
  }

  return null;
}
