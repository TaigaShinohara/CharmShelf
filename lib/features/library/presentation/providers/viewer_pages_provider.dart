import 'dart:io';
import 'package:private_shelf/core/performance/bounded_lru_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/services/image_optimization_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_page.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';

import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';

part 'viewer_pages_provider.g.dart';

class ViewerPagesParam {
  final List<MediaItem> items;
  final ViewerSourceContext? sourceContext;

  const ViewerPagesParam(this.items, {this.sourceContext});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerPagesParam &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          sourceContext == other.sourceContext;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), sourceContext);
}

const double _splitAspectRatioThreshold = 1.3;
final Map<String, double> globalImageAspectRatioCache =
    BoundedLruMap<String, double>(2048);
final Map<String, Future<double?>> _aspectRatioInFlight = {};
final _imageInfoService = ImageOptimizationService();

double? getCachedImageAspectRatio(File file) {
  return globalImageAspectRatioCache[file.path];
}

Future<double?> fetchImageAspectRatio(File file, {String? cacheKey}) async {
  if (Platform.isAndroid && p.extension(file.path).toLowerCase() == '.webp') {
    AppLogger.d(
      LogTag.ui,
      '[ImageDecodeTrace] skip aspect ratio probe for android webp path=${file.path}',
    );
    return null;
  }
  final key = cacheKey ?? file.path;
  final cached =
      globalImageAspectRatioCache[key] ??
      globalImageAspectRatioCache[file.path];
  if (cached != null) {
    // Either the renderer (physical path) or the page builder (stable item
    // path) may populate the cache first. Heal the missing alias on every hit.
    globalImageAspectRatioCache[key] = cached;
    globalImageAspectRatioCache[file.path] = cached;
    return cached;
  }
  final running = _aspectRatioInFlight[key];
  if (running != null) return running;

  final future = () async {
    final result = await _imageInfoService.getInfo(file);
    final info = result.dataOrNull;
    if (info == null || info.height == 0) {
      AppLogger.w(
        LogTag.ui,
        '[ImageDecodeTrace] aspect ratio probe failed path=${file.path} ext=${p.extension(file.path).toLowerCase()}',
      );
      return null;
    }
    final ratio = info.aspectRatio;
    globalImageAspectRatioCache[key] = ratio;
    // Image widgets resolve by the physical file path, while viewer page
    // generation resolves by the stable MediaItem path. Keep both aliases.
    globalImageAspectRatioCache[file.path] = ratio;
    return ratio;
  }();
  _aspectRatioInFlight[key] = future;
  try {
    return await future;
  } finally {
    if (identical(_aspectRatioInFlight[key], future)) {
      _aspectRatioInFlight.remove(key);
    }
  }
}

bool _hasMime(MediaItem item, String prefix) {
  final mime = item.mimeType?.toLowerCase();
  if (mime == null || mime.isEmpty) return false;
  return mime.startsWith(prefix);
}

String _resolveExtension(MediaItem item) {
  return p.extension(item.path).toLowerCase();
}

bool _isImage(MediaItem item) {
  if (_hasMime(item, 'image/')) return true;
  if (_hasMime(item, 'video/') || _hasMime(item, 'audio/')) return false;
  final ext = _resolveExtension(item);
  return ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'].contains(ext);
}

bool _isVideo(MediaItem item) {
  if (_hasMime(item, 'video/')) return true;
  final ext = _resolveExtension(item);
  return [
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.3gp',
    '.flv',
    '.wmv',
    '.ts',
    '.m2ts',
  ].contains(ext);
}

bool _isAudio(MediaItem item) {
  if (_hasMime(item, 'audio/')) return true;
  final ext = _resolveExtension(item);
  return [
    '.mp3',
    '.wav',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.wma',
    '.aiff',
    '.alac',
  ].contains(ext);
}

bool _isSplitEnabled(Ref ref, MediaItem item) {
  final linked = item.collection.value;
  if (linked != null) return linked.splitSpreadView;
  final path = item.parentPath ?? item.path;
  final collection = ref.read(collectionNotifierProvider(path)).asData?.value;
  return collection?.splitSpreadView ?? false;
}

