import '../../../device_files/data/device_storage.dart';
import '../../../device_files/domain/device_file.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../data/services/external_storage_service.dart';
import '../../data/services/import_source_browser.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/application/use_cases/scan_directory_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/internal_import_service_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:uuid/uuid.dart';
import '../../domain/models/selected_document.dart';
import '../../domain/models/import_source.dart' show sharesImportGrant;
import '../helpers/system_file_picker.dart' as system_picker;

part 'import_flow_provider.g.dart';

enum ImportFlowStatus {
  idle,
  scanning,
  confirming,
  importing,
  completed,
  error,
}

class ImportFlowState {
  final ImportFlowStatus status;
  final FileTreeNode? rootNode;
  final AppError? error;
  final String? targetParentPath;
  final ImportExecutionReport? importReport;
  final ImportCatalogMode catalogMode;
  final Set<Uri> ownedGrants;

  ImportFlowState({
    this.status = ImportFlowStatus.idle,
    this.rootNode,
    this.error,
    this.targetParentPath,
    this.importReport,
    this.catalogMode = ImportCatalogMode.folder,
    this.ownedGrants = const {},
  });

  ImportFlowState copyWith({
    ImportFlowStatus? status,
    FileTreeNode? rootNode,
    AppError? error,
    String? targetParentPath,
    ImportExecutionReport? importReport,
    bool clearError = false,
    bool clearImportReport = false,
    ImportCatalogMode? catalogMode,
    Set<Uri>? ownedGrants,
  }) {
    return ImportFlowState(
      status: status ?? this.status,
      rootNode: rootNode ?? this.rootNode,
      error: clearError ? null : (error ?? this.error),
      targetParentPath: targetParentPath ?? this.targetParentPath,
      importReport: clearImportReport
          ? null
          : (importReport ?? this.importReport),
      catalogMode: catalogMode ?? this.catalogMode,
      ownedGrants: ownedGrants ?? this.ownedGrants,
    );
  }

  /// 親を含む選択経路上に、取り込み対象が1件以上あるか。
  bool get hasImportSelection {
    final root = rootNode;
    if (root == null) return false;

    bool visit(FileTreeNode node, {required bool parentEnabled}) {
      if (!parentEnabled || !node.includeInImport) return false;
      if (node.children.isEmpty) return true;
      return true;
    }

    return visit(root, parentEnabled: true);
  }
}

@Riverpod(keepAlive: true)
class ImportFlowNotifier extends _$ImportFlowNotifier {
  Future<void> _draftWrites = Future<void>.value();
  int _selectionGeneration = 0;
  Set<Uri> _sessionGrants = {};
  static const pendingGrantReleasesKey =
      system_picker.systemFilePickerGrantReleasesKey;

  Future<void> _protectGrants(Set<Uri> grants) async {
    if (_sessionGrants.isEmpty && grants.isEmpty) return;
    final previous = _sessionGrants;
    _sessionGrants = Set.of(grants);
    final storage = await ref.read(externalStorageServiceProvider.future);
    storage.activeImportGrants.removeAll(previous.difference(_sessionGrants));
    storage.activeImportGrants.addAll(grants.intersection(_sessionGrants));
  }

