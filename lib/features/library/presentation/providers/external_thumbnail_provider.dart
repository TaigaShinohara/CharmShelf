import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

part 'external_thumbnail_provider.g.dart';

@riverpod
Future<Uint8List?> externalThumbnail(
  Ref ref,
  MediaItem item,
) async {
  if (!item.requiresSourceAccess) {
    return null;
  }

  var uri = Uri.parse(item.path);
  if (!uri.hasScheme) {
    uri = Uri.file(item.path);
  }
  var revision = '${item.updatedAt.microsecondsSinceEpoch}:${item.size}';
  if (uri.isScheme('file')) {
    try {
      final stat = await File(uri.toFilePath()).stat();
      revision = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
    } catch (_) {
      // 参照先が一時的に利用できない場合はDB上の更新情報を使う。
    }
  }

  // 1. ローカルのキャッシュを確認
  final tempDir = await getTemporaryDirectory();
  final cacheDir = Directory(p.join(tempDir.path, 'external_thumb_cache'));
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }

  final hash = sha256
      .convert(utf8.encode('v2:${item.path}:$revision'))
      .toString()
      .substring(0, 24);
  final cacheFile = File(p.join(cacheDir.path, 'thumb_${item.id}_$hash'));

  if (await cacheFile.exists()) {
    try {
      final bytes = await cacheFile.readAsBytes();
      if (bytes.isNotEmpty) {
        AppLogger.d(
          LogTag.ui,
          '[ImageDecodeTrace] externalThumbnail cache hit id=${item.id} ext=${p.extension(item.path).toLowerCase()} bytes=${bytes.length} path=${item.path}',
        );
        return bytes;
      }
      AppLogger.d(
        LogTag.ui,
        '[ImageDecodeTrace] externalThumbnail cache empty id=${item.id} cache=${cacheFile.path}',
      );
    } catch (e, st) {
      AppLogger.w(
        LogTag.ui,
        '[ImageDecodeTrace] externalThumbnail cache read failed id=${item.id} cache=${cacheFile.path}',
        e,
        st,
      );
    }
  }

  // 2. SAF 経由で取得
  final storageService = await ref.watch(externalStorageServiceProvider.future);

  AppLogger.d(
    LogTag.ui,
    '[ImageDecodeTrace] externalThumbnail fetch start id=${item.id} uri=$uri ext=${p.extension(item.path).toLowerCase()}',
  );
  final bytes = await storageService.getThumbnailBytes(uri);
  AppLogger.d(
    LogTag.ui,
    '[ImageDecodeTrace] externalThumbnail fetch done id=${item.id} bytes=${bytes?.length ?? 0}',
  );

  if (bytes != null && bytes.isNotEmpty) {
    try {
      await cacheFile.writeAsBytes(bytes);
      AppLogger.d(
        LogTag.ui,
        '[ImageDecodeTrace] externalThumbnail cache write id=${item.id} cache=${cacheFile.path} bytes=${bytes.length}',
      );
    } catch (e, st) {
      AppLogger.w(
        LogTag.ui,
        '[ImageDecodeTrace] externalThumbnail cache write failed id=${item.id} cache=${cacheFile.path}',
        e,
        st,
      );
    }
  } else {
    AppLogger.w(
      LogTag.ui,
      '[ImageDecodeTrace] externalThumbnail returned empty id=${item.id} uri=$uri path=${item.path}',
    );
  }

  return bytes;
}
