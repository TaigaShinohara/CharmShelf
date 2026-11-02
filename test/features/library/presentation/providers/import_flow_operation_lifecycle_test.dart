import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/internal_import_service_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _lifetimeProbeProvider = Provider<int>((ref) => 1);

class _SourceStorage extends Mock implements ExternalStorageService {}

/// Retains the factory's real Ref, like the production service callbacks do.
/// Only the native/storage work is deferred; AdvancedImportUseCase stays real.
class _DeferredInternalImportService extends Mock
    implements InternalImportService {
  _DeferredInternalImportService(
    this.ref,
    this.started,
    this.allowImport,
    this.shouldFail,
  );

  final Ref ref;
  final Completer<void> started;
  final Completer<void> allowImport;
  final bool Function() shouldFail;

  @override
  Future<Result<ImportExecutionReport, AppError>> importFiles(
    List<File> files, {
    String? targetParentPath,
    bool isCatalog = false,
    void Function(SyncProgress progress)? onProgress,
    int failureThresholdCount =
        ImportExecutionReport.defaultFailureThresholdCount,
  }) async {
    ref.read(_lifetimeProbeProvider);
    started.complete();
    await allowImport.future;
    // A factory-only lifetime guard would be released before this read.
    ref.read(_lifetimeProbeProvider);
    if (ref.read(syncProgressNotifierProvider).isCancelled) {
      return Result.success(
        ImportExecutionReport(
          totalItems: 1,
          processedItems: 0,
          failedItems: 0,
          failureThresholdCount: failureThresholdCount,
          pendingSourcePaths: [files.single.path],
          isCancelled: true,
        ),
      );
    }
    if (shouldFail()) {
      final report = ImportExecutionReport(
        totalItems: 1,
        processedItems: 0,
        failedItems: 1,
        failureThresholdCount: failureThresholdCount,
        pendingSourcePaths: [files.single.path],
        failedEntries: [
          ImportFailureDetail(
            path: files.single.path,
            displayName: 'synthetic.txt',
            reason: ImportFailureReasonCode.file,
          ),
        ],
      );
      return Result.failure(
        AppError.file(
          'synthetic import failure',
        ).withAdditionalData(report.toMap()),
      );
    }
    return Result.success(
      ImportExecutionReport(
        totalItems: 1,
        processedItems: 1,
        failedItems: 0,
        failureThresholdCount: failureThresholdCount,
        committedItems: [
          ImportCommittedItem(
            id: 1,
            path: 'library/synthetic.txt',
            sourcePath: files.single.path,
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(Uri()));

  late Directory directory;
  late ProviderContainer container;
  late Completer<void> factoryStarted;
  late Completer<void> allowFactory;
  late Completer<void> importStarted;
  late Completer<void> allowImport;
  late int factoryDisposals;
  late bool failFactory;
  late bool failImport;
  Future<void>? operation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'tagshelf-import-lifetime-',
    );
    final source = await File(
      '${directory.path}/synthetic.txt',
    ).writeAsString('synthetic import lifetime fixture');
    factoryStarted = Completer<void>();
    allowFactory = Completer<void>();
    importStarted = Completer<void>();
    allowImport = Completer<void>();
    factoryDisposals = 0;
    failFactory = false;
    failImport = false;
    operation = null;
    final sourceStorage = _SourceStorage();
    when(() => sourceStorage.activeImportGrants).thenReturn(<Uri>{});
    when(
      () => sourceStorage.releasePersistedAccess(any()),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        // No native initialization, secure storage, or database belongs to this
        // lifetime check, including the grant-cleanup paths of executeImport.
        externalStorageServiceProvider.overrideWith(
          (ref) async => sourceStorage,
        ),
        internalImportServiceProvider.overrideWith((ref) async {
          ref.onDispose(() => factoryDisposals++);
          factoryStarted.complete();
          await allowFactory.future;
          // Reproduces the production factory's Ref reads after repository IO.
          ref.read(_lifetimeProbeProvider);
          if (failFactory) throw StateError('synthetic factory failure');
          return _DeferredInternalImportService(
            ref,
            importStarted,
            allowImport,
            () => failImport,
          );
        }),
      ],
    );
    // The screen observes progress, but it never observes these dependencies.
    container.listen(syncProgressNotifierProvider, (_, _) {});
    await container.read(importFlowNotifierProvider.notifier).startFilesScan([
      source.path,
    ]);
    final selection = container.read(importFlowNotifierProvider);
    expect(selection.status, ImportFlowStatus.confirming);
    expect(selection.rootNode!.children.single.sourceTreeUri, isNull);
    expect(selection.rootNode!.children.single.sourceDocumentUri, isNull);
  });

  tearDown(() async {
    if (!allowFactory.isCompleted) allowFactory.complete();
    if (!allowImport.isCompleted) allowImport.complete();
    try {
      if (factoryDisposals == 0) {
        await operation?.timeout(const Duration(seconds: 3));
      } else {
        // Before the fix, auto-disposal can detach the FutureProvider's future
        // permanently. The explicit lifetime assertion is the failure; awaiting
        // that detached future again would add an unrelated teardown timeout.
        operation?.ignore();
      }
    } finally {
      container.dispose();
      await directory.delete(recursive: true);
    }
  });

  Future<void> expectFactoryStartedAndRetained() async {
    await factoryStarted.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => fail(
        'Internal factory did not start: '
        'flow=${container.read(importFlowNotifierProvider).status}, '
        'advanced=${container.exists(advancedImportUseCaseProvider)}, '
        'internal=${container.exists(internalImportServiceProvider)}',
      ),
    );
    await container.pump();
    expect(
      factoryDisposals,
      0,
      reason: 'The started factory must remain alive across the IO delay',
    );
    expect(container.exists(internalImportServiceProvider), isTrue);
  }

  Future<void> startThroughDeferredFactory() async {
    operation = container
        .read(importFlowNotifierProvider.notifier)
        .executeImport();
    await expectFactoryStartedAndRetained();
    allowFactory.complete();
    final enteredImport = await Future.any<bool>([
      importStarted.future.then((_) => true),
      operation!.then((_) => false),
    ]).timeout(const Duration(seconds: 3));
    expect(
      enteredImport,
      isTrue,
      reason: 'The real advanced provider must finish its deferred dependency',
    );
    await container.pump();
    expect(factoryDisposals, 0);
    expect(container.exists(internalImportServiceProvider), isTrue);
  }

  Future<void> expectReleasedAfterOperation() async {
    await operation!.timeout(const Duration(seconds: 3));
    await container.pump();
    expect(factoryDisposals, 1);
    expect(container.exists(internalImportServiceProvider), isFalse);
    expect(container.exists(advancedImportUseCaseProvider), isFalse);
  }

  test(
    'import retains its async dependency through factory and invoke',
    () async {
      await startThroughDeferredFactory();
      allowImport.complete();
      await expectReleasedAfterOperation();

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.completed);
      expect(state.error, isNull);
      expect(state.importReport!.processedItems, 1);
      expect(state.importReport!.committedFiles.single.id, 1);
    },
  );

  test(
    'failed invoke preserves its report and releases the dependency',
    () async {
      failImport = true;
      await startThroughDeferredFactory();
      allowImport.complete();
      await expectReleasedAfterOperation();

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.error);
      expect(state.error!.category, ErrorCategory.file);
      expect(state.importReport!.failedItems, 1);
      expect(
        state.importReport!.failedEntries.single.reason,
        ImportFailureReasonCode.file,
      );
    },
  );

  test('failed async factory releases the operation subscription', () async {
    failFactory = true;
    operation = container
        .read(importFlowNotifierProvider.notifier)
        .executeImport();
    await expectFactoryStartedAndRetained();
    allowFactory.complete();
    await expectReleasedAfterOperation();

    expect(importStarted.isCompleted, isFalse);
    expect(
      container.read(importFlowNotifierProvider).status,
      ImportFlowStatus.error,
    );
  });

  test(
    'cancellation survives the deferred invoke and releases dependencies',
    () async {
      await startThroughDeferredFactory();
      container.read(syncProgressNotifierProvider.notifier).cancel();
      await container.pump();
      expect(factoryDisposals, 0);
      allowImport.complete();
      await expectReleasedAfterOperation();

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.completed);
      expect(state.importReport!.isCancelled, isTrue);
      expect(state.importReport!.processedItems, 0);
    },
  );

  test(
    'reset during dependency loading releases the early return lease',
    () async {
      final notifier = container.read(importFlowNotifierProvider.notifier);
      operation = notifier.executeImport();
      await expectFactoryStartedAndRetained();
      await notifier.reset();
      expect(factoryDisposals, 0);
      allowFactory.complete();
      await expectReleasedAfterOperation();

      expect(importStarted.isCompleted, isFalse);
      expect(
        container.read(importFlowNotifierProvider).status,
        ImportFlowStatus.idle,
      );
    },
  );
}