  // Record cleanup before releasing access; a failed release remains retryable.
  Future<void> _releaseGrants(Set<Uri> grants) => _enqueueDraftWrite(() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = (prefs.getStringList(pendingGrantReleasesKey) ?? []).toSet()
      ..addAll(grants.map((uri) => '$uri'));
    if (pending.isEmpty) return;
    if (!await prefs.setStringList(pendingGrantReleasesKey, pending.toList())) {
      throw StateError('Could not record pending import access cleanup');
    }
    final storage = await ref.read(externalStorageServiceProvider.future);
    for (final value in pending.toList()) {
      final uri = Uri.parse(value);
      if (_sessionGrants.any((grant) => sharesImportGrant(uri, grant))) {
        continue;
      }
      try {
        await storage.releasePersistedAccess(uri);
        if (_sessionGrants.any((grant) => sharesImportGrant(uri, grant))) {
          continue;
        }
        // The picker may append another abandoned grant while release awaits.
        // Remove only this entry from the latest journal, never its new entries.
        final remaining =
            (prefs.getStringList(pendingGrantReleasesKey) ?? []).toSet()
              ..remove(value);
        if (!await prefs.setStringList(
          pendingGrantReleasesKey,
          remaining.toList(),
        )) {
          throw StateError('Could not record completed import access cleanup');
        }
      } catch (error, stack) {
        AppLogger.w(LogTag.storage, '取り込み元の権限解放を次回再試行します', error, stack);
      }
    }
  });

  int _startSelection() {
    if (state.status == ImportFlowStatus.importing) {
      throw StateError('Import already running');
    }
    return ++_selectionGeneration;
  }

  Future<Set<Uri>> _beginSelection({
    required int generation,
    required Set<Uri> grants,
    required Set<Uri> owned,
  }) async {
    final previous = state.ownedGrants;
    final nextOwned = {...owned, ...previous.intersection(grants)};
    state = ImportFlowState(
      status: ImportFlowStatus.scanning,
      ownedGrants: Set.unmodifiable(nextOwned),
    );
    await _protectGrants(grants);
    await _clearDraftSession(generation, recordAbandonedGrants: true);
    await _releaseGrants(previous.difference(grants));
    return Set.unmodifiable(nextOwned);
  }

  Future<int?> _adoptSelection(Set<Uri> grants, Set<Uri> owned) async {
    final int generation;
    try {
      generation = _startSelection();
    } catch (error, stack) {
      // A rejected picker must leave the running import untouched.
      try {
        await _releaseGrants(owned);
      } catch (cleanupError, cleanupStack) {
        AppLogger.w(
          LogTag.storage,
          '取り込み元の権限を回収できませんでした',
          cleanupError,
          cleanupStack,
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
    final cleanupGrants = {...state.ownedGrants, ...owned};
    try {
      await _beginSelection(
        generation: generation,
        grants: grants,
        owned: owned,
      );
      return generation == _selectionGeneration ? generation : null;
    } catch (error, stack) {
      if (generation == _selectionGeneration) {
        state = ImportFlowState(
          status: ImportFlowStatus.error,
          error: AppError.file(
            '取り込み元を準備できませんでした',
            original: error,
            stackTrace: stack,
          ),
          ownedGrants: Set.unmodifiable(cleanupGrants),
        );
      }
      try {
        await _finishOwnedGrants(generation: generation, owned: cleanupGrants);
      } catch (cleanupError, cleanupStack) {
        AppLogger.w(
          LogTag.storage,
          '取り込み元の権限解放を次回再試行します',
          cleanupError,
          cleanupStack,
        );
      }
      return null;
    }
  }

  Future<void> _finishOwnedGrants({
    required int generation,
    required Set<Uri> owned,
  }) async {
    try {
      try {
        if (generation == _selectionGeneration) {
          state = state.copyWith(ownedGrants: const {});
          await _protectGrants({});
        }
      } finally {
        await _releaseGrants(owned);
      }
    } catch (_) {
      if (generation == _selectionGeneration) {
        state = state.copyWith(ownedGrants: Set.unmodifiable(owned));
      }
      rethrow;
    }
  }

  Future<void> _enqueueDraftWrite(Future<void> Function() write) {
    final next = _draftWrites.then((_) => write());
    _draftWrites = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        AppLogger.w(LogTag.ui, 'インポート下書きの保存処理に失敗しました', error, stack);
      },
    );
    return next;
  }

  @override
  ImportFlowState build() {
    return ImportFlowState();
  }

  /// 状態を明示的にリセットする
  Future<void> reset() async {
    final generation = ++_selectionGeneration;
    final owned = state.ownedGrants;
    state = ImportFlowState();
    var cleanupFailed = false;
    try {
      await _protectGrants({});
    } catch (error, stack) {
      cleanupFailed = true;
      AppLogger.w(LogTag.storage, '取り込み元の権限保護を解除できませんでした', error, stack);
    } finally {
      try {
        await _clearDraftSession(generation, recordAbandonedGrants: true);
      } catch (error, stack) {
        cleanupFailed = true;
        AppLogger.w(LogTag.storage, '取り込み下書きの権限回収を記録できませんでした', error, stack);
      } finally {
        try {
          await _releaseGrants(owned);
        } catch (error, stack) {
          cleanupFailed = true;
          AppLogger.w(LogTag.storage, '取り込み元の権限解放を次回再試行します', error, stack);
        }
      }
    }
    if (cleanupFailed && generation == _selectionGeneration) {
      state = state.copyWith(ownedGrants: Set.unmodifiable(owned));
    }
  }

  void retryFailedItems() {
    final rootNode = state.rootNode;
    final report = state.importReport;
    if (rootNode == null ||
        report == null ||
        report.retryBlocked ||
        (report.pendingSourcePaths.isEmpty && report.failedEntries.isEmpty)) {
      return;
    }

    // Old reports have no destination identity. Do not silently replay a
    // partially committed import whose destination cannot be verified.
    if (report.sessionId == null) return;
    final failedPaths = report.pendingSourcePaths.map(_normalizePath).toSet();

    state = state.copyWith(
      status: ImportFlowStatus.confirming,
      rootNode: _buildRetryTree(rootNode, failedPaths),
      clearError: true,
    );
    unawaited(_persistDraftSession());
  }

  /// ディレクトリのスキャンを開始する
  Future<void> startScan(
    Uri uri, {
    String? targetParentPath,
    bool ownsGrant = false,
  }) async {
    final generation = await _adoptSelection({uri}, ownsGrant ? {uri} : {});
    if (generation == null || generation != _selectionGeneration) return;
    final owned = state.ownedGrants;
    state = ImportFlowState(
      status: ImportFlowStatus.scanning,
      targetParentPath: targetParentPath,
      ownedGrants: owned,
    );

    try {
      final scanUseCase = await ref.read(scanDirectoryUseCaseProvider.future);
      final result = await scanUseCase.invoke(uri);
      if (generation != _selectionGeneration) return;

      result.when(
        success: (rootNode) {
          final normalizedRoot = _applyCatalogMode(
            rootNode,
            ImportCatalogMode.folder,
          );
          AppLogger.d(
            LogTag.ui,
            'スキャン成功: ルートノード ${rootNode.name}, 子ノード数: ${rootNode.children.length}',
          );
          state = state.copyWith(
            status: ImportFlowStatus.confirming,
            rootNode: normalizedRoot,
            catalogMode: ImportCatalogMode.folder,
          );
        },
        failure: (error) {
          AppLogger.e(LogTag.ui, 'スキャン失敗: ${error.message}');
          state = state.copyWith(status: ImportFlowStatus.error, error: error);
          unawaited(_clearDraftSession(generation));
        },
      );
      if (state.status == ImportFlowStatus.confirming) {
        await _persistDraftSession(requireSuccess: true);
      }
    } catch (e, st) {
      if (generation != _selectionGeneration) return;
      AppLogger.e(LogTag.ui, 'スキャン処理中に例外が発生しました', e, st);
      state = state.copyWith(
        status: ImportFlowStatus.error,
        error: AppError.unknown('スキャン中に例外が発生しました', original: e, stackTrace: st),
      );
      unawaited(_clearDraftSession(generation));
    }
    if (generation == _selectionGeneration &&
        state.status == ImportFlowStatus.error) {
      await _finishOwnedGrants(generation: generation, owned: owned);
    }
  }

  Future<void> startFilesScan(
    List<String> filePaths, {
    String? targetParentPath,
  }) async {
    final generation = await _adoptSelection({}, {});
    if (generation == null || generation != _selectionGeneration) return;
    final uniquePaths = filePaths.toSet().toList();

    final rootNode = FileTreeNode(
      name: '選択ファイル',
      uri: Uri.parse('private-shelf://selected-files'),
      relativePath: '',
      isDirectory: true,
      isExpanded: true,
      includeInImport: true,
      isCatalog: false,
      isMedia: true,
    );

    final children = uniquePaths.map((path) {
      int? size;
      try {
        final file = File(path);
        if (file.existsSync()) {
          size = file.lengthSync();
        }
      } catch (e) {
        AppLogger.w(LogTag.storage, 'ファイルサイズの取得に失敗: $path, $e');
      }
      return FileTreeNode(
        name: p.basename(path),
        uri: Uri.file(path),
        relativePath: path,
        isDirectory: false,
        includeInImport: true,
        isCatalog: true,
        isMedia:
            !MediaFormatUtils.isIgnoredFile(path) &&
            MediaFormatUtils.allSupportedExtensions.contains(
              p.extension(path).toLowerCase(),
            ),
        size: size,
      );
    }).toList();

    state = ImportFlowState(
      status: ImportFlowStatus.confirming,
      targetParentPath: targetParentPath,
      rootNode: rootNode.copyWith(children: children),
    );
    unawaited(_persistDraftSession());
  }

  /// Build confirmation metadata without copying any selected document.
  Future<void> startDocumentsScan(
    List<SelectedDocument> documents, {
    String? targetParentPath,
  }) async {
    final unique = {for (final document in documents) document.uri: document};
    if (unique.isEmpty) return;
    final grants = unique.keys.toSet();
    final owned = documents
        .where((document) => document.ownsGrant)
        .map((document) => document.uri)
        .toSet();
    final generation = await _adoptSelection(grants, owned);
    if (generation == null || generation != _selectionGeneration) return;
    final adopted = state.ownedGrants;
    final children = unique.values
        .map(
          (document) => FileTreeNode(
            name: document.name,
            uri: document.uri,
            sourceDocumentUri: document.uri,
            // A private selection key: names and provider paths are not identities.
            relativePath: const Uuid().v4(),
            isDirectory: false,
            size: document.size,
            mimeType: document.mimeType,
            isMedia:
                MediaFormatUtils.supportedMimeExtension(
                  document.name,
                  document.mimeType,
                ) !=
                null,
            isCatalog: true,
          ),
        )
        .toList();
    state = ImportFlowState(
      status: ImportFlowStatus.confirming,
      targetParentPath: targetParentPath,
      ownedGrants: adopted,
      rootNode: FileTreeNode(
        name: '選択ファイル',
        uri: Uri.parse('private-shelf://selected-documents'),
        relativePath: '',
        isDirectory: true,
        isExpanded: true,
        isMedia: children.any((node) => node.isMedia),
        children: children,
      ),
    );
    try {
      await _persistDraftSession(requireSuccess: true);
    } catch (error, stack) {
      if (generation != _selectionGeneration) return;
      state = state.copyWith(
        status: ImportFlowStatus.error,
        error: AppError.file(
          '取り込み下書きを保存できませんでした',
          original: error,
          stackTrace: stack,
        ),
      );
      await _finishOwnedGrants(generation: generation, owned: adopted);
    }
  }

  Future<void> startSourceSelection(
    FileTreeNode selection, {
    String? targetParentPath,
  }) async {
    final generation = await _adoptSelection({}, {});
    if (generation == null || generation != _selectionGeneration) return;
    state = ImportFlowState(
      status: ImportFlowStatus.confirming,
      rootNode: selection,
      targetParentPath: targetParentPath,
    );
    await _persistDraftSession();
  }

  /// ツリーを展開/折りたたむ
  void toggleExpanded(String relativePath) {
    if (state.rootNode == null) return;

    final newRoot = _updateNode(state.rootNode!, relativePath, (node) {
      return node.copyWith(isExpanded: !node.isExpanded);
    });

    if (newRoot != null) {
      state = state.copyWith(rootNode: newRoot);
      unawaited(_persistDraftSession());
    }
  }

  /// インポート対象に含めるかどうかを切り替える
  void toggleImportSelection(String relativePath) {
    if (state.rootNode == null) return;

    final newRoot = _updateNode(state.rootNode!, relativePath, (node) {
      final newValue = !node.includeInImport;
      if (node.isDirectory) {
        return _nodeWithRecursiveImportSelection(node, newValue);
      }
      return node.copyWith(includeInImport: newValue);
    });

    if (newRoot != null) {
      state = state.copyWith(rootNode: newRoot);
      unawaited(_persistDraftSession());
    }
  }

  /// すべての項目の選択状態を一括設定する
  void setAllImportSelection(bool include) {
    if (state.rootNode == null) return;
    final newRoot = _nodeWithRecursiveImportSelection(state.rootNode!, include);
    state = state.copyWith(rootNode: newRoot);
    unawaited(_persistDraftSession());
  }

  /// すべてのフォルダの展開状態を一括設定する
  void setAllExpanded(bool expanded) {
    if (state.rootNode == null) return;
    final newRoot = _nodeWithRecursiveExpanded(state.rootNode!, expanded);
    state = state.copyWith(rootNode: newRoot);
    unawaited(_persistDraftSession());
  }

  FileTreeNode _nodeWithRecursiveExpanded(FileTreeNode node, bool expanded) {
    final newChildren = node.children
        .map((child) => _nodeWithRecursiveExpanded(child, expanded))
        .toList();
    return node.copyWith(
      isExpanded: node.isDirectory ? expanded : node.isExpanded,
      children: newChildren,
    );
  }

  FileTreeNode _nodeWithRecursiveImportSelection(
    FileTreeNode node,
    bool includeInImport,
  ) {
    final newChildren = node.children
        .map(
          (child) => _nodeWithRecursiveImportSelection(child, includeInImport),
        )
        .toList();
    return node.copyWith(
      includeInImport: includeInImport,
      children: newChildren,
    );
  }

  /// カタログ登録状態を変更する
  void updateCatalogRegistration(String relativePath, bool isCatalog) {
    if (state.rootNode == null) return;

    final newRoot = _updateNode(state.rootNode!, relativePath, (node) {
      return node.copyWith(isCatalog: isCatalog);
    });

    if (newRoot != null) {
      state = state.copyWith(rootNode: newRoot);
      unawaited(_persistDraftSession());
    }
  }

  /// フォルダ取り込みのカタログ化方針を変更し、ツリーへ再適用する。
  /// 詳細設定から戻った場合も同じ規則で再現できるよう、モードを下書きに保存する。
  void setCatalogMode(ImportCatalogMode mode) {
    if (state.importReport?.hasCommittedFiles == true) return;
    final root = state.rootNode;
    if (root == null || root.uri.scheme == 'private-shelf') return;
    final newRoot = _applyCatalogMode(root, mode);
    state = state.copyWith(rootNode: newRoot, catalogMode: mode);
    unawaited(_persistDraftSession());
  }

  FileTreeNode _applyCatalogMode(
    FileTreeNode node,
    ImportCatalogMode mode, {
    bool sourceTopLevel = false,
  }) {
    final syntheticSource =
        node.sourceTreeUri != null && node.uri.scheme == 'private-shelf';
    final shouldCatalog = mode == ImportCatalogMode.folder
        ? !syntheticSource &&
              (node.relativePath.isEmpty || sourceTopLevel) &&
              node.isDirectory
        : !node.isDirectory && node.isMedia;
    return node.copyWith(
      isCatalog: shouldCatalog,
      children: node.children
          .map(
            (child) =>
                _applyCatalogMode(child, mode, sourceTopLevel: syntheticSource),
          )
          .toList(growable: false),
    );
  }

  /// インポートを実行する
  Future<void> executeImport() async {
    if (state.rootNode == null || state.status != ImportFlowStatus.confirming) {
      return;
    }

    final selectedNodes = <FileTreeNode>[];
    // ルートは常に有効として走査開始
    _collectSelectedNodes(state.rootNode!, selectedNodes, parentEnabled: true);
    if (selectedNodes.isEmpty) return;

    final generation = _selectionGeneration;
    final selection = state;
    final ownedGrants = Set<Uri>.of(selection.ownedGrants);
    final previousReport = state.importReport;
    ref.read(syncProgressNotifierProvider.notifier).reset();
    state = state.copyWith(
      status: ImportFlowStatus.importing,
      clearError: true,
      clearImportReport: true,
    );

    ExternalStorageService? sourceStorage;
    final sourceGrants = selectedNodes
        .expand((n) => [n.sourceTreeUri, n.sourceDocumentUri])
        .whereType<Uri>()
        .toSet();
    try {
      if (sourceGrants.isNotEmpty) {
        sourceStorage = await ref.read(externalStorageServiceProvider.future);
        sourceStorage!.activeImportGrants.addAll(sourceGrants);
        final browser = ref.read(importSourceBrowserProvider);
        for (final grant in sourceGrants) {
          if (selectedNodes.any((node) => node.sourceDocumentUri == grant)) {
            if (await saf.canRead(grant) != true) {
              throw StateError('Selected document access was revoked');
            }
          } else if (grant.scheme == 'file') {
            final device = ref.read(deviceStorageProvider);
            final deviceNodes = selectedNodes
                .where(
                  (n) => n.sourceTreeUri == grant && n.uri.scheme == 'file',
                )
                .toList();
            if (deviceNodes.any((n) => n.sourceIdentity == null)) {
              throw StateError('Device source identity is missing');
            }
            await device.validate(
              deviceNodes
                  .map(
                    (n) => DeviceFile(
                      uri: n.uri,
                      identity: n.sourceIdentity!,
                      name: n.name,
                      directory: n.isDirectory,
                      size: n.size,
                    ),
                  )
                  .toList(),
            );
          } else {
            await browser.root(grant);
          }
        }
      }
      if (generation != _selectionGeneration) return;
      // Invalidate the replayable confirmation before any storage mutation.
      // After process death the destination state must be checked, not replayed.
      final marker = jsonEncode({
        'version': 5,
        'status': ImportFlowStatus.importing.name,
        'rootNode': selection.rootNode!.toMap(),
        'targetParentPath': selection.targetParentPath,
        'catalogMode': selection.catalogMode.name,
        'importReport': previousReport?.toMap(),
        'ownedGrants': ownedGrants.map((uri) => '$uri').toList(),
      });
      await _enqueueDraftWrite(() async {
        if (generation != _selectionGeneration) return;
        final draftPrefs = await SharedPreferences.getInstance();
        if (generation != _selectionGeneration) return;
        final marked = await draftPrefs.setString(
          AppPreferences.importFlowDraftSessionKey,
          marker,
        );
        if (!marked) {
          throw StateError('Could not protect import recovery state');
        }
      });
      if (generation != _selectionGeneration) return;
      // Retain the async factory and the Ref captured by its returned service.
      // A listener keeps them alive without rebuilding this notifier.
      final importSubscription = ref.listen(
        advancedImportUseCaseProvider,
        (_, _) {},
      );
      final Result<ImportExecutionReport, AppError> result;
      try {
        final importUseCase = await ref.read(
          advancedImportUseCaseProvider.future,
        );
        if (generation != _selectionGeneration) return;
        result = await importUseCase.invoke(
          selectedNodes,
          previousReport: previousReport,
          targetParentPath: selection.targetParentPath,
          catalogMode: selection.catalogMode,
          onProgress: (progress) {
            if (generation != _selectionGeneration) return;
            ref
                .read(syncProgressNotifierProvider.notifier)
                .updateProgress(progress);
          },
        );
      } finally {
        importSubscription.close();
      }

      if (generation != _selectionGeneration) return;
      result.when(
        success: (report) {
          ref.invalidate(libraryViewModelProvider);
          ref.invalidate(recentMediaProvider);
          state = state.copyWith(
            status: ImportFlowStatus.completed,
            importReport: report,
          );
        },
        failure: (error) {
          final report = _reportFromError(error);
          state = state.copyWith(
            status: ImportFlowStatus.error,
            error: error,
            importReport: report,
            clearImportReport: report == null,
          );
        },
      );
      if (generation != _selectionGeneration) return;
      final report = state.importReport;
      if (report != null &&
          !report.isCancelled &&
          !report.hasPartialFailure &&
          !report.retryBlocked) {
        await _finishOwnedGrants(generation: generation, owned: ownedGrants);
        await _clearDraftSession(generation);
      } else {
        await _persistDraftSession(requireSuccess: true);
      }
    } catch (e, st) {
      if (generation != _selectionGeneration) return;
      state = state.copyWith(
        status: ImportFlowStatus.error,
        error: AppError.unknown(
          'インポート中に例外が発生しました',
          original: e,
          stackTrace: st,
        ),
      );
      // Keep the importing marker when the final storage state is unknown.
    } finally {
      sourceStorage?.activeImportGrants.removeAll(
        sourceGrants.difference(_sessionGrants),
      );
      if (generation != _selectionGeneration) {
        await _releaseGrants(ownedGrants);
      }
    }
  }

  ImportExecutionReport? _reportFromError(AppError error) {
    final data = error.additionalData;
    if (data == null) return null;
    try {
      return ImportExecutionReport.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// 全ての選択されたノード（includeInImport == true かつ 親が有効）を抽出（再帰的）
  void _collectSelectedNodes(
    FileTreeNode node,
    List<FileTreeNode> result, {
    required bool parentEnabled,
  }) {
    // 親がOFFの場合、配下は全て無効
    if (!parentEnabled) return;

    if (node.includeInImport) {
      result.add(node);
    }

    final nextLevelEnabled = node.includeInImport;

    for (final child in node.children) {
      _collectSelectedNodes(child, result, parentEnabled: nextLevelEnabled);
    }
  }

  FileTreeNode _buildRetryTree(FileTreeNode node, Set<String> failedPaths) {
    final normalizedPath = _normalizePath(node.relativePath);
    final isFailedRoot =
        normalizedPath.isEmpty ||
        failedPaths.any(
          (failedPath) =>
              failedPath == normalizedPath ||
              failedPath.startsWith('$normalizedPath/'),
        );

    return node.copyWith(
      includeInImport: isFailedRoot,
      children: node.children
          .map((child) => _buildRetryTree(child, failedPaths))
          .toList(growable: false),
    );
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  Future<void> _persistDraftSession({bool requireSuccess = false}) {
    final generation = _selectionGeneration;
    final rootNode = state.rootNode;
    if (rootNode == null ||
        state.status == ImportFlowStatus.idle ||
        state.status == ImportFlowStatus.scanning ||
        state.status == ImportFlowStatus.importing) {
      return Future<void>.value();
    }
    // Capture before awaiting: a later selection/start must not mutate this write.
    final encoded = jsonEncode({
      'version': 5,
      'importReport': state.importReport?.toMap(),
      'status': state.status.name,
      'targetParentPath': state.targetParentPath,
      'catalogMode': state.catalogMode.name,
      'rootNode': rootNode.toMap(),
      'ownedGrants': state.ownedGrants.map((uri) => '$uri').toList(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return _enqueueDraftWrite(() async {
      try {
        if (generation != _selectionGeneration) return;
        final prefs = await SharedPreferences.getInstance();
        if (generation != _selectionGeneration) return;
        final saved = await prefs.setString(
          AppPreferences.importFlowDraftSessionKey,
          encoded,
        );
        if (!saved) {
          throw StateError('Could not save import recovery state');
        }
      } catch (e, st) {
        AppLogger.w(LogTag.ui, 'インポート下書きセッションの保存に失敗しました', e, st);
        if (requireSuccess) rethrow;
      }
    });
  }

  Future<void> _clearDraftSession(
    int generation, {
    bool recordAbandonedGrants = false,
  }) => _enqueueDraftWrite(() async {
    try {
      if (generation != _selectionGeneration) return;
      final prefs = await SharedPreferences.getInstance();
      if (generation != _selectionGeneration) return;
      if (recordAbandonedGrants) {
        final encoded = prefs.getString(
          AppPreferences.importFlowDraftSessionKey,
        );
        if (encoded != null) {
          Object? decoded;
          try {
            decoded = jsonDecode(encoded);
          } on FormatException {
            // A malformed draft has no recoverable ownership metadata.
            decoded = null;
          }
          final abandoned = decoded is Map ? decoded['ownedGrants'] : null;
          if (abandoned is List) {
            final pending =
                (prefs.getStringList(pendingGrantReleasesKey) ?? []).toSet()
                  ..addAll(
                    abandoned.whereType<String>().where(
                      (value) => Uri.tryParse(value)?.scheme == 'content',
                    ),
                  );
            if (pending.isNotEmpty &&
                !await prefs.setStringList(
                  pendingGrantReleasesKey,
                  pending.toList(),
                )) {
              throw StateError(
                'Could not record abandoned import access cleanup',
              );
            }
          }
        }
      }
      if (generation != _selectionGeneration) return;
      await prefs.remove(AppPreferences.importFlowDraftSessionKey);
    } catch (e, st) {
      AppLogger.w(LogTag.ui, 'インポート下書きセッションの削除に失敗しました', e, st);
      if (recordAbandonedGrants) rethrow;
    }
  });

  Future<void> _restoreDraftSession() async {
    final generation = _selectionGeneration;
    try {
      if (state.status != ImportFlowStatus.idle || state.rootNode != null) {
        return;
      }
      await _draftWrites;
      final prefs = await SharedPreferences.getInstance();
      if (generation != _selectionGeneration ||
          state.status != ImportFlowStatus.idle ||
          state.rootNode != null) {
        return;
      }
      final encoded = prefs.getString(AppPreferences.importFlowDraftSessionKey);
      if (encoded == null || encoded.isEmpty) return;

      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return;
      final rootMap = decoded['rootNode'];
      if (rootMap is! Map<String, dynamic>) return;

      final restoredRoot = FileTreeNode.fromMap(rootMap);
      final owned = (decoded['ownedGrants'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(Uri.parse)
          .toSet();
      final interrupted = decoded['status'] == ImportFlowStatus.importing.name;
      final restoredReport = decoded['importReport'] is Map<String, dynamic>
          ? ImportExecutionReport.fromMap(
              decoded['importReport'] as Map<String, dynamic>,
            )
          : null;
      state = ImportFlowState(
        status: interrupted
            ? ImportFlowStatus.error
            : ImportFlowStatus.confirming,
        error: interrupted ? AppError.file('取り込み中に中断されました') : null,
        rootNode: restoredRoot,
        ownedGrants: Set.unmodifiable(owned),
        importReport: interrupted
            ? (restoredReport ??
                      const ImportExecutionReport(
                        totalItems: 0,
                        processedItems: 0,
                        failedItems: 0,
                        failureThresholdCount: 5,
                      ))
                  .copyWith(retryBlocked: true)
            : restoredReport,
        targetParentPath: decoded['targetParentPath'] as String?,
        catalogMode: ImportCatalogMode.values.firstWhere(
          (mode) => mode.name == decoded['catalogMode'],
          orElse: () => ImportCatalogMode.folder,
        ),
      );
      final grants = <Uri>{...owned};
      void collect(FileTreeNode node) {
        if (node.sourceTreeUri != null) grants.add(node.sourceTreeUri!);
        if (node.sourceDocumentUri != null) grants.add(node.sourceDocumentUri!);
        for (final child in node.children) {
          collect(child);
        }
      }

      collect(restoredRoot);
      if (grants.isNotEmpty) await _protectGrants(grants);
      await _releaseGrants({});
      AppLogger.i(LogTag.ui, 'インポート下書きセッションを復元しました');
    } catch (e, st) {
      AppLogger.w(LogTag.ui, 'インポート下書きセッションの復元に失敗しました', e, st);
    }
  }

  Future<void> restoreDraftSession() => _restoreDraftSession();

  /// 特定のパスのノードを更新する（再帰的、不変更新）
  FileTreeNode? _updateNode(
    FileTreeNode node,
    String targetPath,
    FileTreeNode Function(FileTreeNode) update,
  ) {
    if (node.relativePath == targetPath) {
      return update(node);
    }

    final newChildren = <FileTreeNode>[];
    var updated = false;
    for (final child in node.children) {
      final newChild = _updateNode(child, targetPath, update);
      if (newChild != null) {
        newChildren.add(newChild);
        if (newChild != child) updated = true;
      }
    }

    if (updated) {
      return node.copyWith(children: newChildren);
    }
    return node;
  }
}
