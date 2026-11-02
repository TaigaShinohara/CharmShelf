import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/services/import_source_browser.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/selected_document.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/internal_import_service_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The legacy preference plugin exposes this test seam through its platform package.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Storage extends Mock implements ExternalStorageService {}

class _Browser extends Mock implements ImportSourceBrowser {}

class _Import extends Mock implements AdvancedImportUseCase {}

class _Library extends LibraryViewModel {
  _Library(this.onBuild);

  final void Function() onBuild;

  @override
  FutureOr<List<MediaItem>> build() {
    onBuild();
    return <MediaItem>[];
  }
}

class _DeferredPreferencesStore extends InMemorySharedPreferencesStore {
  _DeferredPreferencesStore(super.data) : super.withData();

  final readStarted = Completer<void>();
  final allowRead = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    readStarted.complete();
    await allowRead.future;
    return super.getAll();
  }
}

class _FailingDraftPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingDraftPreferencesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.${AppPreferences.importFlowDraftSessionKey}') {
      return Future.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const documentChannel = MethodChannel(
    'io.alexrintt.plugins/sharedstorage/documentfile',
  );
  late _Storage storage;
  late _Browser browser;
  late _Import importer;
  late int libraryRefreshes;
  late int recentRefreshes;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(<FileTreeNode>[]);
    registerFallbackValue(ImportCatalogMode.folder);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    browser = _Browser();
    importer = _Import();
    libraryRefreshes = 0;
    recentRefreshes = 0;
    when(() => storage.activeImportGrants).thenReturn(<Uri>{});
    when(() => storage.releasePersistedAccess(any())).thenAnswer((_) async {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(documentChannel, (call) async {
          if (call.method == 'canRead') return true;
          throw StateError('Unexpected document operation: ${call.method}');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(documentChannel, null);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        externalStorageServiceProvider.overrideWith((ref) async => storage),
        importSourceBrowserProvider.overrideWithValue(browser),
        advancedImportUseCaseProvider.overrideWith((ref) async => importer),
        libraryViewModelProvider.overrideWith(
          () => _Library(() => libraryRefreshes++),
        ),
        recentMediaProvider.overrideWith((ref) {
          recentRefreshes++;
          return Stream.value(<MediaItem>[]);
        }),
      ],
    );
    container.listen(libraryViewModelProvider, (previous, next) {});
    container.listen(recentMediaProvider, (previous, next) {});
    addTearDown(container.dispose);
    return container;
  }

  void completeImportSuccessfully() {
    when(
      () => importer.invoke(
        any(),
        previousReport: any(named: 'previousReport'),
        targetParentPath: any(named: 'targetParentPath'),
        catalogMode: any(named: 'catalogMode'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((call) async {
      final nodes = call.positionalArguments.first as List<FileTreeNode>;
      final source = nodes.firstWhere((node) => !node.isDirectory);
      return Result.success(
        ImportExecutionReport(
          sessionId: 'completed-document',
          totalItems: 1,
          processedItems: 1,
          failedItems: 0,
          failureThresholdCount: 5,
          committedItems: [
            ImportCommittedItem(
              id: 1,
              path: 'library/${source.name}',
              sourcePath: source.relativePath,
            ),
          ],
        ),
      );
    });
  }

  test(
    'selection reviews URI metadata without copying and distinguishes duplicate names',
    () async {
      final firstUri = Uri.parse('content://provider/document/first');
      final secondUri = Uri.parse('content://provider/document/second');
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);

      await flow.startDocumentsScan([
        SelectedDocument(uri: firstUri, name: 'photo.jpg', size: 3),
        SelectedDocument(uri: firstUri, name: 'photo.jpg', size: 3),
        SelectedDocument(
          uri: secondUri,
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ], targetParentPath: 'library/Current');

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.targetParentPath, 'library/Current');
      expect(state.rootNode!.children, hasLength(2));
      final first = state.rootNode!.children.first;
      final second = state.rootNode!.children.last;
      expect(first.name, second.name);
      expect(first.uri, firstUri);
      expect(second.uri, secondUri);
      expect(first.relativePath, isNot(second.relativePath));
      expect(second.size, isNull);
      expect(second.mimeType, 'image/jpeg');
      expect(second.sourceDocumentUri, secondUri);
      expect(second.sourceTreeUri, isNull);
      expect(state.ownedGrants, isEmpty);

      flow.toggleImportSelection(first.relativePath);
      final edited = container.read(importFlowNotifierProvider).rootNode!;
      expect(edited.children.first.includeInImport, isFalse);
      expect(edited.children.last.includeInImport, isTrue);
      verifyNever(
        () => storage.copyToTemp(
          any(),
          any(),
          expectedBytes: any(named: 'expectedBytes'),
          maxBytes: any(named: 'maxBytes'),
        ),
      );
      verifyNever(() => browser.root(any()));
    },
  );

  test(
    'owned grants survive draft restoration and borrowed grants are not released',
    () async {
      final owned = Uri.parse('content://provider/document/owned');
      final borrowed = Uri.parse('content://provider/document/borrowed');
      final container = createContainer();
      await container
          .read(importFlowNotifierProvider.notifier)
          .startDocumentsScan([
            SelectedDocument(uri: owned, name: 'photo.jpg', ownsGrant: true),
            SelectedDocument(uri: borrowed, name: 'other.jpg'),
          ]);
      final saved = (await SharedPreferences.getInstance()).getString(
        AppPreferences.importFlowDraftSessionKey,
      );
      expect(saved, isNotNull);
      expect((jsonDecode(saved!) as Map)['version'], 5);

      final restored = createContainer();
      final flow = restored.read(importFlowNotifierProvider.notifier);
      await flow.restoreDraftSession();
      final state = restored.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.ownedGrants, {owned});
      expect(state.rootNode!.children.last.size, isNull);
      expect(state.rootNode!.children.last.uri, borrowed);

      await flow.reset();
      expect(
        restored.read(importFlowNotifierProvider).status,
        ImportFlowStatus.idle,
      );
      verify(() => storage.releasePersistedAccess(owned)).called(1);
      verifyNever(() => storage.releasePersistedAccess(borrowed));
    },
  );

  test(
    'a new selection of the same URI inherits owned access until reset',
    () async {
      final uri = Uri.parse('content://provider/document/same');
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg'),
      ]);

      expect(container.read(importFlowNotifierProvider).ownedGrants, {uri});
      verifyNever(() => storage.releasePersistedAccess(uri));
      await flow.reset();
      verify(() => storage.releasePersistedAccess(uri)).called(1);
    },
  );

  test(
    'failed confirmation persistence reports an error and releases the new owned access',
    () async {
      final uri = Uri.parse('content://provider/document/unsaved-confirmation');
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingDraftPreferencesStore();
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);

      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.error);
      expect(state.error, isNotNull);
      expect(state.ownedGrants, isEmpty);
      expect(storage.activeImportGrants, isEmpty);
      verify(() => storage.releasePersistedAccess(uri)).called(1);
    },
  );

  test(
    'reset during a delayed selection prevents stale confirmation and releases its owned access',
    () async {
      final uri = Uri.parse('content://provider/document/delayed');
      final ready = Completer<ExternalStorageService>();
      final container = ProviderContainer(
        overrides: [
          externalStorageServiceProvider.overrideWith((ref) => ready.future),
        ],
      );
      addTearDown(container.dispose);
      final flow = container.read(importFlowNotifierProvider.notifier);

      final pending = flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);
      final reset = flow.reset();
      ready.complete(storage);
      await Future.wait([pending, reset]);

      expect(
        container.read(importFlowNotifierProvider).status,
        ImportFlowStatus.idle,
      );
      expect(container.read(importFlowNotifierProvider).rootNode, isNull);
      expect(storage.activeImportGrants, isEmpty);
      verify(() => storage.releasePersistedAccess(uri)).called(1);
    },
  );

  for (final folder in [false, true]) {
    test(
      'late ${folder ? 'folder' : 'documents'} selection cannot remove a newer local-file draft after reset',
      () async {
        final uri = Uri.parse(
          'content://provider/${folder ? 'tree' : 'document'}/delayed',
        );
        final ready = Completer<ExternalStorageService>();
        final container = ProviderContainer(
          overrides: [
            externalStorageServiceProvider.overrideWith((ref) => ready.future),
          ],
        );
        addTearDown(container.dispose);
        final prefs = await SharedPreferences.getInstance();
        final flow = container.read(importFlowNotifierProvider.notifier);
        final pending = folder
            ? flow.startScan(uri, ownsGrant: true)
            : flow.startDocumentsScan([
                SelectedDocument(uri: uri, name: 'old.jpg', ownsGrant: true),
              ]);
        final resetting = flow.reset();
        await flow.startFilesScan([
          '/source/new.jpg',
        ], targetParentPath: 'library/New');
        await Future<void>.delayed(Duration.zero);
        expect(
          prefs.getString(AppPreferences.importFlowDraftSessionKey),
          contains('new.jpg'),
        );

        ready.complete(storage);
        await Future.wait([pending, resetting]);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(importFlowNotifierProvider);
        expect(state.status, ImportFlowStatus.confirming);
        expect(state.targetParentPath, 'library/New');
        expect(state.rootNode!.children.single.name, 'new.jpg');
        expect(state.ownedGrants, isEmpty);
        expect(storage.activeImportGrants, isEmpty);
        expect(
          prefs.getString(AppPreferences.importFlowDraftSessionKey),
          contains('new.jpg'),
        );
        verify(() => storage.releasePersistedAccess(uri)).called(1);
      },
    );
  }

  test(
    'a delayed draft restore cannot overwrite an in-progress new document selection',
    () async {
      final oldUri = Uri.parse('content://provider/document/old');
      final newUri = Uri.parse('content://provider/document/new');
      final store = _DeferredPreferencesStore({
        'flutter.${AppPreferences.importFlowDraftSessionKey}': jsonEncode({
          'version': 5,
          'status': 'confirming',
          'ownedGrants': ['$oldUri'],
          'rootNode': {
            'name': 'old.jpg',
            'uri': '$oldUri',
            'sourceDocumentUri': '$oldUri',
            'relativePath': 'old-document',
            'isDirectory': false,
          },
        }),
      });
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = store;
      final ready = Completer<ExternalStorageService>();
      final container = ProviderContainer(
        overrides: [
          externalStorageServiceProvider.overrideWith((ref) => ready.future),
        ],
      );
      addTearDown(container.dispose);
      final flow = container.read(importFlowNotifierProvider.notifier);
      final restoring = flow.restoreDraftSession();
      await store.readStarted.future;
      final picking = flow.startDocumentsScan([
        SelectedDocument(uri: newUri, name: 'new.jpg', ownsGrant: true),
      ], targetParentPath: 'library/New');
      store.allowRead.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(importFlowNotifierProvider).rootNode, isNull);
      expect(container.read(importFlowNotifierProvider).ownedGrants, {newUri});
      ready.complete(storage);
      await Future.wait([restoring, picking]);

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.rootNode!.children.single.uri, newUri);
      expect(state.targetParentPath, 'library/New');
      expect(state.ownedGrants, {newUri});
      expect(storage.activeImportGrants, {newUri});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppPreferences.importFlowDraftSessionKey),
        contains('new.jpg'),
      );
      verifyNever(() => storage.releasePersistedAccess(oldUri));
      expect(
        prefs.getStringList(ImportFlowNotifier.pendingGrantReleasesKey),
        contains('$oldUri'),
      );
      verifyNever(() => storage.releasePersistedAccess(newUri));
      await flow.reset();
      verify(() => storage.releasePersistedAccess(oldUri)).called(1);
    },
  );

  test(
    'legacy v4 draft restores without claiming ownership of tree access',
    () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.importFlowDraftSessionKey: jsonEncode({
          'version': 4,
          'status': 'confirming',
          'targetParentPath': 'library/Current',
          'rootNode': {
            'name': 'Album',
            'uri': 'content://provider/tree/album',
            'sourceTreeUri': 'content://provider/tree/album',
            'relativePath': '',
            'isDirectory': true,
            'children': [],
          },
        }),
      });
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.restoreDraftSession();

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.targetParentPath, 'library/Current');
      expect(state.ownedGrants, isEmpty);
      expect(state.rootNode!.sourceDocumentUri, isNull);
      expect(
        state.rootNode!.sourceTreeUri,
        Uri.parse('content://provider/tree/album'),
      );
      await flow.reset();
      verifyNever(() => storage.releasePersistedAccess(any()));
    },
  );

  test(
    'failed owned grant release is retained and retried by a later reset',
    () async {
      final uri = Uri.parse('content://provider/document/release-failure');
      var attempts = 0;
      when(() => storage.releasePersistedAccess(uri)).thenAnswer((_) async {
        if (++attempts == 1) throw StateError('Temporary release failure');
      });
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);

      await flow.reset();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ImportFlowNotifier.pendingGrantReleasesKey), [
        '$uri',
      ]);
      expect(
        container.read(importFlowNotifierProvider).status,
        ImportFlowStatus.idle,
      );
      await flow.reset();

      expect(
        prefs.getStringList(ImportFlowNotifier.pendingGrantReleasesKey),
        isEmpty,
      );
      verify(() => storage.releasePersistedAccess(uri)).called(2);
    },
  );

  test(
    'reset records owned access cleanup even when the storage provider becomes unavailable',
    () async {
      final uri = Uri.parse('content://provider/document/storage-unavailable');
      var unavailable = false;
      final container = ProviderContainer(
        overrides: [
          externalStorageServiceProvider.overrideWith((ref) async {
            if (unavailable) {
              throw StateError('Storage temporarily unavailable');
            }
            return storage;
          }),
        ],
      );
      addTearDown(container.dispose);
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);
      unavailable = true;
      container.invalidate(externalStorageServiceProvider);
      await expectLater(
        container.read(externalStorageServiceProvider.future),
        throwsStateError,
      );

      await flow.reset();

      expect(
        container.read(importFlowNotifierProvider).status,
        ImportFlowStatus.idle,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppPreferences.importFlowDraftSessionKey), isNull);
      expect(prefs.getStringList(ImportFlowNotifier.pendingGrantReleasesKey), [
        '$uri',
      ]);
      verifyNever(() => storage.releasePersistedAccess(uri));
    },
  );

  test(
    'revoked document read access reports failure before an import write',
    () async {
      final uri = Uri.parse('content://provider/document/revoked');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(documentChannel, (_) async => false);
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);

      await flow.executeImport();

      await container.pump();
      expect(libraryRefreshes, 1);
      expect(recentRefreshes, 1);

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.error);
      expect(state.error, isNotNull);
      expect(state.ownedGrants, {uri});
      verifyNever(
        () => importer.invoke(
          any(),
          previousReport: any(named: 'previousReport'),
          targetParentPath: any(named: 'targetParentPath'),
          catalogMode: any(named: 'catalogMode'),
          onProgress: any(named: 'onProgress'),
        ),
      );
      verifyNever(() => browser.root(any()));
      await flow.reset();
      verify(() => storage.releasePersistedAccess(uri)).called(1);
    },
  );

  test(
    'successful document import releases owned access and skips tree validation',
    () async {
      final uri = Uri.parse('content://provider/document/photo');
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ], targetParentPath: 'library/Current');
      final identity = container
          .read(importFlowNotifierProvider)
          .rootNode!
          .children
          .single
          .relativePath;
      when(
        () => importer.invoke(
          any(),
          previousReport: any(named: 'previousReport'),
          targetParentPath: 'library/Current',
          catalogMode: any(named: 'catalogMode'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          ImportExecutionReport(
            sessionId: 'document-import',
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 1,
                path: 'library/Current/photo.jpg',
                sourcePath: identity,
              ),
            ],
          ),
        ),
      );

      await flow.executeImport();

      expect(
        container.read(importFlowNotifierProvider).status,
        ImportFlowStatus.completed,
      );
      await container.pump();
      expect(libraryRefreshes, greaterThanOrEqualTo(2));
      expect(recentRefreshes, greaterThanOrEqualTo(2));
      expect(storage.activeImportGrants, isEmpty);
      verifyNever(() => browser.root(any()));
      verify(() => storage.releasePersistedAccess(uri)).called(1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppPreferences.importFlowDraftSessionKey,
        ),
        isNull,
      );
    },
  );

  test(
    'retryable document failure retains owned access and a restorable draft',
    () async {
      final uri = Uri.parse('content://provider/document/photo');
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: uri, name: 'photo.jpg', ownsGrant: true),
      ]);
      final identity = container
          .read(importFlowNotifierProvider)
          .rootNode!
          .children
          .single
          .relativePath;
      when(
        () => importer.invoke(
          any(),
          previousReport: any(named: 'previousReport'),
          targetParentPath: any(named: 'targetParentPath'),
          catalogMode: any(named: 'catalogMode'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          ImportExecutionReport(
            sessionId: 'retry-document',
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
        ),
      );

      await flow.executeImport();

      expect(container.read(importFlowNotifierProvider).ownedGrants, {uri});
      expect(storage.activeImportGrants, {uri});
      verifyNever(() => storage.releasePersistedAccess(uri));
      final restored = createContainer();
      final restoredFlow = restored.read(importFlowNotifierProvider.notifier);
      await restoredFlow.restoreDraftSession();
      expect(
        restored.read(importFlowNotifierProvider).status,
        ImportFlowStatus.confirming,
      );
      expect(
        restored
            .read(importFlowNotifierProvider)
            .importReport!
            .pendingSourcePaths,
        [identity],
      );
      expect(restored.read(importFlowNotifierProvider).ownedGrants, {uri});
      await restoredFlow.reset();
      verify(() => storage.releasePersistedAccess(uri)).called(1);
    },
  );

  test(
    'a new selection during the completion transition survives the old import cleanup',
    () async {
      final oldUri = Uri.parse('content://provider/document/old-completed');
      final newUri = Uri.parse('content://provider/document/new-selected');
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: oldUri, name: 'old.jpg', ownsGrant: true),
      ]);
      completeImportSuccessfully();
      Future<void>? nextSelection;
      container.listen(importFlowNotifierProvider, (previous, next) {
        if (next.status == ImportFlowStatus.completed &&
            nextSelection == null) {
          nextSelection = flow.startDocumentsScan([
            SelectedDocument(uri: newUri, name: 'new.jpg', ownsGrant: true),
          ], targetParentPath: 'library/New');
        }
      });

      await flow.executeImport();
      expect(nextSelection, isNotNull);
      await nextSelection!;

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.rootNode!.children.single.uri, newUri);
      expect(state.ownedGrants, {newUri});
      expect(storage.activeImportGrants, {newUri});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppPreferences.importFlowDraftSessionKey),
        contains('new.jpg'),
      );
      verifyNever(() => storage.releasePersistedAccess(oldUri));
      expect(
        prefs.getStringList(ImportFlowNotifier.pendingGrantReleasesKey),
        contains('$oldUri'),
      );
      verifyNever(() => storage.releasePersistedAccess(newUri));
      await flow.reset();
      verify(() => storage.releasePersistedAccess(oldUri)).called(1);
    },
  );

  test(
    'new document grants and draft survive a delayed release from the completed import',
    () async {
      final oldUri = Uri.parse('content://provider/document/slow-release');
      final newUri = Uri.parse(
        'content://provider/document/new-during-release',
      );
      final releaseStarted = Completer<void>();
      final allowRelease = Completer<void>();
      when(() => storage.releasePersistedAccess(oldUri)).thenAnswer((_) async {
        if (!releaseStarted.isCompleted) releaseStarted.complete();
        await allowRelease.future;
      });
      final container = createContainer();
      final flow = container.read(importFlowNotifierProvider.notifier);
      await flow.startDocumentsScan([
        SelectedDocument(uri: oldUri, name: 'old.jpg', ownsGrant: true),
      ]);
      completeImportSuccessfully();
      final importing = flow.executeImport();
      await releaseStarted.future;
      final nextSelection = flow.startDocumentsScan([
        SelectedDocument(uri: newUri, name: 'new.jpg', ownsGrant: true),
      ], targetParentPath: 'library/New');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(importFlowNotifierProvider).ownedGrants, {newUri});
      expect(storage.activeImportGrants, {newUri});
      allowRelease.complete();
      await Future.wait([importing, nextSelection]);

      final state = container.read(importFlowNotifierProvider);
      expect(state.status, ImportFlowStatus.confirming);
      expect(state.rootNode!.children.single.uri, newUri);
      expect(state.targetParentPath, 'library/New');
      expect(state.ownedGrants, {newUri});
      expect(storage.activeImportGrants, {newUri});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppPreferences.importFlowDraftSessionKey),
        contains('new.jpg'),
      );
      verify(
        () => storage.releasePersistedAccess(oldUri),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(() => storage.releasePersistedAccess(newUri));
      await flow.reset();
    },
  );
}
