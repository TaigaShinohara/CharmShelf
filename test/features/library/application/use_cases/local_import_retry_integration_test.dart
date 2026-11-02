import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/core/services/local_notification_service_io.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

// Local file selections must not call the Android document-provider APIs or
// background notification APIs. Unexpected calls to these fakes fail the test.
class _LocalStorage extends Fake implements ExternalStorageService {
  @override
  bool isSupportedExtension(String extension) =>
      MediaFormatUtils.allSupportedExtensions.contains(extension.toLowerCase());
}

class _Notifications extends Fake implements LocalNotificationService {}

enum _Fault { read, write }

class _ReadFailureFile extends Fake implements File {
  _ReadFailureFile(this.file);
  final File file;

  @override
  String get path => file.path;
  @override
  Future<int> length() => file.length();
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    await for (final chunk in file.openRead(start, end)) {
      // Read real source bytes and deliver a prefix before the read error.
      yield chunk.sublist(0, chunk.length ~/ 2);
      throw FileSystemException('Injected source read failure', path);
    }
  }
}

class _PartialFile extends Fake implements File {
  _PartialFile(this.file, this.fault, this.onPartialBytes);
  final File file;
  final _Fault fault;
  final void Function(List<int>) onPartialBytes;

  @override
  String get path => file.path;
  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      file.create(recursive: recursive, exclusive: exclusive);
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);
  @override
  Future<File> rename(String newPath) => file.rename(newPath);
  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) => _PartialSink(
    file,
    file.openWrite(mode: mode, encoding: encoding),
    fault,
    onPartialBytes,
  );
}

class _PartialSink extends Fake implements IOSink {
  _PartialSink(this.file, this.sink, this.fault, this.onPartialBytes);
  final File file;
  final IOSink sink;
  final _Fault fault;
  final void Function(List<int>) onPartialBytes;

  @override
  void add(List<int> data) {
    if (fault == _Fault.write) {
      // The prefix is written by a real IOSink. This injects the filesystem
      // error boundary; it does not simulate kernel disk exhaustion.
      sink.add(data.sublist(0, data.length ~/ 2));
      return;
    }
    sink.add(data);
  }

  @override
  Future<void> close() async {
    await sink.close();
    onPartialBytes(await file.readAsBytes());
    if (fault == _Fault.write) {
      // Asynchronous IOSink write errors are observed while closing the sink.
      throw FileSystemException(
        'Injected destination write failure',
        file.path,
      );
    }
  }
}

class _Files extends FileService {
  _Files(this.failedSourcePath, this.fault);
  final String failedSourcePath;
  final _Fault fault;
  final attempts = <String, int>{};
  bool faultEnabled = true;
  List<int>? bytesBeforeCleanup;

  @override
  Future<Result<String, AppError>> importFile(
    File file, {
    String? targetParentPath,
    String? sourceFileName,
    Future<void> Function(String)? onDestinationPrepared,
    Future<void> Function(String)? onDestinationPublished,
    int maxBytes = ImportSafetyPolicy.maxTotalBytes,
    int? expectedBytes,
    String? importOperationId,
  }) {
    attempts.update(file.path, (count) => count + 1, ifAbsent: () => 1);
    final shouldFail = faultEnabled && file.path == failedSourcePath;
    Future<Result<String, AppError>> copy() => super.importFile(
      shouldFail && fault == _Fault.read ? _ReadFailureFile(file) : file,
      targetParentPath: targetParentPath,
      sourceFileName: sourceFileName,
      onDestinationPrepared: onDestinationPrepared,
      onDestinationPublished: onDestinationPublished,
      maxBytes: maxBytes,
      expectedBytes: expectedBytes,
      importOperationId: importOperationId,
    );
    if (!shouldFail) return copy();
    return IOOverrides.runZoned(
      copy,
      createFile: (path) {
        final realFile = Zone.root.run(() => File(path));
        if (path.endsWith('.$importOperationId.tagshelf-part')) {
          return _PartialFile(
            realFile,
            fault,
            (bytes) => bytesBeforeCleanup = bytes,
          );
        }
        return realFile;
      },
    );
  }

