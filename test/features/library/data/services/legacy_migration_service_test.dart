import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';

class MemoryLegacyStorage implements LegacyStorage {
  final files = <String, List<int>>{};
  int deleteCount = 0;
  int? failDeleteAt;
  bool failScan = false;
  bool failCopy = false;
  bool corruptCopy = false;
  bool leaveDeletedFile = false;
  @override
  Future<List<LegacyEntry>> scan(Uri tree) async {
    if (failScan) throw StateError('Permission lost');
    return files.entries
        .map(
          (e) => LegacyEntry(
            path: e.key,
            directory: false,
            size: e.value.length,
            hash: sha256.convert(e.value).toString(),
          ),
        )
        .toList();
  }

  @override
  Future<void> copy(Uri tree, LegacyEntry entry, File destination) async {
    if (failCopy) throw StateError('Copy interrupted');
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(corruptCopy ? [0] : files[entry.path]!);
  }

  @override
  Future<void> deleteFile(Uri tree, LegacyEntry entry) async {
    if (deleteCount == failDeleteAt) throw StateError('Delete interrupted');
    if (sha256.convert(files[entry.path]!).toString() != entry.hash) {
      throw StateError('Changed');
    }
    if (!leaveDeletedFile) files.remove(entry.path);
    deleteCount++;
  }
}

