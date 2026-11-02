import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/home_library_items_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/personal_library_state_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';

class _ImportFlow extends ImportFlowNotifier {
  @override
  ImportFlowState build() => ImportFlowState();
  void setFlow(ImportFlowState value) => state = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar isar;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    directory = await Directory.systemTemp.createTemp(
      'personal_library_state_',
    );
    isar = await Isar.open(
      [
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
        ViewingHistorySchema,
      ],
      directory: directory.path,
      name: 'personal_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [
        isarProvider.overrideWith((ref) async => isar),
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        importFlowNotifierProvider.overrideWith(_ImportFlow.new),
        homeLibraryItemsProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (isar.isOpen) await isar.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  MediaItem item(String uid, {String? originalPath}) => MediaItem()
    ..uid = uid
    ..path = 'library/$uid.txt'
    ..originalPath = originalPath ?? '/source/$uid.txt'
    ..type = MediaType.file;

  Future<void> save(MediaItem value) => isar.writeTxn(() async {
    await isar.mediaItems.put(value);
  });

  Future<PersonalLibraryState> freshState() async {
    container.invalidate(personalLibraryStateProvider);
    // Match the page's watch: keep this auto-dispose stream subscribed until
    // its asynchronous database lookup has emitted the requested state.
    final subscription = container.listen(
      personalLibraryStateProvider,
      (_, _) {},
    );
    try {
      return await container.read(personalLibraryStateProvider.future);
    } finally {
      subscription.close();
    }
  }

  void setFlow(ImportFlowState flow) {
    (container.read(importFlowNotifierProvider.notifier) as _ImportFlow)
        .setFlow(flow);
  }

  test(
    'closing a page during preferences loading does not start a database watch',
    () async {
      final loaded = Completer<SharedPreferences>();
      var databaseRequests = 0;
      final pendingContainer = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => loaded.future),
          isarProvider.overrideWith((ref) async {
            databaseRequests++;
            return isar;
          }),
          importFlowNotifierProvider.overrideWith(_ImportFlow.new),
        ],
      );
      addTearDown(pendingContainer.dispose);
      final subscription = pendingContainer.listen(
        personalLibraryStateProvider,
        (_, _) {},
      );
      await pendingContainer.pump();
      subscription.close();
      await pendingContainer.pump();
      expect(pendingContainer.exists(personalLibraryStateProvider), isFalse);

      loaded.complete(prefs);
      await Future<void>.delayed(Duration.zero);
      await pendingContainer.pump();
      expect(databaseRequests, 0);
    },
  );

  test('new empty library keeps the first import guide', () async {
    final state = await freshState();
    expect(state.hasImported, isFalse);
    expect(state.showFirstImportGuide, isTrue);
    expect(prefs.getBool(personalImportCompletedKey), isNull);
  });

  test(
    'legacy samples alone do not complete first import or mutate those samples',
    () async {
      final sample = item('sample', originalPath: 'template://welcome/Example')
        ..isFavorite = true;
      await save(sample);
      final state = await freshState();
      expect(state.hasImported, isFalse);
      expect(state.showFirstImportGuide, isTrue);
      expect((await isar.mediaItems.get(sample.id))!.isFavorite, isTrue);
      expect(await isar.mediaItems.count(), 1);
    },
  );

  test(
    'hidden and archived personal files still establish imported state',
    () async {
      await save(
        item('personal')
          ..isHidden = true
          ..isArchived = true,
      );
      final state = await freshState();
      expect(state.hasImported, isTrue);
      expect(state.showFirstImportGuide, isFalse);
      expect(prefs.getBool(personalImportCompletedKey), isTrue);
    },
  );

  test(
    'restored files without a known original source count as personal data',
    () async {
      await save(item('restored', originalPath: ''));
      expect((await freshState()).hasImported, isTrue);
    },
  );

  test(
    'provisional import rows do not persist completion and rollback keeps the guide',
    () async {
      setFlow(ImportFlowState(status: ImportFlowStatus.importing));
      final provisional = item('provisional');
      await save(provisional);
      expect((await freshState()).hasImported, isFalse);
      expect(prefs.getBool(personalImportCompletedKey), isNull);
      await isar.writeTxn(() async => isar.mediaItems.delete(provisional.id));
      setFlow(
        ImportFlowState(
          status: ImportFlowStatus.completed,
          importReport: const ImportExecutionReport(
            totalItems: 1,
            processedItems: 0,
            failedItems: 0,
            failureThresholdCount: 1,
            isCancelled: true,
            isRolledBack: true,
          ),
        ),
      );
      expect((await freshState()).showFirstImportGuide, isTrue);
      expect(prefs.getBool(personalImportCompletedKey), isNull);
    },
  );

  test(
    'a completed report with committed files establishes success despite partial failure',
    () async {
      setFlow(
        ImportFlowState(
          status: ImportFlowStatus.completed,
          importReport: const ImportExecutionReport(
            totalItems: 2,
            processedItems: 1,
            failedItems: 1,
            failureThresholdCount: 2,
            committedItems: [
              ImportCommittedItem(
                id: 1,
                uid: 'committed',
                path: 'library/committed.txt',
                sourcePath: '/source/committed.txt',
              ),
            ],
          ),
        ),
      );
      expect((await freshState()).hasImported, isTrue);
      expect(prefs.getBool(personalImportCompletedKey), isTrue);
    },
  );

  test('committed empty folders alone do not complete file import', () async {
    setFlow(
      ImportFlowState(
        status: ImportFlowStatus.completed,
        importReport: const ImportExecutionReport(
          totalItems: 1,
          processedItems: 1,
          failedItems: 0,
          failureThresholdCount: 1,
          committedItems: [
            ImportCommittedItem(
              id: 1,
              path: 'library/folder',
              sourcePath: '/source/folder',
              isFolder: true,
            ),
          ],
        ),
      ),
    );
    expect((await freshState()).hasImported, isFalse);
  });

  test(
    'filtered home result with zero rows does not override existing personal data',
    () async {
      await save(item('existing'));
      final homeSubscription = container.listen(
        homeLibraryItemsProvider,
        (_, _) {},
      );
      addTearDown(homeSubscription.close);
      expect(await container.read(homeLibraryItemsProvider.future), isEmpty);
      expect((await freshState()).hasImported, isTrue);
    },
  );

  test(
    'deleting all files does not reset a previously completed first import',
    () async {
      final personal = item('personal');
      await save(personal);
      expect((await freshState()).hasImported, isTrue);
      await isar.writeTxn(() async => isar.mediaItems.delete(personal.id));
      expect((await freshState()).hasImported, isTrue);
      expect((await freshState()).showFirstImportGuide, isFalse);
    },
  );

  test('trash alone does not establish a new completed import', () async {
    await save(item('trashed')..isTrashed = true);
    expect((await freshState()).hasImported, isFalse);
  });

  test('dismissed guide does not pretend a file was imported', () async {
    await prefs.setBool(personalImportGuideDismissedKey, true);
    final state = await freshState();
    expect(state.guideDismissed, isTrue);
    expect(state.hasImported, isFalse);
    expect(state.showFirstImportGuide, isFalse);
    expect(prefs.getBool(personalImportCompletedKey), isNull);
  });
}