bool _shouldConsiderSplit(Ref ref, MediaItem item) {
  if (!_isImage(item) || _isVideo(item) || _isAudio(item)) {
    return false;
  }
  return _isSplitEnabled(ref, item);
}

@riverpod
List<ViewerPage> viewerPages(Ref ref, ViewerPagesParam param) {
  final items = param.items;

  final isAnySplitEnabled = items.any(
    (item) => _shouldConsiderSplit(ref, item),
  );
  if (!isAnySplitEnabled) {
    return items.map((item) => ViewerPage(item: item)).toList();
  }

  final pages = <ViewerPage>[];
  for (final item in items) {
    if (_shouldConsiderSplit(ref, item)) {
      final key = item.path;
      final ratio = globalImageAspectRatioCache[key];
      if (ratio != null && ratio >= _splitAspectRatioThreshold) {
        pages.add(ViewerPage(item: item, splitSide: SplitSide.left));
        pages.add(ViewerPage(item: item, splitSide: SplitSide.right));
        continue;
      }
    }
    pages.add(ViewerPage(item: item));
  }

  return pages;
}

/// 指定されたインデックスの周辺画像のアスペクト比を非同期でオンデマンド取得・キャッシュする
Future<bool> ensureAspectRatiosCachedAround({
  required WidgetRef ref,
  required List<MediaItem> items,
  required int centerIndex,
  int radius = 5,
}) async {
  if (items.isEmpty) return false;
  final docsPath = ref.read(appDocumentsPathSyncProvider);

  final start = (centerIndex - radius).clamp(0, items.length - 1);
  final end = (centerIndex + radius).clamp(0, items.length - 1);

  // Resolve every provider dependency synchronously. No WidgetRef is touched
  // after the first await, so closing the viewer cannot leave an async task
  // using a disposed element.
  final probes = <_AspectRatioProbe>[];
  for (var i = start; i <= end; i++) {
    final item = items[i];
    if (!_isImage(item) || _isVideo(item) || _isAudio(item)) continue;
    final linkedCollection = item.collection.value;
    final collectionPath = item.parentPath ?? item.path;
    final splitEnabled =
        linkedCollection?.splitSpreadView ??
        ref
            .read(collectionNotifierProvider(collectionPath))
            .asData
            ?.value
            ?.splitSpreadView ??
        false;
    if (!splitEnabled) continue;

    final cacheKey = item.path;
    if (globalImageAspectRatioCache.containsKey(cacheKey)) continue;
    probes.add(
      _AspectRatioProbe(
        item: item,
        cacheKey: cacheKey,
        externalTempPathFuture: item.requiresSourceAccess
            ? ref.read(externalFilePreviewProvider(item).future)
            : null,
      ),
    );
  }

  var hasNewSplitRatio = false;
  for (final probe in probes) {
    final item = probe.item;
    File? file;
    if (item.requiresSourceAccess) {
      final tempPath = await probe.externalTempPathFuture;
      if (tempPath != null) {
        final f = File(tempPath);
        if (await f.exists()) file = f;
      }
    } else {
      final f = File(p.join(docsPath, item.path));
      if (await f.exists()) file = f;
    }

    if (file != null) {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) continue;
      final isAndroidWebp =
          Platform.isAndroid && p.extension(file.path).toLowerCase() == '.webp';
      if (!isAndroidWebp) {
        final ratio = await fetchImageAspectRatio(
          file,
          cacheKey: probe.cacheKey,
        );
        if (ratio != null && ratio >= _splitAspectRatioThreshold) {
          hasNewSplitRatio = true;
        }
      }
    }
  }

  return hasNewSplitRatio;
}

class _AspectRatioProbe {
  const _AspectRatioProbe({
    required this.item,
    required this.cacheKey,
    this.externalTempPathFuture,
  });

  final MediaItem item;
  final String cacheKey;
  final Future<String?>? externalTempPathFuture;
}