void main() {
  late Directory root;
  late MemoryLegacyStorage storage;
  late LegacyMigrationService service;
  var imports = 0;
  var rejectReferences = false;
  final tree = Uri.parse(
    'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
  );
  Future<void> importFiles(Directory prepared) async {
    imports++;
    await for (final entry in prepared.list(recursive: true)) {
      if (entry is File &&
          !p
              .relative(entry.path, from: prepared.path)
              .startsWith('.tagshelf/')) {
        final target = File(
          p.join(root.path, p.relative(entry.path, from: prepared.path)),
        );
        await target.parent.create(recursive: true);
        await entry.copy(target.path);
      }
    }
  }

  LegacyMigrationService create() => LegacyMigrationService(
    root: root,
    storage: storage,
    restorePrepared: importFiles,
    checkReferences: (_) async {
      if (rejectReferences) {
        throw const LegacyMigrationException(LegacyIssue.linkedFolder);
      }
    },
  );
  setUp(() async {
    StorageOperationGate.recoveryRequired = false;
    root = await Directory.systemTemp.createTemp('legacy_migration_');
    storage = MemoryLegacyStorage();
    imports = 0;
    rejectReferences = false;
    service = create();
  });
  tearDown(() async {
    StorageOperationGate.recoveryRequired = false;
    await root.delete(recursive: true);
  });

  test(
    'full access emptiness check only completes a new, verified empty migration',
    () async {
      expect(await service.completeIfNoLegacyData(() async => false), isNull);
      expect(await service.load(), isNull);
      await expectLater(
        service.completeIfNoLegacyData(
          () async => throw StateError('permission lost'),
        ),
        throwsStateError,
      );
      expect(await service.load(), isNull);
      final result = await service.completeIfNoLegacyData(() async => true);
      expect(result!.phase, LegacyPhase.complete);
      expect((await create().load())!.phase, LegacyPhase.complete);
      expect(storage.deleteCount, 0);
      expect(imports, 0);
    },
  );
  test(
    'full access emptiness check cannot bypass an existing migration decision',
    () async {
      storage.files['library/photo.jpg'] = [1, 2, 3];
      await service.inspect(tree);
      var checked = false;
      final result = await service.completeIfNoLegacyData(() async {
        checked = true;
        return true;
      });
      expect(checked, isFalse);
      expect(result!.phase, LegacyPhase.choice);
      expect(storage.files, isNotEmpty);
      expect(storage.deleteCount, 0);
    },
  );

  test('absence only completes after a successful scan', () async {
    storage.failScan = true;
    await expectLater(service.inspect(tree), throwsStateError);
    expect(await service.load(), isNull);
    storage.failScan = false;
    expect((await service.inspect(tree)).phase, LegacyPhase.complete);
  });
  test('rejects unrelated providers and folders', () async {
    for (final uri in [
      Uri.parse('file:///Documents'),
      Uri.parse('content://evil/tree/primary%3ADocuments'),
      Uri.parse(
        'content://com.android.externalstorage.documents/tree/primary%3ADownload',
      ),
    ]) {
      await expectLater(
        service.inspect(uri),
        throwsA(isA<LegacyMigrationException>()),
      );
    }
    expect(storage.deleteCount, 0);
  });
  test('inspection is read only and survives restart', () async {
    storage.files['library/photo.jpg'] = [1, 2, 3];
    final before = await service.inspect(tree);
    final after = await create().load();
    expect(after!.id, before.id);
    expect(after.phase, LegacyPhase.choice);
    expect(storage.files, hasLength(1));
    expect(imports, 0);
  });
  test(
    'discard deletes only confirmed old files and preserves current app',
    () async {
      storage.files['library/photo.jpg'] = [1, 2, 3];
      final current = File(p.join(root.path, 'library/current.jpg'));
      await current.parent.create(recursive: true);
      await current.writeAsBytes([9]);
      await service.inspect(tree);
      final result = await service.execute(restore: false);
      expect(result.phase, LegacyPhase.complete);
      expect(result.restored, isFalse);
      expect(storage.files, isEmpty);
      expect(await current.readAsBytes(), [9]);
      expect(imports, 0);
    },
  );
  test(
    'verified restore precedes source deletion and preserves both files',
    () async {
      storage.files['library/photo.jpg'] = [1, 2, 3];
      final current = File(p.join(root.path, 'library/photo.jpg'));
      await current.parent.create(recursive: true);
      await current.writeAsBytes([9]);
      final record = await service.inspect(tree);
      await service.execute(restore: true);
      expect(await current.readAsBytes(), [9]);
      expect(
        await File(
          p.join(root.path, 'library/Restored-${record.id}/library/photo.jpg'),
        ).readAsBytes(),
        [1, 2, 3],
      );
      expect(storage.files, isEmpty);
      expect(imports, 1);
    },
  );
  test(
    'copy failure retains originals and must resume the same decision',
    () async {
      storage.files['library/photo.jpg'] = [1, 2, 3];
      await service.inspect(tree);
      storage.failCopy = true;
      await expectLater(service.execute(restore: true), throwsStateError);
      expect(storage.files, hasLength(1));
      expect(imports, 0);
      await expectLater(create().execute(restore: false), throwsStateError);
      await expectLater(create().inspect(tree), throwsStateError);
      expect(storage.files, hasLength(1));
      storage.failCopy = false;
      await create().execute(restore: true);
      expect(storage.files, isEmpty);
    },
  );
  test('corrupt copies never authorize deleting originals', () async {
    storage.files['library/photo.jpg'] = [1, 2, 3];
    await service.inspect(tree);
    storage.corruptCopy = true;
    await expectLater(service.execute(restore: true), throwsStateError);
    expect(storage.deleteCount, 0);
  });
  test('partial discard resumes remaining files after restart', () async {
    storage.files.addAll({
      'library/one.jpg': [1],
      'library/two.jpg': [2],
    });
    await service.inspect(tree);
    storage.failDeleteAt = 1;
    await expectLater(service.execute(restore: false), throwsStateError);
    expect(storage.files.keys, ['library/two.jpg']);
    expect((await service.load())!.phase, LegacyPhase.deleting);
    storage.failDeleteAt = null;
    await create().execute(restore: false);
    expect(storage.files, isEmpty);
    expect(storage.deleteCount, 2);
  });
  test('restore resumes deletion without importing metadata again', () async {
    storage.files.addAll({
      'library/one.jpg': [1],
      'library/two.jpg': [2],
    });
    await service.inspect(tree);
    storage.failDeleteAt = 1;
    await expectLater(service.execute(restore: true), throwsStateError);
    expect((await service.load())!.restored, isTrue);
    storage.failDeleteAt = null;
    await create().execute(restore: true);
    expect(imports, 1);
    expect(storage.files, isEmpty);
  });
  test('a changed or new source file blocks deletion', () async {
    storage.files['library/one.jpg'] = [1];
    await service.inspect(tree);
    storage.files['library/one.jpg'] = [2];
    await expectLater(
      service.execute(restore: false),
      throwsA(isA<LegacyMigrationException>()),
    );
    expect(storage.deleteCount, 0);
    await service.inspect(tree);
    storage.files['library/two.jpg'] = [3];
    await expectLater(
      service.execute(restore: false),
      throwsA(isA<LegacyMigrationException>()),
    );
    expect(storage.deleteCount, 0);
  });
  test('false deletion success is detected by relisting', () async {
    storage.files['library/one.jpg'] = [1];
    await service.inspect(tree);
    storage.leaveDeletedFile = true;
    await expectLater(service.execute(restore: false), throwsStateError);
    expect((await service.load())!.phase, LegacyPhase.deleting);
  });
  test('referenced external folders are never deleted', () async {
    storage.files['library/one.jpg'] = [1];
    await service.inspect(tree);
    rejectReferences = true;
    await expectLater(
      service.execute(restore: false),
      throwsA(isA<LegacyMigrationException>()),
    );
    expect(storage.deleteCount, 0);
  });
  test('unknown files are not silently included', () async {
    storage.files['personal.txt'] = [1];
    await expectLater(
      service.inspect(tree),
      throwsA(isA<LegacyMigrationException>()),
    );
    expect(await service.load(), isNull);
  });
  test(
    'unsupported media can be discarded but cannot be silently lost during restore',
    () async {
      storage.files['library/unknown.xyz'] = [1];
      await service.inspect(tree);
      await expectLater(
        service.execute(restore: true),
        throwsA(isA<LegacyMigrationException>()),
      );
      expect((await service.load())!.phase, LegacyPhase.choice);
      await service.execute(restore: false);
      expect(storage.files, isEmpty);
    },
  );
  test('invalid metadata keeps originals; valid backup may restore', () async {
    storage.files['.tagshelf/metadata.json'] = utf8.encode('broken');
    await service.inspect(tree);
    await expectLater(
      service.execute(restore: true),
      throwsA(isA<LegacyMigrationException>()),
    );
    expect(storage.deleteCount, 0);
  });
  test(
    'metadata path traversal is rejected before DB import or source deletion',
    () async {
      storage.files['.tagshelf/metadata.json'] = utf8.encode(
        jsonEncode({
          'version': 2,
          'tags': [],
          'collections': [],
          'mediaItems': [
            {'relativePath': '../secret.jpg'},
          ],
        }),
      );
      await service.inspect(tree);
      await expectLater(
        service.execute(restore: true),
        throwsA(isA<LegacyMigrationException>()),
      );
      expect(imports, 0);
      expect(storage.deleteCount, 0);
    },
  );
  test('DB verification failure preserves source', () async {
    storage.files['library/photo.jpg'] = [1];
    await service.inspect(tree);
    final checked = LegacyMigrationService(
      root: root,
      storage: storage,
      restorePrepared: importFiles,
      checkReferences: (_) async {},
      verifyDatabase: (_) async => throw StateError('Missing DB item'),
    );
    await expectLater(checked.execute(restore: true), throwsStateError);
    expect(storage.deleteCount, 0);
  });
  test(
    'a completed empty scan can be checked again without losing its history',
    () async {
      final first = await service.inspect(tree);
      expect(first.completedOutcome, LegacyOutcome.notFound);
      storage.files['library/later.jpg'] = [3];
      final next = await create().inspect(tree);
      expect(next.phase, LegacyPhase.choice);
      expect(next.id, isNot(first.id));
      expect(
        await File(
          p.join(root.path, '.tagshelf', 'legacy-history', '${first.id}.json'),
        ).exists(),
        isTrue,
      );
      expect(storage.files, hasLength(1));
    },
  );

  test('load is read only; cleanup is explicit and retryable', () async {
    final record = await service.inspect(tree);
    final stage = Directory(
      p.join(root.path, '.tagshelf', 'legacy-${record.id}', 'prepared'),
    );
    await stage.create(recursive: true);
    await service.load();
    expect(await stage.exists(), isTrue);
    await service.finishCleanup();
    expect(await stage.exists(), isFalse);
    expect((await service.load())!.phase, LegacyPhase.complete);
  });

  test('reconnecting preserves an interrupted deletion manifest', () async {
    storage.files.addAll({
      'library/a.jpg': [1],
      'library/b.jpg': [2],
    });
    final record = await service.inspect(tree);
    storage.failDeleteAt = 1;
    await expectLater(service.execute(restore: false), throwsStateError);
    await service.reconnect(tree);
    final resumed = (await service.load())!;
    expect(resumed.id, record.id);
    expect(resumed.fileCount, 2);
    await expectLater(service.inspect(tree), throwsStateError);
    storage.failDeleteAt = null;
    await service.execute(restore: false);
    expect((await service.load())!.completedOutcome, LegacyOutcome.deleted);
  });

  test('busy storage rejects execution before recording consent', () async {
    storage.files['library/a.jpg'] = [1];
    await service.inspect(tree);
    await StorageOperationGate.run(() async {
      await expectLater(
        service.execute(restore: false),
        throwsA(isA<StorageOperationBusy>()),
      );
    });
    expect((await service.load())!.phase, LegacyPhase.choice);
    expect(storage.files, hasLength(1));
  });

  test('completed decision is idempotent', () async {
    storage.files['library/one.jpg'] = [1];
    await service.inspect(tree);
    await service.execute(restore: false);
    await create().execute(restore: true);
    expect(storage.deleteCount, 1);
    expect(imports, 0);
  });
}
