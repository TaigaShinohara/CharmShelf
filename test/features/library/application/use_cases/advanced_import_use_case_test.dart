import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';

class _ImportService extends Mock implements InternalImportService {}

FileTreeNode folder(String path) => FileTreeNode(
  name: path,
  uri: Uri.parse('file:///source/$path'),
  relativePath: path,
  isDirectory: true,
  isCatalog: true,
);
FileTreeNode file(String path) => FileTreeNode(
  name: path,
  uri: Uri.parse('file:///source/$path'),
  relativePath: path,
  isDirectory: false,
  isMedia: true,
);

void main() {
  late _ImportService service;
  late AdvancedImportUseCase useCase;
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(false);
    registerFallbackValue(ImportCatalogMode.folder);
  });
  setUp(() {
    service = _ImportService();
    useCase = AdvancedImportUseCase(service);
  });

  void respond(
    Future<Result<ImportExecutionReport, AppError>> Function(Invocation)
    callback,
  ) {
    when(
      () => service.importFolder(
        any(),
        targetParentPath: any(named: 'targetParentPath'),
        isCatalog: any(named: 'isCatalog'),
        registerChildFolders: any(named: 'registerChildFolders'),
        catalogMode: any(named: 'catalogMode'),
        catalogOverridesByRelativePath: any(
          named: 'catalogOverridesByRelativePath',
        ),
        selectedRelativePaths: any(named: 'selectedRelativePaths'),
        resumeDestinations: any(named: 'resumeDestinations'),
        maxBytes: any(named: 'maxBytes'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(callback);
  }

  test(
    'browser folder selection passes only the reviewed subtree with its display name',
    () async {
      final treeUri = Uri.parse('content://provider/tree/opaque');
      final leaf = FileTreeNode(
        name: 'photo.jpg',
        uri: Uri.parse('$treeUri/document/leaf'),
        relativePath: 'Album/photo.jpg',
        isDirectory: false,
        isMedia: true,
        size: 3,
        sourceTreeUri: treeUri,
      );
      final album = FileTreeNode(
        name: 'Album',
        uri: Uri.parse('$treeUri/document/album'),
        relativePath: 'Album',
        isDirectory: true,
        isCatalog: true,
        children: [leaf],
        sourceTreeUri: treeUri,
      );
      final virtualRoot = FileTreeNode(
        name: 'Location',
        uri: Uri.parse('private-shelf://source-selection'),
        relativePath: '',
        isDirectory: true,
        children: [album],
        sourceTreeUri: treeUri,
      );
      when(
        () => service.importFolder(
          any(),
          targetParentPath: any(named: 'targetParentPath'),
          isCatalog: any(named: 'isCatalog'),
          registerChildFolders: false,
          catalogMode: any(named: 'catalogMode'),
          catalogOverridesByRelativePath: any(
            named: 'catalogOverridesByRelativePath',
          ),
          selectedRelativePaths: any(named: 'selectedRelativePaths'),
          resumeDestinations: any(named: 'resumeDestinations'),
          maxBytes: any(named: 'maxBytes'),
          sourceName: 'Album',
          sourceEntries: any(named: 'sourceEntries'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        final entries = call.namedArguments[#sourceEntries] as List;
        expect(entries, hasLength(1));
        expect(entries.single.uri, '${leaf.uri}');
        expect(entries.single.relativePath, 'photo.jpg');
        return Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 3,
                path: 'library/Album/photo.jpg',
                sourcePath: 'photo.jpg',
                sizeBytes: 3,
              ),
            ],
          ),
        );
      });
      final result = await useCase.invoke([virtualRoot, album, leaf]);
      expect(result.isSuccess, isTrue);
      expect(
        result.dataOrNull!.committedFiles.single.sourcePath,
        'Album/photo.jpg',
      );
      expect(result.dataOrNull!.pendingSourcePaths, isEmpty);
      expect(result.dataOrNull!.committedFiles.single.sizeBytes, 3);
    },
  );

  test(
    'browser individual content URI imports without converting it into a local path and retries keep identity',
    () async {
      final grant = Uri.parse('content://provider/tree/opaque');
      final photo = FileTreeNode(
        name: 'photo.jpg',
        uri: Uri.parse('$grant/document/photo'),
        relativePath: 'folder/photo.jpg',
        isDirectory: false,
        isMedia: true,
        size: 3,
        sourceTreeUri: grant,
      );
      when(
        () => service.importContentFile(
          photo.uri,
          photo.name,
          photo.relativePath,
          expectedBytes: 3,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 5,
                path: 'library/photo.jpg',
                sourcePath: photo.relativePath,
              ),
            ],
          ),
        ),
      );
      final result = await useCase.invoke([photo]);
      expect(result.dataOrNull!.pendingSourcePaths, isEmpty);
      await useCase.invoke([photo], previousReport: result.dataOrNull);
      verify(
        () => service.importContentFile(
          photo.uri,
          photo.name,
          photo.relativePath,
          expectedBytes: 3,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  test(
    'standard document selection retains unknown size and forwards its stable identity',
    () async {
      final documentUri = Uri.parse('content://provider/document/opaque-photo');
      final document = FileTreeNode(
        name: 'photo.jpg',
        uri: documentUri,
        sourceDocumentUri: documentUri,
        relativePath: 'document-1',
        isDirectory: false,
        isMedia: true,
        isCatalog: true,
      );
      when(
        () => service.importContentFile(
          documentUri,
          'photo.jpg',
          'document-1',
          expectedBytes: null,
          targetParentPath: 'library/Current',
          isCatalog: true,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 12,
                path: 'library/Current/photo.jpg',
                sourcePath: 'document-1',
                sizeBytes: 3,
              ),
            ],
          ),
        ),
      );

      final result = await useCase.invoke([
        document,
      ], targetParentPath: 'library/Current');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.pendingSourcePaths, isEmpty);
      expect(result.dataOrNull!.committedFiles.single.sourcePath, 'document-1');
      await useCase.invoke(
        [document],
        targetParentPath: 'library/Current',
        previousReport: result.dataOrNull,
      );
      verify(
        () => service.importContentFile(
          documentUri,
          'photo.jpg',
          'document-1',
          expectedBytes: null,
          targetParentPath: 'library/Current',
          isCatalog: true,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verifyNever(
        () => service.importDeviceFile(
          any(),
          any(),
          any(),
          expectedBytes: any(named: 'expectedBytes'),
          targetParentPath: any(named: 'targetParentPath'),
          isCatalog: any(named: 'isCatalog'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    },
  );

  test(
    'same display name in distinct document URIs has independent success and retry identity',
    () async {
      final firstUri = Uri.parse('content://provider/document/first');
      final secondUri = Uri.parse('content://provider/document/second');
      final first = FileTreeNode(
        name: 'photo.jpg',
        uri: firstUri,
        sourceDocumentUri: firstUri,
        relativePath: 'document-first',
        isDirectory: false,
        isMedia: true,
        size: 3,
      );
      final second = FileTreeNode(
        name: 'photo.jpg',
        uri: secondUri,
        sourceDocumentUri: secondUri,
        relativePath: 'document-second',
        isDirectory: false,
        isMedia: true,
        size: 3,
      );
      var secondAttempts = 0;
      when(
        () => service.importContentFile(
          any(),
          'photo.jpg',
          any(),
          expectedBytes: 3,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        final uri = call.positionalArguments[0] as Uri;
        final identity = call.positionalArguments[2] as String;
        final failed = uri == secondUri && ++secondAttempts == 1;
        return Result.success(
          ImportExecutionReport(
            totalItems: 1,
            processedItems: failed ? 0 : 1,
            failedItems: failed ? 1 : 0,
            failureThresholdCount: 5,
            pendingSourcePaths: failed ? [identity] : [],
            failedEntries: failed
                ? [
                    ImportFailureDetail(
                      path: identity,
                      displayName: 'photo.jpg',
                      reason: ImportFailureReasonCode.temporaryCopy,
                    ),
                  ]
                : [],
            committedItems: failed
                ? []
                : [
                    ImportCommittedItem(
                      id: uri == firstUri ? 13 : 14,
                      path: uri == firstUri
                          ? 'library/photo.jpg'
                          : 'library/photo (1).jpg',
                      sourcePath: identity,
                      sizeBytes: 3,
                    ),
                  ],
          ),
        );
      });

      final initial = (await useCase.invoke([first, second])).dataOrNull!;
      expect(initial.committedFiles.single.sourcePath, 'document-first');
      expect(initial.pendingSourcePaths, ['document-second']);
      final retry = (await useCase.invoke([
        first,
        second,
      ], previousReport: initial)).dataOrNull!;

      expect(retry.committedFiles.map((item) => item.sourcePath), [
        'document-first',
        'document-second',
      ]);
      expect(retry.pendingSourcePaths, isEmpty);
      expect(secondAttempts, 2);
      verify(
        () => service.importContentFile(
          firstUri,
          'photo.jpg',
          'document-first',
          expectedBytes: 3,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  test(
    'unknown document copies consume one shared byte budget and retain earlier success on a limit failure',
    () async {
      final firstUri = Uri.parse('content://provider/document/large');
      final secondUri = Uri.parse('content://provider/document/overflow');
      FileTreeNode document(Uri uri, String identity) => FileTreeNode(
        name: 'photo.jpg',
        uri: uri,
        sourceDocumentUri: uri,
        relativePath: identity,
        isDirectory: false,
        isMedia: true,
      );
      final observedLimits = <int>[];
      when(
        () => service.importContentFile(
          any(),
          'photo.jpg',
          any(),
          expectedBytes: null,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        final uri = call.positionalArguments[0] as Uri;
        final identity = call.positionalArguments[2] as String;
        observedLimits.add(call.namedArguments[#maxBytes] as int);
        final measured =
            call.namedArguments[#onMeasuredBytes] as void Function(int);
        if (uri == firstUri) {
          measured(ImportSafetyPolicy.maxTotalBytes - 1);
          return Result.success(
            ImportExecutionReport(
              totalItems: 1,
              processedItems: 1,
              failedItems: 0,
              failureThresholdCount: 5,
              committedItems: [
                ImportCommittedItem(
                  id: 15,
                  path: 'library/photo.jpg',
                  sourcePath: identity,
                  sizeBytes: ImportSafetyPolicy.maxTotalBytes - 1,
                ),
              ],
            ),
          );
        }
        return Result.success(
          ImportExecutionReport(
            totalItems: 1,
            processedItems: 0,
            failedItems: 1,
            failureThresholdCount: 5,
            pendingSourcePaths: [identity],
            failedEntries: [
              ImportFailureDetail(
                path: identity,
                displayName: 'photo.jpg',
                reason: ImportFailureReasonCode.temporaryCopy,
              ),
            ],
          ),
        );
      });

      final report = (await useCase.invoke([
        document(firstUri, 'document-large'),
        document(secondUri, 'document-overflow'),
      ])).dataOrNull!;

      expect(observedLimits, [ImportSafetyPolicy.maxTotalBytes, 1]);
      expect(report.committedFiles.single.sourcePath, 'document-large');
      expect(report.pendingSourcePaths, ['document-overflow']);
      expect(report.retryBlocked, isFalse);
    },
  );

  test(
    'document retry subtracts measured earlier commits from the same session byte limit',
    () async {
      final uri = Uri.parse('content://provider/document/retry-large');
      const committedBytes = ImportSafetyPolicy.maxTotalBytes * 4 ~/ 5;
      const remainingBytes = ImportSafetyPolicy.maxTotalBytes - committedBytes;
      final retry = FileTreeNode(
        name: 'large.jpg',
        uri: uri,
        sourceDocumentUri: uri,
        relativePath: 'document-retry',
        isDirectory: false,
        isMedia: true,
      );
      const previous = ImportExecutionReport(
        sessionId: 'same-document-session',
        totalItems: 2,
        processedItems: 1,
        failedItems: 1,
        failureThresholdCount: 5,
        pendingSourcePaths: ['document-retry'],
        committedItems: [
          ImportCommittedItem(
            id: 16,
            path: 'library/large.jpg',
            sourcePath: 'document-committed',
            sizeBytes: committedBytes,
          ),
        ],
      );
      when(
        () => service.importContentFile(
          uri,
          'large.jpg',
          'document-retry',
          expectedBytes: null,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: remainingBytes,
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((call) async {
        // The retry is 50% of the limit, exceeding the 20% remaining budget.
        expect(
          ImportSafetyPolicy.maxTotalBytes ~/ 2,
          greaterThan(remainingBytes),
        );
        return Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 0,
            failedItems: 1,
            failureThresholdCount: 5,
            pendingSourcePaths: ['document-retry'],
            failedEntries: [
              ImportFailureDetail(
                path: 'document-retry',
                displayName: 'large.jpg',
                reason: ImportFailureReasonCode.noSpace,
              ),
            ],
          ),
        );
      });

      final result = await useCase.invoke([retry], previousReport: previous);

      expect(result.isSuccess, isTrue);
      final report = result.dataOrNull!;
      expect(report.sessionId, 'same-document-session');
      expect(report.committedFiles.single.sizeBytes, committedBytes);
      expect(report.pendingSourcePaths, ['document-retry']);
      expect(report.processedItems, 1);
      verify(
        () => service.importContentFile(
          uri,
          'large.jpg',
          'document-retry',
          expectedBytes: null,
          targetParentPath: null,
          isCatalog: false,
          maxBytes: remainingBytes,
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  for (final previousBytes in <int?>[null, -1]) {
    test(
      'document retry with ${previousBytes == null ? 'missing' : 'negative'} committed sizes is blocked before another copy',
      () async {
        final uri = Uri.parse('content://provider/document/legacy-retry');
        final retry = FileTreeNode(
          name: 'photo.jpg',
          uri: uri,
          sourceDocumentUri: uri,
          relativePath: 'document-retry',
          isDirectory: false,
          isMedia: true,
        );
        final previous = ImportExecutionReport(
          sessionId: 'legacy-document-session',
          totalItems: 2,
          processedItems: 1,
          failedItems: 1,
          failureThresholdCount: 5,
          pendingSourcePaths: ['document-retry'],
          committedItems: [
            ImportCommittedItem(
              id: 17,
              path: 'library/photo.jpg',
              sourcePath: 'document-committed',
              sizeBytes: previousBytes,
            ),
          ],
        );

        final result = await useCase.invoke([retry], previousReport: previous);

        expect(result.isFailure, isTrue);
        final report = ImportExecutionReport.fromMap(
          result.errorOrNull!.additionalData!,
        );
        expect(report.retryBlocked, isTrue);
        expect(report.committedFiles.single.id, 17);
        expect(report.pendingSourcePaths, ['document-retry']);
        verifyNever(
          () => service.importContentFile(
            any(),
            any(),
            any(),
            expectedBytes: any(named: 'expectedBytes'),
            targetParentPath: any(named: 'targetParentPath'),
            isCatalog: any(named: 'isCatalog'),
            maxBytes: any(named: 'maxBytes'),
            onMeasuredBytes: any(named: 'onMeasuredBytes'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      },
    );
  }

  test(
    'unknown SAF folder retry retains the session byte budget used by earlier committed files',
    () async {
      const committedBytes = ImportSafetyPolicy.maxTotalBytes * 4 ~/ 5;
      const remainingBytes = ImportSafetyPolicy.maxTotalBytes - committedBytes;
      final uri = Uri.parse('content://provider/tree/Album');
      final leaf = FileTreeNode(
        name: 'b.jpg',
        uri: Uri.parse('content://provider/tree/Album/document/b'),
        relativePath: 'Album/b.jpg',
        isDirectory: false,
        isMedia: true,
      );
      final album = FileTreeNode(
        name: 'Album',
        uri: uri,
        relativePath: 'Album',
        isDirectory: true,
        isCatalog: true,
        children: [leaf],
      );
      const previous = ImportExecutionReport(
        sessionId: 'same-folder-session',
        totalItems: 2,
        processedItems: 1,
        failedItems: 1,
        failureThresholdCount: 5,
        pendingSourcePaths: ['Album/b.jpg'],
        destinations: [
          ImportCommittedItem(
            id: 1,
            path: 'library/Album',
            sourcePath: 'Album',
            isFolder: true,
          ),
        ],
        committedItems: [
          ImportCommittedItem(
            id: 2,
            path: 'library/Album/a.jpg',
            sourcePath: 'Album/a.jpg',
            sizeBytes: committedBytes,
          ),
        ],
      );
      respond((call) async {
        expect(call.positionalArguments.single, uri);
        expect(call.namedArguments[#maxBytes], remainingBytes);
        expect(call.namedArguments[#selectedRelativePaths], {'b.jpg'});
        final resumed =
            call.namedArguments[#resumeDestinations]
                as List<ImportCommittedItem>;
        expect(resumed.single.sourcePath, '');
        return Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 0,
            failedItems: 1,
            failureThresholdCount: 5,
            pendingSourcePaths: ['b.jpg'],
            failedEntries: [
              ImportFailureDetail(
                path: 'b.jpg',
                displayName: 'b.jpg',
                reason: ImportFailureReasonCode.noSpace,
              ),
            ],
          ),
        );
      });

      final result = await useCase.invoke([
        album,
        leaf,
      ], previousReport: previous);

      expect(result.isSuccess, isTrue);
      final report = result.dataOrNull!;
      expect(report.sessionId, 'same-folder-session');
      expect(report.committedFiles.single.sizeBytes, committedBytes);
      expect(report.pendingSourcePaths, ['Album/b.jpg']);
      expect(report.failedEntries.single.path, 'Album/b.jpg');
    },
  );

  test(
    'passes only selected files to folder rescan; newly found files are not authorized',
    () async {
      Set<String>? received;
      respond((call) async {
        received = call.namedArguments[#selectedRelativePaths] as Set<String>;
        return Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 7,
                path: 'library/a.jpg',
                sourcePath: 'a.jpg',
              ),
            ],
          ),
        );
      });
      final result = await useCase.invoke([folder('one'), file('one/a.jpg')]);
      expect(received, {'a.jpg'});
      expect(result.dataOrNull!.committedFiles.single.sourcePath, 'one/a.jpg');
      expect(result.dataOrNull!.pendingSourcePaths, isEmpty);
    },
  );

  test(
    'later cancellation keeps earlier committed files and stops later groups',
    () async {
      final visited = <String>[];
      respond((call) async {
        final uri = call.positionalArguments.first as Uri;
        visited.add(uri.path);
        return Result.success(
          uri.path.endsWith('a')
              ? const ImportExecutionReport(
                  totalItems: 1,
                  processedItems: 1,
                  failedItems: 0,
                  failureThresholdCount: 5,
                  committedItems: [
                    ImportCommittedItem(
                      id: 1,
                      path: 'library/a.jpg',
                      sourcePath: 'a.jpg',
                    ),
                  ],
                )
              : const ImportExecutionReport(
                  totalItems: 1,
                  processedItems: 0,
                  failedItems: 0,
                  failureThresholdCount: 5,
                  isCancelled: true,
                  isRolledBack: true,
                ),
        );
      });
      final report = (await useCase.invoke([
        folder('a'),
        file('a/a.jpg'),
        folder('b'),
        file('b/b.jpg'),
        folder('c'),
        file('c/c.jpg'),
      ])).dataOrNull!;
      expect(visited, ['/source/a', '/source/b']);
      expect(report.isCancelled, isTrue);
      expect(report.hasCommittedFiles, isTrue);
      expect(report.processedItems, 1);
      expect(report.pendingSourcePaths, ['b/b.jpg', 'c/c.jpg']);
    },
  );

  test(
    'failure after rollback retains earlier success and retries all unsaved sources',
    () async {
      respond(
        (call) async =>
            (call.positionalArguments.first as Uri).path.endsWith('a')
            ? Result.success(
                const ImportExecutionReport(
                  totalItems: 1,
                  processedItems: 1,
                  failedItems: 0,
                  failureThresholdCount: 5,
                  committedItems: [
                    ImportCommittedItem(
                      id: 1,
                      path: 'library/a.jpg',
                      sourcePath: 'a.jpg',
                    ),
                  ],
                ),
              )
            : Result.failure(
                AppError.file('rollback').withAdditionalData(
                  const ImportExecutionReport(
                    totalItems: 2,
                    processedItems: 1,
                    failedItems: 1,
                    failureThresholdCount: 1,
                    isRolledBack: true,
                  ).toMap(),
                ),
              ),
      );
      final result = await useCase.invoke([
        folder('a'),
        file('a/a.jpg'),
        folder('b'),
        file('b/b.jpg'),
        file('b/c.jpg'),
      ]);
      expect(result.isFailure, isTrue);
      final report = ImportExecutionReport.fromMap(
        result.errorOrNull!.additionalData!,
      );
      expect(report.committedFiles.map((item) => item.id), [1]);
      expect(report.pendingSourcePaths, ['b/b.jpg', 'b/c.jpg']);
    },
  );

  test(
    'retry retains unsupported rejections and replaces transient failures',
    () async {
      const previous = ImportExecutionReport(
        sessionId: 'retry-session',
        totalItems: 3,
        processedItems: 1,
        failedItems: 2,
        failureThresholdCount: 5,
        committedItems: [
          ImportCommittedItem(
            id: 1,
            path: 'library/good.jpg',
            sourcePath: 'one/good.jpg',
          ),
        ],
        pendingSourcePaths: ['one/retry.jpg'],
        failedEntries: [
          ImportFailureDetail(
            path: 'one/bad.bin',
            displayName: 'bad.bin',
            reason: ImportFailureReasonCode.unsupported,
          ),
          ImportFailureDetail(
            path: 'one/retry.jpg',
            displayName: 'retry.jpg',
            reason: ImportFailureReasonCode.file,
          ),
        ],
      );
      respond(
        (call) async => Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 2,
                path: 'library/retry.jpg',
                sourcePath: 'retry.jpg',
              ),
            ],
          ),
        ),
      );
      final report = (await useCase.invoke([
        folder('one'),
        file('one/retry.jpg'),
      ], previousReport: previous)).dataOrNull!;
      expect(report.sessionId, 'retry-session');
      expect(report.totalItems, 3);
      expect(report.processedItems, 2);
      expect(report.failedItems, 1);
      expect(report.failedEntries.single.path, 'one/bad.bin');
      expect(
        report.failedEntries.single.reason,
        ImportFailureReasonCode.unsupported,
      );
      expect(report.pendingSourcePaths, isEmpty);
      expect(report.committedFiles.map((item) => item.id), [1, 2]);
    },
  );

  for (final persistedMediaFlag in [false, true]) {
    test(
      'unsupported-only selection is reported once and is never retryable (isMedia=$persistedMediaFlag)',
      () async {
        final unsupported = FileTreeNode(
          name: 'unsupported.bin',
          uri: Uri.file('/source/unsupported.bin'),
          relativePath: '/source/unsupported.bin',
          isDirectory: false,
          isMedia: persistedMediaFlag,
        );
        final result = await useCase.invoke([unsupported]);
        expect(result.isSuccess, isTrue);
        final report = result.dataOrNull!;
        expect(report.totalItems, 1);
        expect(report.processedItems, 0);
        expect(report.failedItems, 1);
        expect(
          report.failedEntries.single.reason,
          ImportFailureReasonCode.unsupported,
        );
        expect(report.pendingSourcePaths, isEmpty);
        expect(report.committedItems, isEmpty);
        verifyZeroInteractions(service);
      },
    );
  }

  test(
    'report serialization retains retry identity and reads legacy reports safely',
    () {
      const report = ImportExecutionReport(
        sessionId: 'operation',
        totalItems: 2,
        processedItems: 1,
        failedItems: 1,
        failureThresholdCount: 5,
        committedItems: [
          ImportCommittedItem(
            id: 5,
            uid: 'stable',
            path: 'library/a',
            sourcePath: 'a',
          ),
        ],
        pendingSourcePaths: ['b'],
        retryBlocked: true,
      );
      final restored = ImportExecutionReport.fromMap(report.toMap());
      expect(restored.sessionId, 'operation');
      expect(restored.committedFiles.single.uid, 'stable');
      expect(restored.retryBlocked, isTrue);
      expect(
        ImportExecutionReport.fromMap({'processedItems': 3}).hasCommittedFiles,
        isFalse,
      );
    },
  );
}
