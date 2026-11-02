import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';

part 'file_tree_thumbnail_provider.g.dart';

@riverpod
Future<Uint8List?> fileTreeNodeThumbnail(
  Ref ref,
  FileTreeNode node,
) async {
  if (node.isDirectory) {
    return null;
  }

  // 1. ローカルキャッシュの確認
  final tempDir = await getTemporaryDirectory();
  final cacheDir = Directory(p.join(tempDir.path, 'file_tree_thumb_cache'));
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }

  final hash = node.uri.toString().hashCode.toRadixString(16);
  final cacheFile = File(p.join(cacheDir.path, 'thumb_$hash.webp'));

  if (await cacheFile.exists()) {
    try {
      final bytes = await cacheFile.readAsBytes();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    } catch (e, st) {
      AppLogger.w(
        LogTag.ui,
        '[FileTreeThumbnail] キャッシュの読み込みに失敗しました: ${cacheFile.path}',
        e,
        st,
      );
    }
  }

  // 2. StorageService 経由でサムネイル取得
  final storageService = await ref.watch(externalStorageServiceProvider.future);

  try {
    final bytes = await storageService.getThumbnailBytes(node.uri);
    if (bytes != null && bytes.isNotEmpty) {
      try {
        await cacheFile.writeAsBytes(bytes);
      } catch (e, st) {
        AppLogger.w(
          LogTag.ui,
          '[FileTreeThumbnail] キャッシュの保存に失敗しました: ${cacheFile.path}',
          e,
          st,
        );
      }
      return bytes;
    }
  } catch (e, st) {
    AppLogger.w(
      LogTag.ui,
      '[FileTreeThumbnail] サムネイルの取得に失敗しました: ${node.uri}',
      e,
      st,
    );
  }

  return null;
}
