import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:isar/isar.dart' hide Collection;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/core/services/storage_sandbox.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';

part 'sidecar_metadata_service.g.dart';

@Riverpod(keepAlive: true)
Future<SidecarMetadataService> sidecarMetadataService(
  Ref ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  final storageManager = ref.watch(localStorageManagerProvider);
  return SidecarMetadataService(isar, storageManager);
}

/// 専用フォルダ直下の `.tagshelf/metadata.json` と DB 間のメタデータ同期を行うサービス。
class SidecarMetadataService {
  final Isar _isar;
  final LocalStorageManager _storageManager;
  final Future<void> Function(File file) _deleteFile;
  final int _maxMetadataBytes;
  final int _maxRecordsPerType;

  SidecarMetadataService(
    this._isar,
    this._storageManager, {
    Future<void> Function(File file)? deleteFile,
    this._maxMetadataBytes = ImportSafetyPolicy.maxMetadataBytes,
    this._maxRecordsPerType = ImportSafetyPolicy.maxMetadataRecordsPerType,
  }) : _deleteFile = deleteFile ?? _deleteNormally;

  static const int currentSchemaVersion = 2;
  static const String legacyMigrationMarkerName =
      '.legacy_public_metadata_migrated';

  static Future<void> _deleteNormally(File file) => file.delete();

