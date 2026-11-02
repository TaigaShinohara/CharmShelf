import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/import_copy_artifacts.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class _Repository extends Mock implements MediaRepository {}

class _FailOnceFiles extends FileService {
  _FailOnceFiles(this.failedPath);
  final String failedPath;
  bool failed = false;
  @override
  Future<Result<void, AppError>> deleteFile(String path) async {
    if (path == failedPath && !failed) {
      failed = true;
      return Result.failure(AppError.file('temporary cleanup failure'));
    }
    return super.deleteFile(path);
  }
}

class _FailRepeatedlyFiles extends FileService {
  _FailRepeatedlyFiles(this.failedPath);
  final String failedPath;
  bool failDeletion = true;
  int deleteAttempts = 0;

  @override
  Future<Result<void, AppError>> deleteFile(String path) async {
    if (path == failedPath) {
      deleteAttempts++;
      if (failDeletion) {
        return Result.failure(AppError.file('persistent cleanup failure'));
      }
    }
    return super.deleteFile(path);
  }
}

class _FailRemoveJournal extends OperationJournalService {
  bool failRemove = true;

  @override
  Future<void> remove(String id) async {
    if (failRemove) throw FileSystemException('journal remove failed', id);
    await super.remove(id);
  }
}

class _ReadFailureFile extends Fake implements File {
  _ReadFailureFile(this.file);
  final File file;
  @override
  String get path => file.path;
  @override
  Future<int> length() => file.length();
  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream.error(FileSystemException('source read failed', file.path));
}

class _FailStagedJournal extends OperationJournalService {
  @override
  Future<void> write(OperationJournalEntry entry) async {
    if (entry.stage == OperationStage.staged) {
      throw const FileSystemException('staged journal persistence failed');
    }
    await super.write(entry);
  }
}

class _NoThumbnailFiles extends FileService {
  @override
  Future<Result<String, AppError>> generateThumbnail(
    File file, {
    int? timeMs,
  }) async => Result.failure(AppError.file('test fixture has no thumbnail'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(MediaItem()));
  late Directory root;
  late PathProviderPlatform oldPaths;
  late OperationJournalService journal;
  late _Repository repository;
  late OperationRecoveryService recovery;
  final artifacts = ImportCopyArtifacts(
    operationId: 'interrupted-copy',
    destinationPath: 'library/selected.jpg',
  );

  File file(String path) => File(p.join(root.path, path));
  Future<void> write(String path, String contents) async {
    await file(path).parent.create(recursive: true);
    await file(path).writeAsString(contents);
  }

  Future<void> checkpoint({
    OperationStage stage = OperationStage.planned,
    bool legacy = false,
  }) => journal.write(
    OperationJournalEntry(
      id: artifacts.operationId,
      kind: OperationKind.import,
      stage: stage,
      payload: {
        'path': artifacts.destinationPath,
        'thumbnailPath': null,
        if (!legacy) 'copyArtifacts': artifacts.toMap(),
      },
    ),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('import-crash-recovery-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    PrivateStorageService.resetForTesting();
    journal = OperationJournalService();
    repository = _Repository();
    recovery = OperationRecoveryService(journal, FileService(), repository);
    when(
      () => repository.getByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success(<MediaItem>[]));
    await write('source.jpg', 'original source');
  });

  tearDown(() async {
    PathProviderPlatform.instance = oldPaths;
    PrivateStorageService.resetForTesting();
    await root.delete(recursive: true);
  });

  test('copy途中の再起動は記録と所有者が一致する一時物だけを回収する', () async {
    await checkpoint();
    await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
    await write(artifacts.partialPath, 'incomplete bytes');
    await write(
      'library/selected.jpg.another.tagshelf-part',
      'another operation',
    );
    await write('library/user.tagshelf-part', 'user file');
    await write(
      'library/user.tagshelf-reservation',
      'user reservation-like file',
    );

    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file(artifacts.partialPath).exists(), isFalse);
    expect(await file(artifacts.reservationPath).exists(), isFalse);
    expect(await journal.readAll(), isEmpty);
    expect(await file('source.jpg').readAsString(), 'original source');
    expect(
      await file('library/selected.jpg.another.tagshelf-part').readAsString(),
      'another operation',
    );
    expect(
      await file('library/user.tagshelf-part').readAsString(),
      'user file',
    );
    expect(
      await file('library/user.tagshelf-reservation').readAsString(),
      'user reservation-like file',
    );
    expect((await recovery.recover()).isSuccess, isTrue);
  });

