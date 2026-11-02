import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'collection_cover_revision_provider.dart';

part 'collection_cover_thumbnail_provider.g.dart';

// Retain a small working set across scroll-out/scroll-in. Unused entries
// expire, including references to external files without DB notifications.
final _coverRetentionProvider = Provider((ref) => <Object, void Function()>{});
final _coverWorkProvider = Provider((ref) => _CoverWorkLimiter());

class _CoverWorkLimiter {
  int _active = 0;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() work) async {
    if (_active < 3) {
      _active++;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await work();
    } finally {
      if (_waiting.isEmpty) {
        _active--;
      } else {
        _waiting.removeAt(0).complete();
      }
    }
  }
}

void _retainCover(Ref ref) {
  final entries = ref.read(_coverRetentionProvider);
  final key = Object();
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 30), () {
    entries.remove(key);
    link.close();
  });
  entries[key] = () {
    timer.cancel();
    link.close();
  };
  while (entries.length > 24) {
    entries.remove(entries.keys.first)!();
  }
  ref.onDispose(() {
    timer.cancel();
    entries.remove(key);
  });
}

/// カタログのカバー画像データ表現
sealed class CollectionCoverData {
  const CollectionCoverData();
}

/// ローカルファイルパスによるカバー画像
class FileCoverData extends CollectionCoverData {
  final String relativePath;
  const FileCoverData(this.relativePath);
}

/// メモリ上のバイトデータによるカバー画像（外部ストレージ用）
class MemoryCoverData extends CollectionCoverData {
  final Uint8List bytes;
  const MemoryCoverData(this.bytes);
}

/// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー
@riverpod
Future<CollectionCoverData?> collectionCoverThumbnail(
  Ref ref,
  MediaCollection collection,
) async {
  ref.watch(collectionCoverRevisionProvider(collection.path));
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final cover = await ref.read(_coverWorkProvider).run(() async {
    if (disposed) return null;
    return _resolveCollectionCover(ref, collection, () => disposed);
  });
  // A successful miss is useful too. Exceptions are deliberately not retained.
  if (!disposed && (cover != null || !collection.isExternal)) _retainCover(ref);
  return cover;
}

Future<CollectionCoverData?> _resolveCollectionCover(
  Ref ref,
  MediaCollection collection,
  bool Function() isDisposed,
) async {
  String? docsPath;
  try {
    docsPath = ref.watch(appDocumentsPathSyncProvider);
  } catch (_) {
    try {
      docsPath = await ref.watch(applicationDocumentsPathProvider.future);
    } catch (_) {
      rethrow;
    }
  }

  // 1. collection.coverImagePath が設定されており、実体ファイルが存在する場合
  if (collection.coverImagePath != null &&
      collection.coverImagePath!.isNotEmpty &&
      docsPath != null) {
    final file = File(p.join(docsPath, collection.coverImagePath!));
    if (await file.exists()) {
      return FileCoverData(collection.coverImagePath!);
    }
  }

  if (isDisposed()) return null;
  final repository = await ref.watch(mediaRepositoryProvider.future);

  // 2. 単体ファイルカタログの場合、または collection.path 自体に該当するアイテムが存在する場合
  final selfItemResult = await repository.getByPath(collection.path);
  if (selfItemResult.isFailure) throw selfItemResult.errorOrNull!;
  final selfItem = selfItemResult.dataOrNull;
  if (selfItem != null && selfItem.type == MediaType.file) {
    final cover = await _resolveItemCover(ref, selfItem, docsPath, isDisposed);
    if (cover != null) return cover;
  }

  // 3. フォルダカタログの場合: 配下のアイテムを自然順（ファイル名昇順）にソートして先頭の画像/サムネイルを解決
  if (isDisposed()) return null;
  final childrenResult = await repository.getCoverCandidates(collection.path);
  if (childrenResult.isFailure) throw childrenResult.errorOrNull!;
  final children = (childrenResult.dataOrNull ?? []).toList();
  if (children.isNotEmpty) {
    children.sort((a, b) => compareNatural(a.path, b.path));
    for (final child in children) {
      if (isDisposed()) return null;
      if (child.type == MediaType.file) {
        final cover = await _resolveItemCover(ref, child, docsPath, isDisposed);
        if (cover != null) return cover;
      }
    }
  }

  // 4. collection.items リレーションから検索。
  // リレーションには過去の同期で子孫が含まれる場合があるため、
  // 表紙候補はこのカタログの直下に限定する。
  if (collection.items.isNotEmpty) {
    final items =
        collection.items
            .where((item) => item.parentPath == collection.path)
            .toList()
          ..sort((a, b) => compareNatural(a.path, b.path));
    for (final item in items) {
      if (isDisposed()) return null;
      final cover = await _resolveItemCover(ref, item, docsPath, isDisposed);
      if (cover != null) return cover;
    }
  }

  return null;
}

Future<CollectionCoverData?> _resolveItemCover(
  Ref ref,
  MediaItem item,
  String? docsPath,
  bool Function() isDisposed,
) async {
  if (isDisposed()) return null;
  // 既に生成されたサムネイル
  if (item.thumbnailPath != null &&
      item.thumbnailPath!.isNotEmpty &&
      docsPath != null) {
    final file = File(p.join(docsPath, item.thumbnailPath!));
    if (await file.exists()) {
      return FileCoverData(item.thumbnailPath!);
    }
  }

  // 外部ストレージのアイテム
  if (item.sourceType == MediaSourceType.externalReference &&
      item.type == MediaType.file) {
    try {
      if (isDisposed()) return null;
      final bytes = await ref.watch(externalThumbnailProvider(item).future);
      if (bytes != null && bytes.isNotEmpty) {
        return MemoryCoverData(bytes);
      }
    } catch (_) {
      // Do not turn transient access failures into a cached "no cover" result.
      rethrow;
    }
  }

  // ローカルコピーの画像
  if (item.isImage &&
      item.sourceType == MediaSourceType.localCopy &&
      docsPath != null) {
    final file = File(p.join(docsPath, item.path));
    if (await file.exists()) {
      return FileCoverData(item.path);
    }
  }

  return null;
}