  /// 現在のDB状態（タグ、コレクション、アイテム設定）を `.tagshelf/metadata.json` にエクスポートして保存する。
  Future<Result<void, AppError>> exportMetadata() async {
    try {
      final tags = await _isar.tags.where().findAll();
      final collections = await _isar.mediaCollections.where().findAll();
      final mediaItems = await _isar.mediaItems.where().findAll();

      // タグIDからキーへの逆引きマップを作成（永続キー解決用）
      final tagIdToKey = <int, String>{for (final t in tags) t.id: t.key};

      final tagList = tags
          .map(
            (t) => {
              'key': t.key,
              'name': t.name,
              'facetId': t.facetId,
              'parentKey': t.parentId != null ? tagIdToKey[t.parentId] : null,
              'level': t.level,
              'colorValue': t.colorValue,
              'isHidden': t.isHidden,
              'createdAt': t.createdAt.toIso8601String(),
            },
          )
          .toList();

      // 各コレクションに関連付けられたタグを読み込み
      final collectionList = <Map<String, dynamic>>[];
      for (final col in collections) {
        if (col.path == 'library' ||
            col.path.isEmpty ||
            !_isUnderManagedRoot(col.path, const {'library', 'folders'})) {
          continue;
        }
        await col.tags.load();
        collectionList.add({
          'uid': col.uid,
          'title': col.title,
          'alias': col.alias,
          'relativePath': col.path,
          'isCatalog': col.isCatalog,
          'type': col.type.name,
          'tier': col.tier,
          'isFavorite': col.isFavorite,
          'isPinned': col.isPinned,
          'isArchived': col.isArchived,
          'isHidden': col.isHidden,
          'isTrashed': col.isTrashed,
          'trashRootPath': col.trashRootPath,
          'coverImagePath': col.coverImagePath,
          'defaultSortOrder': col.defaultSortOrder.name,
          'defaultViewMode': col.defaultViewMode.name,
          'splitSpreadView': col.splitSpreadView,
          'isHeaderExpanded': col.isHeaderExpanded,
          'notes': col.notes,
          'lastViewedAt': col.lastViewedAt?.toIso8601String(),
          'tagKeys': col.tags.map((t) => t.key).toList(),
          'createdAt': col.createdAt.toIso8601String(),
          'updatedAt': col.updatedAt.toIso8601String(),
        });
      }

      final itemList = mediaItems
          .where(
            (m) =>
                (m.isArchived || m.isHidden || m.isFavorite) &&
                _isUnderManagedRoot(m.path, const {'library', 'folders'}),
          )
          .map(
            (m) => {
              'uid': m.uid,
              'relativePath': m.path,
              'isArchived': m.isArchived,
              'isHidden': m.isHidden,
              'isFavorite': m.isFavorite,
              'addedAt': m.addedAt.toIso8601String(),
            },
          )
          .toList();

      final exportData = {
        'version': currentSchemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'tags': tagList,
        'collections': collectionList,
        'mediaItems': itemList,
      };

      final metaFile = await _storageManager.getMetadataFile();
      final metaDir = metaFile.parent;
      if (!await metaDir.exists()) {
        await metaDir.create(recursive: true);
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // アトミック書き込み: 一時ファイルに書き込んでからリプレース & バックアップ退避
      final tmpFile = File('${metaFile.path}.tmp');
      final bakFile = File('${metaFile.path}.bak');

      await tmpFile.writeAsString(jsonString, flush: true);

      if (await metaFile.exists()) {
        try {
          await metaFile.copy(bakFile.path);
        } catch (e) {
          AppLogger.w(LogTag.storage, 'メタデータバックアップ作成失敗 (継続します): $e');
        }
      }

      try {
        await tmpFile.rename(metaFile.path);
      } catch (_) {
        // Android共有ストレージ等で rename が失敗する場合は直接上書き
        await metaFile.writeAsString(jsonString, flush: true);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      }

      AppLogger.i(LogTag.storage, 'メタデータをサイドカーに保存しました: ${metaFile.path}');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.w(LogTag.storage, 'メタデータのエクスポートに失敗しました: $e', e, st);
      return Result.failure(
        AppError.file('メタデータの保存に失敗しました: $e', original: e, stackTrace: st),
      );
    }
  }

  /// `.tagshelf/metadata.json` からメタデータを読み込み、DBに反映・復元する。
  /// 検証したメタデータを私有一時ファイルへ固定し、検証後の差替えを防ぐ。
  Future<Result<File?, AppError>> stageValidatedImportMetadata({
    bool includeLegacy = false,
    File? recoveryMetadata,
  }) async {
    try {
      final metaFile = await _storageManager.getMetadataFile();
      final legacyMetaFile = includeLegacy
          ? await _storageManager.getLegacyMetadataFile()
          : null;
      final hasRecoveryMetadata =
          recoveryMetadata != null &&
          (await recoveryMetadata.exists() ||
              await File('${recoveryMetadata.path}.bak').exists());
      final candidates = <({File file, bool isLegacy})>[
        if (recoveryMetadata != null) ...[
          (file: recoveryMetadata, isLegacy: false),
          (file: File('${recoveryMetadata.path}.bak'), isLegacy: false),
        ],
        if (!hasRecoveryMetadata) ...[
          (file: metaFile, isLegacy: false),
          (file: File('${metaFile.path}.bak'), isLegacy: false),
        ],
        if (legacyMetaFile != null) ...[
          (file: legacyMetaFile, isLegacy: true),
          (file: File('${legacyMetaFile.path}.bak'), isLegacy: true),
        ],
      ];
      final rootDir = await _storageManager.getPrivateRootDirectory();
      var anyCandidateExists = false;
      Map<String, dynamic>? selected;
      var selectedIsLegacy = false;
      for (final candidate in candidates) {
        if (!await candidate.file.exists()) continue;
        anyCandidateExists = true;
        try {
          final parsed = await readValidatedDocument(
            candidate.file,
            maxBytes: _maxMetadataBytes,
            maxRecordsPerType: _maxRecordsPerType,
          );
          if (parsed != null) {
            await _validateDocumentPaths(parsed, rootDir);
            selected = parsed;
            selectedIsLegacy = candidate.isLegacy;
            if (_metadataEntryCount(parsed) > 0 || candidate.isLegacy) break;
          }
        } on Object {
          continue;
        }
      }
      if (selected != null) {
        final staging = await Directory.systemTemp.createTemp(
          'tagshelf_metadata_restore_',
        );
        final snapshot = File(p.join(staging.path, 'metadata.json'));
        await snapshot.writeAsString(jsonEncode(selected), flush: true);
        if (selectedIsLegacy) {
          final marker = File(
            p.join(metaFile.parent.path, legacyMigrationMarkerName),
          );
          await marker.parent.create(recursive: true);
          await marker.writeAsString('pending-cleanup', flush: true);
        }
        return Result.success(snapshot);
      }
      if (!anyCandidateExists) return Result.success(null);
      return Result.failure(AppError.file('メタデータファイルが破損しているため復元できません'));
    } catch (e, st) {
      return Result.failure(
        AppError.file('メタデータの事前検証に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  Future<Result<int, AppError>> importMetadata({
    bool preserveExistingTags = false,
    bool includeLegacy = false,
    File? recoveryMetadata,
  }) async {
    try {
      final metaFile = await _storageManager.getMetadataFile();
      final bakFile = File('${metaFile.path}.bak');
      final rootDir = await _storageManager.getPrivateRootDirectory();

      final legacyMetaFile = includeLegacy
          ? await _storageManager.getLegacyMetadataFile()
          : null;
      final hasRecoveryMetadata =
          recoveryMetadata != null &&
          (await recoveryMetadata.exists() ||
              await File('${recoveryMetadata.path}.bak').exists());
      final candidates = <({File file, bool isLegacy, bool isBackup})>[
        if (recoveryMetadata != null) ...[
          (file: recoveryMetadata, isLegacy: false, isBackup: false),
          (
            file: File('${recoveryMetadata.path}.bak'),
            isLegacy: false,
            isBackup: true,
          ),
        ],
        if (!hasRecoveryMetadata) ...[
          (file: metaFile, isLegacy: false, isBackup: false),
          (file: bakFile, isLegacy: false, isBackup: true),
        ],
        if (legacyMetaFile != null)
          (file: legacyMetaFile, isLegacy: true, isBackup: false),
        if (legacyMetaFile != null)
          (
            file: File('${legacyMetaFile.path}.bak'),
            isLegacy: true,
            isBackup: true,
          ),
      ];

      Map<String, dynamic>? decoded;
      ({File file, bool isLegacy, bool isBackup})? selectedSource;
      var anyCandidateExists = false;

      for (final candidate in candidates) {
        if (!await candidate.file.exists()) continue;
        anyCandidateExists = true;
        try {
          final parsed = await readValidatedDocument(
            candidate.file,
            maxBytes: _maxMetadataBytes,
            maxRecordsPerType: _maxRecordsPerType,
          );
          if (parsed != null) {
            await _validateDocumentPaths(parsed, rootDir);
            decoded = parsed;
            selectedSource = candidate;
            if (candidate.isBackup) {
              AppLogger.i(
                LogTag.storage,
                'metadata.json.bak からフォールバック復元を実行します',
              );
            }
            // 明示的な旧データ復元では、初期化直後に作られた空の私有
            // メタデータが実データ入りの旧公開サイドカーを隠さないようにする。
            if (_metadataEntryCount(parsed) > 0 || candidate.isLegacy) {
              break;
            }
          }
        } catch (e) {
          AppLogger.w(
            LogTag.storage,
            'メタデータ候補の解析に失敗しました。次の候補を確認します: '
            '${candidate.file.path}, $e',
          );
        }
      }

      if (decoded == null) {
        if (!anyCandidateExists) {
          AppLogger.i(LogTag.storage, 'メタデータファイルがないため実体ファイルのみ復元します');
          return Result.success(0);
        }
        return Result.failure(
          AppError.file(
            'メタデータファイルが破損しているため復元できません',
            context: 'SidecarMetadataService.importMetadata',
          ),
        );
      }

      final version = decoded['version'] as int? ?? 1;
      AppLogger.i(LogTag.storage, 'メタデータ読み込み開始 (Schema Version: $version)');

      final rawTags = decoded['tags'] as List<dynamic>;
      final rawCollections = decoded['collections'] as List<dynamic>;
      final rawItems = decoded['mediaItems'] as List<dynamic>;

      var restoredCount = 0;

      await _isar.writeTxn(() async {
        // -------------------------------------------------------------
        // 1. タグの復元（パス1: タグ実体の作成・更新）
        // -------------------------------------------------------------
        final keyToTag = <String, Tag>{};
        final preservedKeys = <String>{};
        for (final raw in rawTags) {
          if (raw is! Map<String, dynamic>) continue;
          final key = raw['key'] as String? ?? '';
          if (key.isEmpty) continue;

          var tag = await _isar.tags.where().keyEqualTo(key).findFirst();
          if (tag == null) {
            tag = Tag()
              ..key = key
              ..name = raw['name'] as String? ?? ''
              ..facetId = raw['facetId'] as int?
              ..level = raw['level'] as int? ?? 100
              ..colorValue = raw['colorValue'] as int?
              ..isHidden = raw['isHidden'] as bool? ?? false
              ..createdAt =
                  DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
                  DateTime.now();
            await _isar.tags.put(tag);
            restoredCount++;
          } else {
            if (preserveExistingTags) {
              keyToTag[key] = tag;
              preservedKeys.add(key);
              continue;
            }
            // 既存タグの属性をマージ
            tag.name = raw['name'] as String? ?? tag.name;
            tag.facetId = raw['facetId'] as int? ?? tag.facetId;
            tag.level = raw['level'] as int? ?? tag.level;
            tag.colorValue = raw['colorValue'] as int? ?? tag.colorValue;
            tag.isHidden = raw['isHidden'] as bool? ?? tag.isHidden;
            await _isar.tags.put(tag);
          }
          keyToTag[key] = tag;
        }

        // -------------------------------------------------------------
        // 2. タグ階層関係の復元（パス2: parentKey/parentId から親子・祖先解決）
        // -------------------------------------------------------------
        for (final raw in rawTags) {
          if (raw is! Map<String, dynamic>) continue;
          final key = raw['key'] as String? ?? '';
          if (key.isEmpty ||
              !keyToTag.containsKey(key) ||
              preservedKeys.contains(key)) {
            continue;
          }

          final tag = keyToTag[key]!;
          final parentKey = raw['parentKey'] as String?;

          if (parentKey != null && keyToTag.containsKey(parentKey)) {
            final parentTag = keyToTag[parentKey]!;
            tag.parentId = parentTag.id;
            tag.ancestorIds = [...parentTag.ancestorIds, parentTag.id];
          } else if (version == 1 && raw['parentId'] != null) {
            // v1 後方互換性（数値parentIdが指定されていた場合、該当IDが存在すれば設定）
            final legacyParentId = raw['parentId'] as int;
            final legacyParent = await _isar.tags.get(legacyParentId);
            if (legacyParent != null) {
              tag.parentId = legacyParent.id;
              tag.ancestorIds = [...legacyParent.ancestorIds, legacyParent.id];
            }
          }
          await _isar.tags.put(tag);
        }

        // -------------------------------------------------------------
        // 3. コレクション（カタログ）の復元/更新
        // -------------------------------------------------------------
        for (final raw in rawCollections) {
          if (raw is! Map<String, dynamic>) continue;
          var relPath = raw['relativePath'] as String? ?? '';
          if (relPath.isEmpty || relPath == 'library') continue;

          // 旧Welcome_DocBookのマイグレーション互換
          if (relPath == 'library/Welcome_DocBook') {
            final jaDir = Directory(
              p.join(rootDir.path, 'library/はじめてのCharmShelf'),
            );
            final enDir = Directory(
              p.join(rootDir.path, 'library/Getting Started with CharmShelf'),
            );
            if (jaDir.existsSync()) {
              relPath = 'library/はじめてのCharmShelf';
            } else if (enDir.existsSync()) {
              relPath = 'library/Getting Started with CharmShelf';
            }
          }

          // 物理フォルダが存在しない場合はDBに新規作成しない
          final colDir = Directory(p.join(rootDir.path, relPath));
          final dirExists =
              colDir.existsSync() ||
              (raw['type'] == 'file' && File(colDir.path).existsSync());

          final existingCol = await _isar.mediaCollections
              .where()
              .pathEqualTo(relPath)
              .findFirst();
          if (existingCol == null) {
            if (!dirExists) {
              continue;
            }

            var coverPath = raw['coverImagePath'] as String?;
            if (coverPath != null &&
                !File(p.join(rootDir.path, coverPath)).existsSync()) {
              coverPath = null;
            }

            final newCol = MediaCollection()
              ..uid = raw['uid'] as String?
              ..title = raw['title'] as String? ?? p.basename(relPath)
              ..alias = raw['alias'] as String?
              ..path = relPath
              ..isCatalog = raw['isCatalog'] == true
              ..type = CollectionType.values
                  .where((type) => type != CollectionType.externalFolder)
                  .firstWhere(
                    (t) => t.name == raw['type'],
                    orElse: () => CollectionType.folder,
                  )
              ..tier = raw['tier'] as int? ?? 0
              ..isFavorite = raw['isFavorite'] as bool? ?? false
              ..isPinned = raw['isPinned'] as bool? ?? false
              ..isArchived = raw['isArchived'] as bool? ?? false
              ..isHidden = raw['isHidden'] as bool? ?? false
              ..isTrashed = raw['isTrashed'] as bool? ?? false
              ..trashRootPath = raw['trashRootPath'] as String?
              ..coverImagePath = coverPath
              ..defaultSortOrder = SortOrder.values.firstWhere(
                (s) => s.name == raw['defaultSortOrder'],
                orElse: () => SortOrder.addedDesc,
              )
              ..defaultViewMode = ViewMode.values.firstWhere(
                (v) => v.name == raw['defaultViewMode'],
                orElse: () => ViewMode.list,
              )
              ..splitSpreadView = raw['splitSpreadView'] as bool? ?? false
              ..isHeaderExpanded = raw['isHeaderExpanded'] as bool? ?? true
              ..notes = raw['notes'] as String?
              ..lastViewedAt = DateTime.tryParse(
                raw['lastViewedAt'] as String? ?? '',
              )
              ..createdAt =
                  DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
                  DateTime.now()
              ..updatedAt =
                  DateTime.tryParse(raw['updatedAt'] as String? ?? '') ??
                  DateTime.now();

            await _isar.mediaCollections.put(newCol);
            restoredCount++;

            // タグの紐付け復元
            final tagKeys =
                (raw['tagKeys'] as List<dynamic>?)?.cast<String>() ?? [];
            newCol.tags.clear();
            for (final tk in tagKeys) {
              final tag =
                  keyToTag[tk] ??
                  await _isar.tags.where().keyEqualTo(tk).findFirst();
              if (tag != null) {
                newCol.tags.add(tag);
              }
            }
            await newCol.tags.save();
          } else {
            // Prepared legacy imports use isolated paths, including folders
            // already registered by the preceding file sync.
            if (preserveExistingTags) {
              existingCol.title = raw['title'] as String? ?? existingCol.title;
              existingCol.isCatalog = raw['isCatalog'] == true;
              existingCol.type = CollectionType.values
                  .where((type) => type != CollectionType.externalFolder)
                  .firstWhere(
                    (type) => type.name == raw['type'],
                    orElse: () => CollectionType.folder,
                  );
            }
            // 既存のコレクションにメタデータをマージ
            existingCol.alias = raw['alias'] as String? ?? existingCol.alias;
            existingCol.tier = raw['tier'] as int? ?? existingCol.tier;
            existingCol.isFavorite =
                raw['isFavorite'] as bool? ?? existingCol.isFavorite;
            existingCol.isPinned =
                raw['isPinned'] as bool? ?? existingCol.isPinned;
            existingCol.isArchived =
                raw['isArchived'] as bool? ?? existingCol.isArchived;
            existingCol.isHidden =
                raw['isHidden'] as bool? ?? existingCol.isHidden;
            existingCol.isTrashed =
                raw['isTrashed'] as bool? ?? existingCol.isTrashed;
            existingCol.trashRootPath =
                raw['trashRootPath'] as String? ?? existingCol.trashRootPath;

            final incomingCover = raw['coverImagePath'] as String?;
            if (incomingCover != null &&
                File(p.join(rootDir.path, incomingCover)).existsSync()) {
              existingCol.coverImagePath = incomingCover;
            } else if (existingCol.coverImagePath != null &&
                !File(
                  p.join(rootDir.path, existingCol.coverImagePath!),
                ).existsSync()) {
              existingCol.coverImagePath = null;
            }

            if (raw['defaultSortOrder'] != null) {
              existingCol.defaultSortOrder = SortOrder.values.firstWhere(
                (s) => s.name == raw['defaultSortOrder'],
                orElse: () => existingCol.defaultSortOrder,
              );
            }
            if (raw['defaultViewMode'] != null) {
              existingCol.defaultViewMode = ViewMode.values.firstWhere(
                (v) => v.name == raw['defaultViewMode'],
                orElse: () => existingCol.defaultViewMode,
              );
            }
            existingCol.splitSpreadView =
                raw['splitSpreadView'] as bool? ?? existingCol.splitSpreadView;
            existingCol.isHeaderExpanded =
                raw['isHeaderExpanded'] as bool? ??
                existingCol.isHeaderExpanded;
            existingCol.notes = raw['notes'] as String? ?? existingCol.notes;
            if (raw['lastViewedAt'] != null) {
              existingCol.lastViewedAt =
                  DateTime.tryParse(raw['lastViewedAt'] as String? ?? '') ??
                  existingCol.lastViewedAt;
            }
            await _isar.mediaCollections.put(existingCol);

            // タグの紐付け復元
            final tagKeys =
                (raw['tagKeys'] as List<dynamic>?)?.cast<String>() ?? [];
            existingCol.tags.clear();
            for (final tk in tagKeys) {
              final tag =
                  keyToTag[tk] ??
                  await _isar.tags.where().keyEqualTo(tk).findFirst();
              if (tag != null) {
                existingCol.tags.add(tag);
              }
            }
            await existingCol.tags.save();
          }
        }

        // -------------------------------------------------------------
        // 4. アイテムのメタデータ復元
        // -------------------------------------------------------------
        for (final raw in rawItems) {
          if (raw is! Map<String, dynamic>) continue;
          final relPath = raw['relativePath'] as String? ?? '';
          if (relPath.isEmpty) continue;

          final item = await _isar.mediaItems
              .where()
              .pathEqualTo(relPath)
              .findFirst();
          if (item != null) {
            item.isArchived = raw['isArchived'] as bool? ?? item.isArchived;
            item.isHidden = raw['isHidden'] as bool? ?? item.isHidden;
            item.isFavorite = raw['isFavorite'] as bool? ?? item.isFavorite;
            await _isar.mediaItems.put(item);
          }
        }
      });

      final source = selectedSource;
      final migrationMarker = File(
        p.join(metaFile.parent.path, legacyMigrationMarkerName),
      );
      if (source != null && (source.isLegacy || source.isBackup)) {
        // 旧公開サイドカーまたはバックアップから復元した場合は、復元済みDBを
        // 現行の私有領域へ書き戻す。
        final migrationResult = await exportMetadata();
        if (migrationResult.isFailure) {
          return Result.failure(migrationResult.errorOrNull!);
        }
        if (source.isLegacy) {
          await migrationMarker.writeAsString('pending-cleanup', flush: true);
        }
      }

      // 旧ファイル削除に途中失敗しても、私有領域のマーカーを残して次回の
      // 明示的な復元で再試行する。マーカーは全削除が完了した最後に消す。
      if (includeLegacy &&
          legacyMetaFile != null &&
          await migrationMarker.exists()) {
        final legacyFiles = [
          legacyMetaFile,
          File('${legacyMetaFile.path}.bak'),
        ];
        for (final legacyFile in legacyFiles) {
          if (await legacyFile.exists()) {
            await _deleteFile(legacyFile);
          }
        }
        final legacyDirectory = legacyMetaFile.parent;
        if (await legacyDirectory.exists() &&
            await legacyDirectory.list(followLinks: false).isEmpty) {
          await legacyDirectory.delete();
        }
        await _deleteFile(migrationMarker);
        AppLogger.i(LogTag.storage, '公開領域の旧メタデータを私有領域へ移行しました');
      }

      AppLogger.i(LogTag.storage, 'メタデータの復元が完了しました ($restoredCount 件新規作成/マージ)');
      return Result.success(restoredCount);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'メタデータのインポート中にエラーが発生しました: $e', e, st);
      return Result.failure(
        AppError.database(
          'メタデータのインポートに失敗しました: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  static int _metadataEntryCount(Map<String, dynamic> decoded) {
    return (decoded['tags'] as List<dynamic>? ?? const []).length +
        (decoded['collections'] as List<dynamic>? ?? const []).length +
        (decoded['mediaItems'] as List<dynamic>? ?? const []).length;
  }

  /// 復元検出と実インポートで共有する、サイズ・型・件数の検証境界。
  static Future<Map<String, dynamic>?> readValidatedDocument(
    File file, {
    int maxBytes = ImportSafetyPolicy.maxMetadataBytes,
    int maxRecordsPerType = ImportSafetyPolicy.maxMetadataRecordsPerType,
  }) async {
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.openRead()) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const FormatException('Metadata file exceeds the size limit');
      }
      bytes.add(chunk);
    }
    final text = utf8.decode(bytes.takeBytes(), allowMalformed: false);
    if (text.trim().isEmpty) return null;
    final parsed = jsonDecode(text);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Invalid metadata document');
    }
    final version = parsed['version'];
    if (version is! int || version < 1 || version > currentSchemaVersion) {
      throw const FormatException('Unsupported metadata schema version');
    }
    for (final key in const ['tags', 'collections', 'mediaItems']) {
      final records = parsed[key];
      if (records is! List || records.length > maxRecordsPerType) {
        throw FormatException('Invalid metadata records: $key');
      }
    }
    return parsed;
  }

  static Future<void> _validateDocumentPaths(
    Map<String, dynamic> document,
    Directory rootDir,
  ) async {
    final collections = document['collections'] as List<dynamic>;
    collections.removeWhere((raw) {
      if (raw is! Map<String, dynamic>) return false;
      final relativePath = raw['relativePath'];
      return relativePath is String &&
          _isSafeLegacyUnmanagedPath(relativePath, const {
            'library',
            'folders',
          });
    });
    for (final raw in collections) {
      if (raw is! Map<String, dynamic>) continue;
      final relativePath = raw['relativePath'];
      if (relativePath is String &&
          relativePath.isNotEmpty &&
          relativePath != 'library') {
        raw['relativePath'] = await _validateRelativePath(
          rootDir,
          relativePath,
          allowedRoots: const {'library', 'folders'},
        );
      }
      final coverPath = raw['coverImagePath'];
      if (coverPath != null) {
        if (coverPath is! String || coverPath.isEmpty) {
          throw const FormatException('Invalid metadata path: coverImagePath');
        }
        raw['coverImagePath'] = await _validateRelativePath(
          rootDir,
          coverPath,
          allowedRoots: const {'library', 'folders', 'covers', '.thumbnails'},
        );
      }
      final trashRootPath = raw['trashRootPath'];
      if (trashRootPath != null) {
        if (trashRootPath is! String || trashRootPath.isEmpty) {
          throw const FormatException('Invalid metadata path: trashRootPath');
        }
        raw['trashRootPath'] = await _validateRelativePath(
          rootDir,
          trashRootPath,
          allowedRoots: const {'library', 'folders'},
        );
      }
    }
    final mediaItems = document['mediaItems'] as List<dynamic>;
    mediaItems.removeWhere((raw) {
      if (raw is! Map<String, dynamic>) return false;
      final relativePath = raw['relativePath'];
      return relativePath is String &&
          _isSafeLegacyUnmanagedPath(relativePath, const {
            'library',
            'folders',
          });
    });
    for (final raw in mediaItems) {
      if (raw is! Map<String, dynamic>) continue;
      final relativePath = raw['relativePath'];
      if (relativePath is! String || relativePath.isEmpty) {
        throw const FormatException('Invalid media item path');
      }
      raw['relativePath'] = await _validateRelativePath(
        rootDir,
        relativePath,
        allowedRoots: const {'library', 'folders'},
      );
    }
  }

  static Future<String> _validateRelativePath(
    Directory rootDir,
    String relativePath, {
    required Set<String> allowedRoots,
  }) async {
    final normalized = p.normalize(relativePath);
    final segments = p.split(normalized);
    if (segments.isEmpty ||
        segments.length > ImportSafetyPolicy.maxRelativePathDepth) {
      throw const FormatException('Invalid metadata path depth');
    }
    try {
      final resolved = StorageSandbox.resolveRelative(
        rootDir.path,
        normalized,
        allowedTopLevelDirectories: allowedRoots,
      );
      await StorageSandbox.rejectSymbolicLinkAncestors(rootDir.path, resolved);
      return p.relative(resolved, from: p.absolute(rootDir.path));
    } on FileSystemException {
      throw const FormatException('Metadata path escapes the storage root');
    }
  }

  static bool _isUnderManagedRoot(String relativePath, Set<String> roots) {
    final normalized = p.normalize(relativePath);
    if (!p.isRelative(normalized)) return false;
    final segments = p.split(normalized);
    return segments.isNotEmpty &&
        !segments.contains('..') &&
        roots.contains(segments.first);
  }

  // 旧版のルート全体走査が生成した、安全だが管理対象外の相対パスだけを
  // 読み飛ばす。絶対パス、親参照、管理用の隠しパスは従来どおり拒否する。
  static bool _isSafeLegacyUnmanagedPath(
    String relativePath,
    Set<String> allowedRoots,
  ) {
    final normalized = p.normalize(relativePath);
    if (!p.isRelative(normalized) || normalized == '.') return false;
    final segments = p.split(normalized);
    if (segments.isEmpty ||
        segments.contains('..') ||
        segments.first.startsWith('.')) {
      return false;
    }
    return !allowedRoots.contains(segments.first);
  }
}