  test('DB保存済みのコピーは再起動で保持して残った所有一時物だけを回収する', () async {
    await checkpoint(stage: OperationStage.staged);
    await write(artifacts.destinationPath, 'complete bytes');
    await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
    await write(artifacts.partialPath, 'owned temporary bytes');
    when(() => repository.getByPath(artifacts.destinationPath)).thenAnswer(
      (_) async =>
          Result.success(MediaItem()..path = artifacts.destinationPath),
    );

    expect((await recovery.recover()).isSuccess, isTrue);
    expect(
      await file(artifacts.destinationPath).readAsString(),
      'complete bytes',
    );
    expect(await file('source.jpg').readAsString(), 'original source');
    expect(await file(artifacts.partialPath).exists(), isFalse);
    expect(await file(artifacts.reservationPath).exists(), isFalse);
    expect(await journal.readAll(), isEmpty);
  });

  for (final ownership in ['different-operation', 'empty', 'missing']) {
    test('所有情報が$ownershipなら一時物とjournalを保持して失敗を返す', () async {
      await checkpoint();
      await write(artifacts.partialPath, 'do not guess');
      if (ownership != 'missing') {
        await write(
          artifacts.reservationPath,
          ownership == 'empty'
              ? ''
              : jsonEncode({
                  ...artifacts.ownership,
                  'operationId': 'another-operation',
                }),
        );
      }
      expect((await recovery.recover()).isFailure, isTrue);
      expect(await file(artifacts.partialPath).readAsString(), 'do not guess');
      expect(await journal.readAll(), hasLength(1));
      verifyNever(() => repository.getByPath(any()));
    });
  }

  test('planned記録だけでは予約のない同名の実体を削除しない', () async {
    await checkpoint();
    await write(artifacts.destinationPath, 'unverified destination');
    expect((await recovery.recover()).isFailure, isTrue);
    expect(
      await file(artifacts.destinationPath).readAsString(),
      'unverified destination',
    );
    expect(await journal.readAll(), hasLength(1));
  });

