import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:isar/isar.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_synchronizer.g.dart';

@riverpod
class LibrarySynchronizer extends _$LibrarySynchronizer {
  @override
  void build() {}

  Future<void> syncPath(String rootPath) async =>
      throw UnsupportedError('External reference registration retired');

  /// ライブラリ全体の整合性をチェック（参照切れの検出）
  Future<void> checkLibraryIntegrity() async {
    final isar = await ref.read(isarProvider.future);
    final fileService = ref.read(fileServiceProvider);
    final externalStorage = await ref.read(
      externalStorageServiceProvider.future,
    );
    final items = await isar.mediaItems
        .filter()
        .sourceTypeEqualTo(MediaSourceType.localCopy)
        .findAll();
    final now = DateTime.now();

    final updatedItems = <MediaItem>[];

    for (final item in items) {
      final bool exists;
      if (item.sourceType == MediaSourceType.localCopy) {
        final existsResult = await fileService.managedEntityExists(item.path);
        // 検査自体の失敗を「消失」と誤認しない。
        if (existsResult.isFailure) continue;
        exists = existsResult.dataOrNull ?? false;
      } else {
        try {
          exists = await externalStorage.fileExists(Uri.parse(item.path));
        } catch (_) {
          // 権限失効や一時的なプロバイダ障害をファイル消失として確定しない。
          continue;
        }
      }

      if (item.isMissing != !exists) {
        item.isMissing = !exists;
        item.missingCheckedAt = now;
        updatedItems.add(item);
      }
    }

    if (updatedItems.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.mediaItems.putAll(updatedItems);
      });
    }
  }

  /// 参照切れアイテムを指定ディレクトリから探し出して再リンクする
  Future<int> relinkMissingItems(String searchRoot) async {
    final isar = await ref.read(isarProvider.future);
    final missingItems = await isar.mediaItems
        .filter()
        .isMissingEqualTo(true)
        .findAll();

    if (missingItems.isEmpty) return 0;

    final searchDir = Directory(searchRoot);
    if (!searchDir.existsSync()) return 0;

    // 検索ディレクトリ内の全ファイルをスキャン（再帰的）
    // パフォーマンスのため、ファイル名とサイズでマップを作成
    final fileMap = <String, List<File>>{};
    await for (final entity in searchDir.list(recursive: true)) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        fileMap.putIfAbsent(fileName, () => []).add(entity);
      }
    }

    var relinkedCount = 0;
    final toUpdate = <MediaItem>[];

    for (final item in missingItems) {
      final originalFileName = p.basename(item.path);
      final candidates = fileMap[originalFileName];

      if (candidates != null && candidates.isNotEmpty) {
        for (final candidate in candidates) {
          final candidateSize = await candidate.length();
          // 名前とサイズが一致すれば同一ファイルとみなす
          if (candidateSize == item.size) {
            item.path = candidate.path;
            item.isMissing = false;
            item.updatedAt = DateTime.now();
            toUpdate.add(item);
            relinkedCount++;
            break;
          }
        }
      }
    }

    if (toUpdate.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.mediaItems.putAll(toUpdate);
      });
    }

    return relinkedCount;
  }
}
