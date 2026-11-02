import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/core/services/storage_sandbox.dart';
import 'import_copy_artifacts.dart';

part 'operation_journal_service.g.dart';

enum OperationKind {
  delete,
  import,
  move,
  createFolder,
  duplicate,
  removeExternalFolderReference,
}

enum OperationStage { planned, staged, committed }

class OperationJournalEntry {
  static const _maxIdLength = 128;
  static const _maxCleanupPaths = 100000;
  static final _safeIdPattern = RegExp(r'^[A-Za-z0-9._-]+$');
  const OperationJournalEntry({
    required this.id,
    required this.kind,
    required this.stage,
    required this.payload,
  });

  final String id;
  final OperationKind kind;
  final OperationStage stage;
  final Map<String, dynamic> payload;

  OperationJournalEntry copyWith({
    OperationStage? stage,
    Map<String, dynamic>? payload,
  }) => OperationJournalEntry(
    id: id,
    kind: kind,
    stage: stage ?? this.stage,
    payload: payload ?? this.payload,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'kind': kind.name,
    'stage': stage.name,
    'payload': payload,
  };

  static OperationJournalEntry fromJson(
    Map<String, dynamic> json, {
    String? expectedId,
  }) {
    if (json['version'] != 1 ||
        json['id'] is! String ||
        json['payload'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid operation journal');
    }
    final entry = OperationJournalEntry(
      id: json['id'] as String,
      kind: OperationKind.values.byName(json['kind'] as String),
      stage: OperationStage.values.byName(json['stage'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
    entry.validate(expectedId: expectedId);
    return entry;
  }

  void validate({String? expectedId}) {
    if (id.isEmpty ||
        id.length > _maxIdLength ||
        !_safeIdPattern.hasMatch(id) ||
        (expectedId != null && id != expectedId)) {
      throw const FormatException('Invalid operation journal id');
    }

    switch (kind) {
      case OperationKind.delete:
        _require<int>('rootItemId');
        final originalPath = _require<String>('originalPath');
        final trashPath = _require<String>('trashPath', allowEmpty: true);
        final isLocal = _require<bool>('isLocal');
        if (isLocal) {
          _validateManagedPath(originalPath, roots: const {'library'});
          _validateManagedPath(trashPath, roots: const {'.trash'});
          final restoreTargetPath = payload['restoreTargetPath'];
          if (restoreTargetPath != null) {
            if (restoreTargetPath is! String) {
              throw const FormatException('Invalid restoreTargetPath');
            }
            _validateManagedPath(restoreTargetPath, roots: const {'library'});
          }
          _validateNullableManagedParent(payload['restoreTargetParentPath']);
        } else {
          _validateExternalPath(originalPath);
          if (trashPath.isNotEmpty) _validateExternalPath(trashPath);
          final restoreTargetPath = payload['restoreTargetPath'];
          if (restoreTargetPath != null) {
            if (restoreTargetPath is! String) {
              throw const FormatException('Invalid restoreTargetPath');
            }
            _validateExternalPath(restoreTargetPath);
          }
          final restoreParent = payload['restoreTargetParentPath'];
          if (restoreParent != null && restoreParent is! String) {
            throw const FormatException('Invalid restoreTargetParentPath');
          }
        }
        final cleanupPaths = payload['cleanupPaths'];
        if (cleanupPaths != null) {
          if (cleanupPaths is! List || cleanupPaths.length > _maxCleanupPaths) {
            throw const FormatException('Invalid cleanupPaths');
          }
          for (final path in cleanupPaths) {
            if (path is! String) {
              throw const FormatException('Invalid cleanup path');
            }
            _validateManagedPath(path, roots: const {'.thumbnails'});
          }
        }
        if (isLocal) {
          final expectedTrashPath = p.join(
            '.trash',
            id,
            p.basename(originalPath),
          );
          if (p.normalize(trashPath) != p.normalize(expectedTrashPath)) {
            throw const FormatException('Delete journal paths do not match');
          }
        }
        break;
      case OperationKind.import:
        _validateManagedPath(
          _require<String>('path'),
          roots: const {'library'},
        );
        final thumbnailPath = payload['thumbnailPath'];
        if (thumbnailPath != null) {
          if (thumbnailPath is! String) {
            throw const FormatException('Invalid thumbnailPath');
          }
          _validateManagedPath(thumbnailPath, roots: const {'.thumbnails'});
        }
        if (payload.containsKey('copyArtifacts')) {
          ImportCopyArtifacts.fromMap(
            payload['copyArtifacts'],
            operationId: id,
            destinationPath: payload['path'] as String,
          );
        }
        break;
      case OperationKind.move:
        _require<int>('rootItemId');
        final oldPath = _require<String>('oldPath');
        final newPath = _require<String>('newPath');
        final isLocal = _require<bool>('isLocal');
        if (isLocal) {
          _validateManagedPath(oldPath, roots: const {'library'});
          _validateManagedPath(newPath, roots: const {'library'});
          _validateNullableManagedParent(payload['newParentPath']);
        } else {
          _validateExternalPath(oldPath);
          _validateExternalPath(newPath);
          final parent = payload['newParentPath'];
          if (parent != null) {
            if (parent is! String) {
              throw const FormatException('Invalid newParentPath');
            }
            _validateExternalPath(parent);
          }
        }
        final newTitle = payload['newTitle'];
        if (newTitle != null && newTitle is! String) {
          throw const FormatException('Invalid newTitle');
        }
        break;
      case OperationKind.createFolder:
        _validateManagedPath(
          _require<String>('path'),
          roots: const {'library'},
        );
        break;
      case OperationKind.duplicate:
        _validateManagedPath(
          _require<String>('rootPath'),
          roots: const {'library'},
        );
        break;
      case OperationKind.removeExternalFolderReference:
        final rootCollectionId = _require<int>('rootCollectionId');
        if (rootCollectionId <= 0) {
          throw const FormatException('Invalid root collection id');
        }
        _validateExternalPath(_require<String>('originalPath'));
        _validateIdList('itemIds');
        final collectionIds = _validateIdList('collectionIds');
        if (!collectionIds.contains(rootCollectionId)) {
          throw const FormatException(
            'External folder journal is missing its root collection',
          );
        }
        break;
    }
  }

  T _require<T>(String key, {bool allowEmpty = false}) {
    final value = payload[key];
    if (value is! T || (!allowEmpty && value is String && value.isEmpty)) {
      throw FormatException('Invalid operation journal field: $key');
    }
    return value;
  }

  List<int> _validateIdList(String key) {
    final value = payload[key];
    if (value is! List || value.length > _maxCleanupPaths) {
      throw FormatException('Invalid operation journal field: $key');
    }
    final ids = <int>[];
    for (final id in value) {
      if (id is! int || id <= 0) {
        throw FormatException('Invalid operation journal field: $key');
      }
      ids.add(id);
    }
    return ids;
  }

  static void _validateManagedPath(String value, {required Set<String> roots}) {
    try {
      StorageSandbox.resolveRelative(
        '/app/documents',
        value,
        allowedTopLevelDirectories: roots,
      );
    } on FileSystemException {
      throw const FormatException('Invalid managed operation path');
    }
  }

  static void _validateNullableManagedParent(Object? value) {
    if (value == null) return;
    if (value is! String) {
      throw const FormatException('Invalid managed parent path');
    }
    _validateManagedPath(value, roots: const {'library'});
  }

  static void _validateExternalPath(String value) {
    final uri = Uri.tryParse(value);
    final isValidFile =
        uri?.scheme == 'file' && p.isAbsolute(uri!.toFilePath());
    final isValidContent = uri?.scheme == 'content' && uri!.hasAuthority;
    if (value.isEmpty || (!isValidFile && !isValidContent)) {
      throw const FormatException('Invalid external operation path');
    }
  }
}

class OperationJournalReadReport {
  const OperationJournalReadReport({
    required this.entries,
    required this.quarantinedOperationIds,
  });

  final List<OperationJournalEntry> entries;
  final Set<String> quarantinedOperationIds;

  bool get hasCorruption => quarantinedOperationIds.isNotEmpty;
}

class OperationJournalService {
  static const _maxJournalBytes = 1024 * 1024;
  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'operation_journal'));
    await directory.create(recursive: true);
    await PrivateStorageService.enforceBackupExclusion(directory);
    return directory;
  }

  Future<void> write(OperationJournalEntry entry) async {
    entry.validate();
    final directory = await _directory();
    final target = File(p.join(directory.path, '${entry.id}.json'));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(entry.toJson()), flush: true);
    await temporary.rename(target.path);
  }