  test('コピー完了後のjournal保存失敗でも所有情報を保持して復旧できる', () async {
    final failingJournal = _FailStagedJournal();
    final importer = ImportMediaUseCase(
      _NoThumbnailFiles(),
      Future.value(repository),
      failingJournal,
    );
    final result = await importer.invoke(file('source.jpg'));
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.additionalData?['importRetryBlocked'], isTrue);
    expect(await file('library/source.jpg').readAsString(), 'original source');
    expect(
      (await failingJournal.readAll()).single.stage,
      OperationStage.planned,
    );
    expect(
      await file('library/source.jpg.tagshelf-reservation').exists(),
      isTrue,
    );
    verifyNever(() => repository.save(any<MediaItem>()));

    final recovered = await OperationRecoveryService(
      failingJournal,
      FileService(),
      repository,
    ).recover();
    expect(recovered.isSuccess, isTrue);
    expect(await failingJournal.readAll(), isEmpty);
    expect(await file('library/source.jpg').exists(), isFalse);
    expect(await file('source.jpg').readAsString(), 'original source');
  });

  test('rename後の予約削除失敗は確定実体とjournalを保持し再試行を停止する', () async {
    final files = _FailOnceFiles('library/source.jpg.tagshelf-reservation');
    final importer = ImportMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    final result = await importer.invoke(file('source.jpg'));
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.additionalData?['importRetryBlocked'], isTrue);
    expect(await file('library/source.jpg').readAsString(), 'original source');
    final entries = await journal.readAll();
    expect(entries, hasLength(1));
    expect(entries.single.stage, OperationStage.staged);
    expect(
      await file('library/source.jpg.tagshelf-reservation').exists(),
      isTrue,
    );
    verifyNever(() => repository.save(any<MediaItem>()));

    // Startup can now identify and remove this unregistered final copy. It must
    // not silently become an untracked success or a second suffixed copy.
    recovery = OperationRecoveryService(journal, files, repository);
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file('library/source.jpg').exists(), isFalse);
    expect(
      await file('library/source.jpg.tagshelf-reservation').exists(),
      isFalse,
    );
    expect(await journal.readAll(), isEmpty);
    expect(await file('source.jpg').readAsString(), 'original source');
  });

  test('予約削除がimportと複数回の復旧で失敗しても記録と所有情報を保持する', () async {
    const destination = 'library/source.jpg';
    const reservation = '$destination.tagshelf-reservation';
    final files = _FailRepeatedlyFiles(reservation);
    final importer = ImportMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    final result = await importer.invoke(file('source.jpg'));
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.additionalData?['importRetryBlocked'], isTrue);
    final entry = (await journal.readAll()).single;
    final ownership = await file(reservation).readAsString();
    expect(jsonDecode(ownership)['operationId'], entry.id);
    expect(jsonDecode(ownership)['destinationPath'], destination);
    expect(await file(destination).readAsString(), 'original source');
    recovery = OperationRecoveryService(journal, files, repository);

    for (var attempt = 0; attempt < 2; attempt++) {
      expect((await recovery.recover()).isFailure, isTrue);
      expect(await file(reservation).readAsString(), ownership);
      expect((await journal.readAll()).single.toJson(), entry.toJson());
      expect(await file('source.jpg').readAsString(), 'original source');
      verifyNever(() => repository.save(any<MediaItem>()));
    }
    expect(files.deleteAttempts, 3);
    // The unregistered final is safely removed first; failure to retire the
    // reservation still prevents recovery from falsely reporting completion.
    expect(await file(destination).exists(), isFalse);
    files.failDeletion = false;
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file(reservation).exists(), isFalse);
    expect(await journal.readAll(), isEmpty);
    expect(await file('source.jpg').readAsString(), 'original source');
    expect((await recovery.recover()).isSuccess, isTrue);
    verifyNever(() => repository.save(any<MediaItem>()));
  });

  test('copy失敗後の空planned記録の退役失敗も再試行を停止し復旧後だけ再実行する', () async {
    final failingJournal = _FailRemoveJournal();
    journal = failingJournal;
    final files = _NoThumbnailFiles();
    final importer = ImportMediaUseCase(
      files,
      Future.value(repository),
      journal,
    );
    final result = await importer.invoke(_ReadFailureFile(file('source.jpg')));
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.additionalData?['importRetryBlocked'], isTrue);
    final entry = (await journal.readAll()).single;
    expect(entry.stage, OperationStage.planned);
    final recorded = ImportCopyArtifacts.fromMap(
      entry.payload['copyArtifacts'],
      operationId: entry.id,
      destinationPath: entry.payload['path'] as String,
    );
    for (final path in [
      recorded.destinationPath,
      recorded.partialPath,
      recorded.reservationPath,
    ]) {
      expect(await file(path).exists(), isFalse);
    }
    expect(await file('source.jpg').readAsString(), 'original source');
    verifyNever(() => repository.save(any<MediaItem>()));

    failingJournal.failRemove = false;
    recovery = OperationRecoveryService(journal, files, repository);
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await journal.readAll(), isEmpty);
    when(
      () => repository.save(any<MediaItem>()),
    ).thenAnswer((_) async => Result.success(null));
    final retry = await importer.invoke(file('source.jpg'));
    expect(retry.isSuccess, isTrue);
    expect(retry.dataOrNull!.path, recorded.destinationPath);
    expect(
      await file(recorded.destinationPath).readAsString(),
      'original source',
    );
    expect(await file('library/source_2.jpg').exists(), isFalse);
    expect(await file('source.jpg').readAsString(), 'original source');
    expect(await journal.readAll(), isEmpty);
    verify(() => repository.save(any<MediaItem>())).called(1);
  });

  for (final directory in [false, true]) {
    test(
      'plannedのpartialと保存先${directory ? 'フォルダ' : 'ファイル'}が併存したら衝突として全保持する',
      () async {
        await checkpoint();
        await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
        await write(artifacts.partialPath, 'owned incomplete bytes');
        final protectedPath = directory
            ? '${artifacts.destinationPath}/user-file.txt'
            : artifacts.destinationPath;
        await write(protectedPath, 'unrelated user data');
        expect((await recovery.recover()).isFailure, isTrue);
        expect(await file(protectedPath).readAsString(), 'unrelated user data');
        expect(
          await file(artifacts.partialPath).readAsString(),
          'owned incomplete bytes',
        );
        expect(await file(artifacts.reservationPath).exists(), isTrue);
        expect(await journal.readAll(), hasLength(1));
        verifyNever(() => repository.getByPath(any()));
      },
    );
  }

  test('未知版のcopyArtifactsが隔離されても復旧成功とせず実体を保持する', () async {
    await checkpoint();
    final recorded = (await journal.readAll()).single;
    final unknown = recorded.copyWith(
      payload: {
        ...recorded.payload,
        'copyArtifacts': {...artifacts.toMap(), 'version': 2},
      },
    );
    await write(
      'operation_journal/${artifacts.operationId}.json',
      jsonEncode(unknown.toJson()),
    );
    await write(artifacts.destinationPath, 'do not remove');
    await write(artifacts.partialPath, 'unverified partial');
    expect((await recovery.recover()).isFailure, isTrue);
    expect(
      await file(artifacts.destinationPath).readAsString(),
      'do not remove',
    );
    expect(
      await file(artifacts.partialPath).readAsString(),
      'unverified partial',
    );
    final report = await journal.readReport();
    expect(report.hasCorruption, isTrue);
    expect(report.quarantinedOperationIds, {artifacts.operationId});
    expect(
      await file(
        'operation_journal/${artifacts.operationId}.json.corrupt',
      ).exists(),
      isTrue,
    );
    expect((await recovery.recover()).isFailure, isTrue);
    expect((await journal.readReport()).hasCorruption, isTrue);
    expect(
      await file(artifacts.destinationPath).readAsString(),
      'do not remove',
    );
    expect(
      await file(artifacts.partialPath).readAsString(),
      'unverified partial',
    );
    verifyNever(() => repository.getByPath(any()));
  });

  test('一時パスのリンク先やアプリ管理外の元ファイルを回収しない', () async {
    await checkpoint();
    await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
    await Link(
      file(artifacts.partialPath).path,
    ).create(file('source.jpg').path);
    expect((await recovery.recover()).isFailure, isTrue);
    expect(await file('source.jpg').readAsString(), 'original source');
    expect(await Link(file(artifacts.partialPath).path).exists(), isTrue);
    expect(await journal.readAll(), hasLength(1));
  });

  test('一時物の清掃失敗はjournalを残し次の復旧で残りだけを回収する', () async {
    await checkpoint();
    await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
    await write(artifacts.partialPath, 'incomplete bytes');
    recovery = OperationRecoveryService(
      journal,
      _FailOnceFiles(artifacts.reservationPath),
      repository,
    );
    expect((await recovery.recover()).isFailure, isTrue);
    expect(await file(artifacts.partialPath).exists(), isFalse);
    expect(await file(artifacts.reservationPath).exists(), isTrue);
    expect(await journal.readAll(), hasLength(1));
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file(artifacts.reservationPath).exists(), isFalse);
    expect(await journal.readAll(), isEmpty);
    expect(await file('source.jpg').readAsString(), 'original source');
  });

  test('稼働中の同一operationは復旧が触らず終了後にだけ回収する', () async {
    await checkpoint();
    await write(artifacts.reservationPath, jsonEncode(artifacts.ownership));
    await write(artifacts.partialPath, 'active copy');
    await FileService.runImportOperation(artifacts.operationId, () async {
      expect((await recovery.recover()).isFailure, isTrue);
      expect(await file(artifacts.partialPath).readAsString(), 'active copy');
      expect(await journal.readAll(), hasLength(1));
      verifyNever(() => repository.getByPath(any()));
    });
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file(artifacts.partialPath).exists(), isFalse);
  });

  test('旧journalは従来の実体だけ回収し似た一時ファイルを推測で削除しない', () async {
    await checkpoint(stage: OperationStage.staged, legacy: true);
    await write(artifacts.destinationPath, 'uncommitted legacy copy');
    await write(artifacts.partialPath, 'unowned legacy-like file');
    await write(artifacts.reservationPath, 'unowned reservation');
    expect((await recovery.recover()).isSuccess, isTrue);
    expect(await file(artifacts.destinationPath).exists(), isFalse);
    expect(
      await file(artifacts.partialPath).readAsString(),
      'unowned legacy-like file',
    );
    expect(
      await file(artifacts.reservationPath).readAsString(),
      'unowned reservation',
    );
  });
}
