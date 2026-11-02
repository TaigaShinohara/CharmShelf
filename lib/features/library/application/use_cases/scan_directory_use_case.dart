// Application layer: coordinates domain contracts with persistence services.
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';

part 'scan_directory_use_case.g.dart';

@riverpod
Future<ScanDirectoryUseCase> scanDirectoryUseCase(
  Ref ref,
) async {
  final storageService = await ref.watch(externalStorageServiceProvider.future);
  return ScanDirectoryUseCase(storageService);
}

class ScanDirectoryUseCase {
  final ExternalStorageService _storageService;

  ScanDirectoryUseCase(this._storageService);

  /// 指定されたディレクトリを再帰的にスキャンしてツリー構造を構築する
  Future<Result<FileTreeNode, AppError>> invoke(Uri rootUri) async {
    try {
      AppLogger.d(LogTag.storage, 'ディレクトリのスキャンを開始: $rootUri');

      // 全ファイルをリストアップ（再帰的）
      final allFiles = await _storageService.listFiles(rootUri).toList();
      AppLogger.d(LogTag.storage, 'スキャン完了: ${allFiles.length} 件のアイテムが見つかりました');

      final directMediaParents = <String>{};
      final mediaAncestors = <String>{};
      for (final file in allFiles) {
        if (!file.isMedia || file.relativePath == null) continue;
        var parent = p.dirname(file.relativePath!);
        if (parent == '.') continue;
        directMediaParents.add(parent);
        while (parent != '.' && parent.isNotEmpty) {
          mediaAncestors.add(parent);
          parent = p.dirname(parent);
        }
      }

      // rootNodeの作成
      // Content URIの場合、toString()からbasenameを取ると不適切な場合がある
      String rootName;
      if (rootUri.scheme == 'content') {
        final decoded = _safeDecodeUriComponent(rootUri.toString());
        rootName = decoded
            .split('/')
            .lastWhere((s) => s.isNotEmpty, orElse: () => 'Root');
      } else {
        rootName = p.basename(rootUri.path);
      }

      final rootNode = FileTreeNode(
        name: rootName,
        uri: rootUri,
        relativePath: '',
        isDirectory: true,
        isExpanded: true,
        isCatalog: true, // デフォルト
        isMedia: allFiles.any((f) => f.isMedia),
      );

      // パスをキーとしたノードマップ（ツリー構築用）
      final nodeMap = <String, FileTreeNode>{'': rootNode};

      // ファイルリストを相対パスの深さ順にソートして処理
      allFiles.sort(
        (a, b) => (a.relativePath ?? '').compareTo(b.relativePath ?? ''),
      );

      for (final file in allFiles) {
        final relPath = file.relativePath ?? '';
        final parentPath = p.dirname(relPath) == '.' ? '' : p.dirname(relPath);

        // 親ノードの状態を確認
        final parentNode = nodeMap[parentPath];
        final isParentCatalog = parentNode?.isCatalog ?? false;

        final isCatalog =
            file.isDirectory &&
            (isParentCatalog || directMediaParents.contains(relPath));

        final node = FileTreeNode(
          name: file.name ?? 'unknown',
          uri: Uri.parse(file.uri),
          relativePath: relPath,
          isDirectory: file.isDirectory,
          size: file.size,
          mimeType: file.mimeType,
          isMedia:
              file.isMedia ||
              (file.isDirectory && mediaAncestors.contains(relPath)),
          isCatalog: isCatalog,
        );

        nodeMap[relPath] = node;

        // 親ノードに自分を追加
        if (parentNode != null) {
          parentNode.children.add(node);
        } else {
          AppLogger.w(
            LogTag.storage,
            '親ノードが見つかりません: $parentPath (ノード: $relPath)',
          );
        }
      }

      return Result.success(rootNode);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ディレクトリのスキャン中にエラーが発生しました', e, st);
      return Result.failure(
        AppError.file('ディレクトリのスキャンに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  String _safeDecodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
}
