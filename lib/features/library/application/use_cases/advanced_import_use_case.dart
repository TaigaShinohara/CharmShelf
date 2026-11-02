import 'dart:io';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import '../../data/services/external_storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';

class AdvancedImportUseCase {
  final InternalImportService _importService;

  AdvancedImportUseCase(this._importService);

  /// ユーザーが選択したノードを元にインポートを実行する
  Future<Result<ImportExecutionReport, AppError>> invoke(
    List<FileTreeNode> selectedNodes, {
    String? targetParentPath,
    ImportExecutionReport? previousReport,
    ImportCatalogMode catalogMode = ImportCatalogMode.folder,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    // Recheck the filename rather than trusting a persisted isMedia flag:
    // older file-picker drafts marked every selected file as supported.
    bool isSupported(FileTreeNode node) =>
        MediaFormatUtils.supportedMimeExtension(
          node.name,
          node.sourceDocumentUri != null ? node.mimeType : null,
        ) !=
        null;
    final selectedLeaves = selectedNodes
        .where((node) => !node.isDirectory)
        .toList();
    final selectedFiles = selectedLeaves.where(isSupported).toList();
    final unsupported = <String, ImportFailureDetail>{
      // Retries select only pending files. Keep final rejections from the
      // original selection so the session's totals and reasons stay stable.
      for (final entry
          in previousReport?.failedEntries ?? const <ImportFailureDetail>[])
        if (entry.reason == ImportFailureReasonCode.unsupported)
          entry.path: entry,
      for (final node in selectedLeaves.where((node) => !isSupported(node)))
        node.relativePath: ImportFailureDetail(
          path: node.relativePath,
          displayName: node.name,
          reason: ImportFailureReasonCode.unsupported,
        ),
    };
    final selectedPaths = selectedFiles
        .map((node) => node.relativePath)
        .toSet();
    final committed = <ImportCommittedItem>[...?previousReport?.committedItems];
    final destinations = <ImportCommittedItem>[
      ...?previousReport?.destinations,
    ];
    // Unsupported entries are final rejections, not transient copy failures.
    // They must not enter the folder service's failure/rollback threshold or
    // the pending retry set, but their reason and count remain visible.
    final failures = unsupported.values.toList();
    final sessionId = previousReport?.sessionId ?? const Uuid().v4();
    var cancelled = false;
    var rolledBack = false;
    var retryBlocked = previousReport?.retryBlocked ?? false;
    final pending = <String>{...selectedPaths};

    ImportExecutionReport snapshot() => ImportExecutionReport(
      sessionId: sessionId,
      committedItems: List.unmodifiable(
        {for (final item in committed) item.id: item}.values,
      ),
      destinations: List.unmodifiable(
        {for (final item in destinations) item.sourcePath: item}.values,
      ),
      pendingSourcePaths: pending.toList(growable: false),
      totalItems:
          committed.where((item) => !item.isFolder).length +
          pending.length +
          unsupported.length,
      processedItems: committed.where((item) => !item.isFolder).length,
      failedItems: failures.length,
      failureThresholdCount: ImportExecutionReport.defaultFailureThresholdCount,
      failedEntries: List.unmodifiable(failures),
      isCancelled: cancelled,
      isRolledBack: rolledBack,
      retryBlocked: retryBlocked,
    );

    ImportCommittedItem rebase(ImportCommittedItem item, String rootPath) =>
        ImportCommittedItem(
          id: item.id,
          uid: item.uid,
          path: item.path,
          sourcePath: rootPath.isEmpty
              ? item.sourcePath
              : item.sourcePath.isEmpty
              ? rootPath
              : '$rootPath/${item.sourcePath}',
          isFolder: item.isFolder,
          isCatalog: item.isCatalog,
          sizeBytes: item.sizeBytes,
        );

    void consume(ImportExecutionReport report, {String rootPath = ''}) {
      cancelled = cancelled || report.isCancelled;
      rolledBack = rolledBack || report.isRolledBack;
      retryBlocked = retryBlocked || report.retryBlocked;
      final newItems = report.committedItems.map(
        (item) => rebase(item, rootPath),
      );
      committed.addAll(newItems);
      destinations.addAll(
        report.destinations.map((item) => rebase(item, rootPath)),
      );
      pending.removeAll(
        newItems.where((item) => !item.isFolder).map((item) => item.sourcePath),
      );
      failures.addAll(
        report.failedEntries.map(
          (failure) => ImportFailureDetail(
            path: rootPath.isEmpty ? failure.path : '$rootPath/${failure.path}',
            displayName: failure.displayName,
            reason: failure.reason,
          ),
        ),
      );
    }

    Result<ImportExecutionReport, AppError> failure(
      AppError error, {
      String rootPath = '',
    }) {
      final data = error.additionalData;
      if (data != null) {
        consume(ImportExecutionReport.fromMap(data), rootPath: rootPath);
      } else {
        // The service cannot establish the final storage state. Never duplicate
        // uncertain work by automatically retrying it.
        retryBlocked = true;
      }
      return Result.failure(error.withAdditionalData(snapshot().toMap()));
    }

    Iterable<ImportCommittedItem> committedFiles() => {
      for (final item in committed)
        if (!item.isFolder) item.id: item,
    }.values;

    int committedBytes() => committedFiles().fold<int>(
      0,
      (sum, item) => sum + (item.sizeBytes ?? 0),
    );

    try {
      if (retryBlocked) return Result.failure(AppError.file('取り込み状態を確認してください'));
      // Already imported files consume the same session budget on every retry.
      pending.removeAll(committedFiles().map((item) => item.sourcePath));
      final needsMeasuredBudget = selectedNodes.any(
        (node) =>
            node.sourceDocumentUri != null ||
            node.sourceTreeUri != null ||
            (node.isDirectory && node.uri.scheme == 'content'),
      );
      if (needsMeasuredBudget &&
          committedFiles().any(
            (item) => item.sizeBytes == null || item.sizeBytes! < 0,
          )) {
        retryBlocked = true;
        return Result.failure(
          AppError.file(
            '取り込み済みファイルの容量を確認できません',
          ).withAdditionalData(snapshot().toMap()),
        );
      }
      if (committedBytes() > ImportSafetyPolicy.maxTotalBytes) {
        retryBlocked = true;
        return Result.failure(
          AppError.file(
            '取り込み可能な容量を超えています',
          ).withAdditionalData(snapshot().toMap()),
        );
      }
      final sourceFiles = selectedFiles
          .where(
            (n) =>
                (n.sourceTreeUri != null || n.sourceDocumentUri != null) &&
                pending.contains(n.relativePath),
          )
          .toList();
      if (sourceFiles.isNotEmpty) {
        var totalBytes = committedBytes();
        if (sourceFiles.length > ImportSafetyPolicy.maxFileCount) {
          return Result.failure(
            AppError.file(
              '取り込み可能な件数を超えています',
            ).withAdditionalData(snapshot().toMap()),
          );
        }
        for (final file in sourceFiles) {
          if (file.size == null && file.sourceDocumentUri != null) continue;
          if (file.size == null || file.size! < 0) {
            return Result.failure(
              AppError.file(
                '選択したファイルの容量を確認できません。読み込み直してお試しください',
              ).withAdditionalData(snapshot().toMap()),
            );
          }
          totalBytes += file.size!;
        }
        if (totalBytes > ImportSafetyPolicy.maxTotalBytes) {
          return Result.failure(
            AppError.file(
              '取り込み可能な容量を超えています',
            ).withAdditionalData(snapshot().toMap()),
          );
        }
      }

      final directories = selectedNodes
          .where((node) => node.isDirectory && _canImportDirectoryNode(node))
          .toList();
      final roots = _normalizeImportTargets(
        directories,
      ).where(_canImportDirectoryNode).toList();
      for (final root in roots) {
        final rootPath = _normalizePath(root.relativePath);
        final paths = pending
            .where(
              (path) =>
                  _isDescendantPath(ancestorPath: rootPath, targetPath: path),
            )
            .map((path) => _rebasePath(path, rootPath))
            .toSet();
        if (paths.isEmpty) continue;
        final resume = destinations
            .where(
              (item) =>
                  item.sourcePath == rootPath ||
                  _isDescendantPath(
                    ancestorPath: rootPath,
                    targetPath: item.sourcePath,
                  ),
            )
            .map(
              (item) => ImportCommittedItem(
                id: item.id,
                uid: item.uid,
                path: item.path,
                sourcePath: _rebasePath(item.sourcePath, rootPath),
                isFolder: true,
                isCatalog: item.isCatalog,
              ),
            )
            .toList();
        final result = await _importService.importFolder(
          root.uri,
          maxBytes: ImportSafetyPolicy.maxTotalBytes - committedBytes(),
          targetParentPath: targetParentPath,
          isCatalog: root.isCatalog,
          registerChildFolders: false,
          catalogMode: catalogMode,
          catalogOverridesByRelativePath: _buildCatalogOverridesForRoot(
            root: root,
            selectedDirectories: directories,
          ),
          selectedRelativePaths: paths,
          resumeDestinations: resume,
          sourceName: root.sourceTreeUri == null ? null : root.name,
          sourceEntries: root.sourceTreeUri == null
              ? null
              : _sourceEntries(root),
          onProgress: onProgress,
        );
        if (result is Failure<ImportExecutionReport, AppError>) {
          return failure(result.error, rootPath: rootPath);
        }
        consume(
          (result as Success<ImportExecutionReport, AppError>).data,
          rootPath: rootPath,
        );
        if (cancelled) return Result.success(snapshot());
      }
      final filesByCatalogState = <bool, List<File>>{};
      var documentBytes = committedBytes();
      for (final node in selectedFiles) {
        if (!pending.contains(node.relativePath) ||
            _isCoveredByImportRoot(node, roots)) {
          continue;
        }
        if (node.sourceDocumentUri != null) {
          final result = await _importService.importContentFile(
            node.uri,
            MediaFormatUtils.importName(node.name, node.mimeType),
            node.relativePath,
            expectedBytes: node.size,
            maxBytes: ImportSafetyPolicy.maxTotalBytes - documentBytes,
            onMeasuredBytes: (bytes) => documentBytes += bytes,
            targetParentPath: targetParentPath,
            isCatalog: node.isCatalog,
            onProgress: onProgress,
          );
          if (result is Failure<ImportExecutionReport, AppError>) {
            return failure(result.error);
          }
          consume((result as Success<ImportExecutionReport, AppError>).data);
          if (cancelled) return Result.success(snapshot());
          continue;
        }
        if (node.sourceTreeUri != null &&
            (node.uri.scheme == 'content' || node.uri.scheme == 'file')) {
          final importDocument = node.uri.scheme == 'file'
              ? _importService.importDeviceFile
              : _importService.importContentFile;
          final result = await importDocument(
            node.uri,
            node.name,
            node.relativePath,
            expectedBytes: node.size,
            maxBytes: ImportSafetyPolicy.maxTotalBytes - documentBytes,
            onMeasuredBytes: (bytes) => documentBytes += bytes,
            targetParentPath: targetParentPath,
            isCatalog: node.isCatalog,
            onProgress: onProgress,
          );
          if (result is Failure<ImportExecutionReport, AppError>) {
            return failure(result.error);
          }
          consume((result as Success<ImportExecutionReport, AppError>).data);
          if (cancelled) return Result.success(snapshot());
          continue;
        }
        if (node.uri.scheme != 'file' ||
            !await File.fromUri(node.uri).exists()) {
          failures.add(
            ImportFailureDetail(
              path: node.relativePath,
              displayName: node.name,
              reason: ImportFailureReasonCode.file,
            ),
          );
          continue;
        }
        filesByCatalogState
            .putIfAbsent(node.isCatalog, () => [])
            .add(File.fromUri(node.uri));
      }
      for (final entry in filesByCatalogState.entries) {
        final result = await _importService.importFiles(
          entry.value,
          targetParentPath: targetParentPath,
          isCatalog: entry.key,
          onProgress: onProgress,
        );
        if (result is Failure<ImportExecutionReport, AppError>) {
          return failure(result.error);
        }
        consume((result as Success<ImportExecutionReport, AppError>).data);
        if (cancelled) break;
      }
      return Result.success(snapshot());
    } catch (error, stack) {
      retryBlocked = true;
      return Result.failure(
        AppError.unknown(
          '高度なインポートに失敗しました',
          original: error,
          stackTrace: stack,
        ).withAdditionalData(snapshot().toMap()),
      );
    }
  }

  List<ExternalFileInfo> _sourceEntries(FileTreeNode root) {
    final entries = <ExternalFileInfo>[];
    void visit(FileTreeNode node) {
      if (!node.includeInImport) return;
      entries.add(
        ExternalFileInfo(
          uri: '${node.uri}',
          name: node.name,
          relativePath: _rebasePath(node.relativePath, root.relativePath),
          isDirectory: node.isDirectory,
          isMedia: !node.isDirectory && node.isMedia,
          size: node.size,
          mimeType: node.mimeType,
        ),
      );
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in root.children) {
      visit(child);
    }
    return entries;
  }

  List<FileTreeNode> _normalizeImportTargets(List<FileTreeNode> selectedNodes) {
    final sortedNodes = selectedNodes.toList()
      ..sort((a, b) {
        final depthDiff =
            _pathDepth(a.relativePath) - _pathDepth(b.relativePath);
        if (depthDiff != 0) return depthDiff;
        return _normalizePath(
          a.relativePath,
        ).compareTo(_normalizePath(b.relativePath));
      });

    final normalized = <FileTreeNode>[];
    final acceptedPaths = <String>[];
    final importedUris = <String>{};

    for (final node in sortedNodes) {
      final normalizedPath = _normalizePath(node.relativePath);
      final hasAncestor = acceptedPaths.any(
        (ancestorPath) => _isDescendantPath(
          ancestorPath: ancestorPath,
          targetPath: normalizedPath,
        ),
      );
      if (hasAncestor) continue;

      final uriKey = node.uri.toString();
      if (importedUris.contains(uriKey)) continue;

      acceptedPaths.add(normalizedPath);
      importedUris.add(uriKey);
      normalized.add(node);
    }

    return normalized;
  }

  Map<String, bool> _buildCatalogOverridesForRoot({
    required FileTreeNode root,
    required List<FileTreeNode> selectedDirectories,
  }) {
    final overrides = <String, bool>{};
    final rootPath = _normalizePath(root.relativePath);
    overrides[''] = root.isCatalog;

    for (final node in selectedDirectories) {
      final nodePath = _normalizePath(node.relativePath);
      if (!_isDescendantPath(ancestorPath: rootPath, targetPath: nodePath)) {
        continue;
      }
      final rebased = _rebasePath(nodePath, rootPath);
      overrides[rebased] = node.isCatalog;
    }

    return overrides;
  }

  int _pathDepth(String path) {
    final normalized = _normalizePath(path);
    if (normalized.isEmpty) return 0;
    return normalized.split('/').length;
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  bool _isDescendantPath({
    required String ancestorPath,
    required String targetPath,
  }) {
    if (ancestorPath.isEmpty) return targetPath.isNotEmpty;
    if (targetPath.isEmpty) return false;
    if (ancestorPath == targetPath) return true;
    return targetPath.startsWith('$ancestorPath/');
  }

  String _rebasePath(String path, String rootPath) {
    if (rootPath.isEmpty) return path;
    if (path == rootPath) return '';
    return path.substring(rootPath.length + 1);
  }

  bool _canImportDirectoryNode(FileTreeNode node) {
    final scheme = node.uri.scheme.toLowerCase();
    return scheme == 'content' || scheme == 'file';
  }

  bool _isCoveredByImportRoot(FileTreeNode fileNode, List<FileTreeNode> roots) {
    final targetPath = _normalizePath(fileNode.relativePath);
    return roots.any((root) {
      final rootPath = _normalizePath(root.relativePath);
      return _isDescendantPath(ancestorPath: rootPath, targetPath: targetPath);
    });
  }
}