  @override
  Future<Result<String, AppError>> generateThumbnail(
    File file, {
    int? timeMs,
  }) async => Result.failure(AppError.file('No thumbnail for text fixture'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform oldPaths;
  late Isar isar;
  late String databaseName;
  late IsarMediaRepository repository;
  late OperationJournalService journal;
  late _Files files;
  late List<File> sources;
  late List<FileTreeNode> nodes;
  late Map<String, String> sourceDigests;

  Future<void> openRepository() async {
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: root.path,
      name: databaseName,
    );
    repository = IsarMediaRepository(isar);
    journal = OperationJournalService();
  }

  AdvancedImportUseCase useCase() => AdvancedImportUseCase(
    InternalImportService(
      ImportMediaUseCase(files, Future.value(repository), journal),
      CreateFolderUseCase(Future.value(repository), files, journal),
      _LocalStorage(),
      files,
      journal,
      repository,
      _Notifications(),
      isCancelled: () => false,
      invalidateCollection: (_) {},
      invalidateLibrary: () {},
    ),
  );

  Future<String> digest(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  Future<void> expectSourcesUnchanged() async {
    for (final source in sources) {
      expect(await digest(source), sourceDigests[source.path]);
    }
  }

  Future<Map<String, Object?>> destinationSnapshot(
    ImportCommittedItem item,
  ) async {
    final row = (await repository.getByPath(item.path)).dataOrNull!;
    final collection = (await repository.getCollectionByPath(
      item.path,
    )).dataOrNull!;
    final destination = File(p.join(root.path, item.path));
    expect(row.id, item.id);
    expect(row.uid, item.uid);
    expect(row.size, item.sizeBytes);
    expect(await digest(destination), sourceDigests[item.sourcePath]);
    await collection.items.load();
    expect(collection.items.map((entry) => entry.id), [item.id]);
    return {
      ...item.toMap(),
      'sha256': await digest(destination),
      'collectionId': collection.id,
      'collectionUid': collection.uid,
    };
  }

  Future<void> expectOnlyCommittedFiles(ImportExecutionReport report) async {
    final rows = await isar.mediaItems.where().findAll();
    final collections = await isar.mediaCollections.where().findAll();
    expect(
      rows.map((row) => row.id),
      unorderedEquals(report.committedFiles.map((item) => item.id)),
    );
    expect(
      collections.map((row) => row.path),
      unorderedEquals(report.committedFiles.map((item) => item.path)),
    );
    final library = Directory(p.join(root.path, 'library'));
    final physicalFiles = await library
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(
      physicalFiles.map((file) => p.relative(file.path, from: root.path)),
      unorderedEquals(report.committedFiles.map((item) => item.path)),
    );
    expect(await journal.readAll(), isEmpty);
    expect((await journal.readReport()).hasCorruption, isFalse);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tagshelf_local_retry_');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    PrivateStorageService.resetForTesting();
    databaseName = 'local_retry_${DateTime.now().microsecondsSinceEpoch}';
    await openRepository();
    final sourceDirectory = await Directory(
      p.join(root.path, 'source'),
    ).create();
    sources = [];
    nodes = [];
    sourceDigests = {};
    for (var index = 0; index < 3; index++) {
      final source =
          await File(
            p.join(sourceDirectory.path, 'selected_$index.txt'),
          ).writeAsBytes(
            List.generate(4096, (offset) => (index * 53 + offset) % 256),
            flush: true,
          );
      sources.add(source);
      sourceDigests[source.path] = await digest(source);
      nodes.add(
        FileTreeNode(
          name: p.basename(source.path),
          uri: source.uri,
          relativePath: source.path,
          isDirectory: false,
          isMedia: true,
          isCatalog: true,
          size: await source.length(),
        ),
      );
    }
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    PathProviderPlatform.instance = oldPaths;
    PrivateStorageService.resetForTesting();
    await root.delete(recursive: true);
  });

  for (final fault in _Fault.values) {
    for (final failedIndex in [0, 1]) {
      test(
        '${fault.name} failure in file $failedIndex retries only the failed local source',
        () async {
          final failedSource = sources[failedIndex];
          files = _Files(failedSource.path, fault);
          final firstResult = await useCase().invoke(nodes);
          expect(firstResult.isSuccess, isTrue);
          final first = firstResult.dataOrNull!;
          // Success<Result> means the batch reported its outcome, not that all
          // files succeeded. A UI must keep this partial failure visible.
          expect(first.hasPartialFailure, isTrue);
          expect(first.totalItems, 3);
          expect(first.processedItems, 2);
          expect(first.failedItems, 1);
          expect(first.pendingSourcePaths, [failedSource.path]);
          expect(first.failedEntries.single.path, failedSource.path);
          expect(
            first.failedEntries.single.displayName,
            p.basename(failedSource.path),
          );
          // FileService maps unclassified FileSystemException to validation;
          // InternalImportService exposes it as invalid. This is still a
          // visible, pending failure eligible for retry after cleanup.
          expect(
            first.failedEntries.single.reason,
            ImportFailureReasonCode.invalid,
          );
          expect(first.retryBlocked, isFalse);
          expect(first.isCancelled, isFalse);
          expect(first.isRolledBack, isFalse);
          expect(first.sessionId, isNotEmpty);
          expect(files.bytesBeforeCleanup, isNotEmpty);
          expect(
            files.bytesBeforeCleanup!.length,
            lessThan(await failedSource.length()),
          );
          expect(
            files.bytesBeforeCleanup,
            (await failedSource.readAsBytes()).sublist(
              0,
              files.bytesBeforeCleanup!.length,
            ),
          );
          expect(files.attempts, {
            for (final source in sources) source.path: 1,
          });
          expect(
            first.committedFiles.map((item) => item.sourcePath),
            unorderedEquals(
              sources
                  .where((source) => source != failedSource)
                  .map((source) => source.path),
            ),
          );
          await expectSourcesUnchanged();
          await expectOnlyCommittedFiles(first);
          final originalDestinations = <String, Map<String, Object?>>{};
          for (final item in first.committedFiles) {
            originalDestinations[item.sourcePath] = await destinationSnapshot(
              item,
            );
          }

          // Reopen the real database and reload the persisted session report.
          // This is an explicit retry, not automatic post-crash continuation.
          final reportFile = await File(
            p.join(root.path, 'retry-report.json'),
          ).writeAsString(jsonEncode(first.toMap()), flush: true);
          await isar.close();
          await openRepository();
          final restored = ImportExecutionReport.fromMap(
            Map<String, dynamic>.from(
              jsonDecode(await reportFile.readAsString()) as Map,
            ),
          );
          expect(
            restored.failedEntries.single.toMap(),
            first.failedEntries.single.toMap(),
          );
          files.faultEnabled = false;
          final retryResult = await useCase().invoke(
            nodes,
            previousReport: restored,
          );
          expect(retryResult.isSuccess, isTrue);
          final retried = retryResult.dataOrNull!;
          expect(retried.sessionId, first.sessionId);
          expect(retried.totalItems, 3);
          expect(retried.processedItems, 3);
          expect(retried.failedItems, 0);
          expect(retried.hasPartialFailure, isFalse);
          expect(retried.failedEntries, isEmpty);
          expect(retried.pendingSourcePaths, isEmpty);
          expect(retried.retryBlocked, isFalse);
          expect(files.attempts, {
            for (final source in sources)
              source.path: source == failedSource ? 2 : 1,
          });
          for (final item in retried.committedFiles) {
            final snapshot = await destinationSnapshot(item);
            if (item.sourcePath != failedSource.path) {
              expect(snapshot, originalDestinations[item.sourcePath]);
            }
          }
          await expectSourcesUnchanged();
          await expectOnlyCommittedFiles(retried);

          final attemptsAfterRetry = Map<String, int>.from(files.attempts);
          final repeated = await useCase().invoke(
            nodes,
            previousReport: retried,
          );
          expect(repeated.isSuccess, isTrue);
          expect(repeated.dataOrNull!.toMap(), retried.toMap());
          expect(files.attempts, attemptsAfterRetry);
          await expectOnlyCommittedFiles(repeated.dataOrNull!);
          await expectSourcesUnchanged();
        },
      );
    }
  }
}