  Future<OperationJournalReadReport> readReport() async {
    final directory = await _directory();
    final entries = <OperationJournalEntry>[];
    final quarantinedOperationIds = <String>{};
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.json.corrupt')) {
        quarantinedOperationIds.add(
          p.basename(entity.path).replaceFirst(RegExp(r'\.json\.corrupt$'), ''),
        );
        continue;
      }
      if (!entity.path.endsWith('.json')) continue;
      try {
        if (await entity.length() > _maxJournalBytes) {
          throw const FormatException('Operation journal is too large');
        }
        final content = await entity.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Invalid operation journal payload format',
          );
        }
        final expectedId = p
            .basename(entity.path)
            .replaceFirst(RegExp(r'\.json$'), '');
        entries.add(
          OperationJournalEntry.fromJson(decoded, expectedId: expectedId),
        );
      } catch (e, st) {
        quarantinedOperationIds.add(
          p.basename(entity.path).replaceFirst(RegExp(r'\.json$'), ''),
        );
        AppLogger.w(
          LogTag.storage,
          '破損したジャーナルファイルを検出しました: ${entity.path} (スキップして隔離します)',
          e,
          st,
        );
        try {
          final corruptPath = '${entity.path}.corrupt';
          await entity.rename(corruptPath);
        } catch (renameErr) {
          AppLogger.e(
            LogTag.storage,
            '破損ジャーナルのリネームに失敗しました: ${entity.path}',
            renameErr,
          );
        }
      }
    }
    return OperationJournalReadReport(
      entries: entries,
      quarantinedOperationIds: quarantinedOperationIds,
    );
  }

  Future<List<OperationJournalEntry>> readAll() async =>
      (await readReport()).entries;

  Future<void> remove(String id) async {
    if (id.isEmpty ||
        id.length > OperationJournalEntry._maxIdLength ||
        !OperationJournalEntry._safeIdPattern.hasMatch(id)) {
      throw const FormatException('Invalid operation journal id');
    }
    final directory = await _directory();
    final file = File(p.join(directory.path, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  /// ユーザーがアプリ内ストレージを初期化した後に、過去の操作を再実行しないよう
  /// ジャーナルと隔離済みファイルをすべて削除する。
  Future<void> clearAll() async {
    final directory = await _directory();
    await for (final entity in directory.list(followLinks: false)) {
      await entity.delete(
        recursive: entity is Directory,
      ); // audit: allow-file-io
    }
    if (!await directory.list(followLinks: false).isEmpty) {
      throw const FileSystemException('操作ジャーナルを完全に削除できませんでした');
    }
  }
}

@Riverpod(keepAlive: true)
OperationJournalService operationJournalService(
  Ref ref,
) {
  return OperationJournalService();
}
