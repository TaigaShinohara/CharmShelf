import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/app/initialization_flow.dart';
import 'package:private_shelf/features/library/presentation/providers/legacy_migration_provider.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/data/services/operation_recovery_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/data/services/template_collection_service.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/features/library/presentation/providers/data_restore_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/template_collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_preset_provider.dart';

class _MockEnsureTagDefaultsUseCase extends Mock
    implements EnsureTagDefaultsUseCase {}

class _RecoveryJournal extends Mock implements OperationJournalService {}

class _RecoveryFiles extends Mock implements FileService {}

class _RecoveryRepository extends Mock implements MediaRepository {}

class _MockTemplateCollectionService extends Mock
    implements TemplateCollectionService {}

class _TestDataRestoreNotifier extends DataRestoreNotifier {
  _TestDataRestoreNotifier(this.result);

  final Result<RestorableDataSummary, AppError> result;

  @override
  DataRestoreState build() => const DataRestoreState();

  @override
  Future<Result<RestorableDataSummary, AppError>> detect() async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final oldHandled in [false, true]) {
    test('Android旧フラグ=$oldHandled の既存ユーザーは確認なしで利用できる', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.restorePromptHandledKey: oldHandled,
        AppPreferences.onboardingCompletedKey: true,
      });
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          dataRestoreIsAndroidProvider.overrideWithValue(true),
          freshStartRunnerProvider.overrideWithValue(_freshStartFixture),
          legacyMigrationRecordProvider.overrideWith((ref) async => null),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.ready,
      );
      await container
          .read(initializationFlowAsyncProvider.notifier)
          .completeRestorePrompt();
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.ready,
      );
    });
  }

  for (final choice in ['first', 'fresh', 'transfer']) {
    test(
      'new Android user chooses $choice without recording a migration',
      () async {
        SharedPreferences.setMockInitialValues(_initializedPreferences());
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            freshStartRecoveryRunnerProvider.overrideWithValue(
              () async => false,
            ),
            dataRestoreIsAndroidProvider.overrideWithValue(true),
            freshStartRunnerProvider.overrideWithValue(_freshStartFixture),
            legacyMigrationRecordProvider.overrideWith((ref) async => null),
            operationRecoveryEnabledProvider.overrideWithValue(false),
            storageClearRecoveryEnabledProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          InitFlowState.welcome,
        );
        await container
            .read(initializationFlowAsyncProvider.notifier)
            .chooseLegacyEntry(choice);
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          switch (choice) {
            'first' || 'fresh' => InitFlowState.onboarding,
            'transfer' => InitFlowState.restorePrompt,
            _ => InitFlowState.onboarding,
          },
        );
        expect(prefs.getBool(AppPreferences.legacyWelcomeHandledKey), isTrue);
        if (choice == 'transfer') {
          await container
              .read(initializationFlowAsyncProvider.notifier)
              .completeRestorePrompt();
          expect(
            await container.read(initializationFlowAsyncProvider.future),
            InitFlowState.welcome,
          );
        }
        container.invalidate(initializationFlowAsyncProvider);
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          choice == 'transfer'
              ? InitFlowState.welcome
              : InitFlowState.onboarding,
        );
      },
    );
  }

  test(
    'confirmed fresh recovery precedes legacy access and failures stop startup',
    () async {
      SharedPreferences.setMockInitialValues(_initializedPreferences());
      final events = <String>[];
      var fail = true;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async {
            events.add('fresh');
            if (fail) throw StateError('unfinished reset');
            return true;
          }),
          dataRestoreIsAndroidProvider.overrideWithValue(true),
          legacyMigrationRecordProvider.overrideWith((ref) async {
            events.add('legacy');
            return null;
          }),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(initializationFlowAsyncProvider.future),
        throwsStateError,
      );
      expect(events, ['fresh']);
      fail = false;
      container.invalidate(initializationFlowAsyncProvider);
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.welcome,
      );
      expect(events, ['fresh', 'fresh', 'legacy']);
    },
  );

  test(
    'fresh-start failure keeps welcome and rejects resets during continuation',
    () async {
      SharedPreferences.setMockInitialValues(_initializedPreferences());
      var resets = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          freshStartRunnerProvider.overrideWithValue((_) async {
            resets++;
            throw StateError('clear failed');
          }),
          dataRestoreIsAndroidProvider.overrideWithValue(true),
          legacyMigrationRecordProvider.overrideWith((ref) async => null),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.welcome,
      );
      await expectLater(
        container
            .read(initializationFlowAsyncProvider.notifier)
            .chooseLegacyEntry('fresh'),
        throwsStateError,
      );
      expect(container.read(initializationFlowProvider), InitFlowState.welcome);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferences.legacyWelcomeHandledKey), isNull);
      await prefs.setBool(AppPreferences.onboardingCompletedKey, true);
      container.invalidate(initializationFlowAsyncProvider);
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.ready,
      );
      await expectLater(
        container
            .read(initializationFlowAsyncProvider.notifier)
            .chooseLegacyEntry('first'),
        throwsStateError,
      );
      expect(resets, 1);
    },
  );

  for (final outcome in LegacyOutcome.values) {
    test(
      'initial transfer result $outcome preserves restored data only',
      () async {
        SharedPreferences.setMockInitialValues(_initializedPreferences());
        final record = LegacyMigrationRecord(
          id: 'result',
          tree: Uri.parse('content://fixture'),
          entries: [],
          phase: LegacyPhase.complete,
          outcome: outcome,
        );
        var resetCalls = 0;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            freshStartRecoveryRunnerProvider.overrideWithValue(
              () async => false,
            ),
            freshStartRunnerProvider.overrideWithValue(
              (_) async => resetCalls++,
            ),
            dataRestoreIsAndroidProvider.overrideWithValue(true),
            legacyMigrationRecordProvider.overrideWith((ref) async => record),
            storageClearRecoveryEnabledProvider.overrideWithValue(false),
            operationRecoveryEnabledProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          InitFlowState.welcome,
        );
        await container
            .read(initializationFlowAsyncProvider.notifier)
            .chooseLegacyEntry('transfer');
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          InitFlowState.restorePrompt,
        );
        container.invalidate(initializationFlowAsyncProvider);
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          InitFlowState.restorePrompt,
        );
        await container
            .read(initializationFlowAsyncProvider.notifier)
            .completeRestorePrompt();
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          outcome == LegacyOutcome.restored
              ? InitFlowState.ready
              : InitFlowState.welcome,
        );
        expect(resetCalls, 0);
      },
    );
  }

  test(
    'deferring initial transfer returns to welcome without resetting',
    () async {
      SharedPreferences.setMockInitialValues(_initializedPreferences());
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          freshStartRunnerProvider.overrideWithValue(
            (_) async => throw StateError('must not reset'),
          ),
          dataRestoreIsAndroidProvider.overrideWithValue(true),
          legacyMigrationRecordProvider.overrideWith((ref) async => null),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      await container.read(initializationFlowAsyncProvider.future);
      await container
          .read(initializationFlowAsyncProvider.notifier)
          .chooseLegacyEntry('transfer');
      await container.read(initializationFlowAsyncProvider.future);
      await container
          .read(initializationFlowAsyncProvider.notifier)
          .deferLegacyTransfer();
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.welcome,
      );
    },
  );

  for (final phase in LegacyPhase.values) {
    test(
      'Android record $phase takes precedence only after writes start',
      () async {
        SharedPreferences.setMockInitialValues({
          ..._initializedPreferences(),
          AppPreferences.onboardingCompletedKey: true,
        });
        final record = LegacyMigrationRecord(
          id: '1',
          tree: Uri.parse(
            'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
          ),
          entries: [],
          phase: phase,
        );
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            freshStartRecoveryRunnerProvider.overrideWithValue(
              () async => false,
            ),
            dataRestoreIsAndroidProvider.overrideWithValue(true),
            freshStartRunnerProvider.overrideWithValue(_freshStartFixture),
            legacyMigrationRecordProvider.overrideWith((ref) async => record),
            operationRecoveryEnabledProvider.overrideWithValue(false),
            storageClearRecoveryEnabledProvider.overrideWithValue(false),
          ],
        );
        addTearDown(() {
          container.dispose();
          StorageOperationGate.recoveryRequired = false;
        });
        expect(
          await container.read(initializationFlowAsyncProvider.future),
          record.requiresRecovery
              ? InitFlowState.restorePrompt
              : InitFlowState.ready,
        );
        if (record.requiresRecovery) {
          await container
              .read(initializationFlowAsyncProvider.notifier)
              .completeRestorePrompt();
          expect(
            await container.read(initializationFlowAsyncProvider.future),
            InitFlowState.restorePrompt,
          );
        }
      },
    );
  }

  group('InitializationFlowNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(_initializedPreferences());
    });

    tearDown(() {
      container.dispose();
    });

    test('初期状態はlaunch→readyに遷移（機能フラグがすべてOFFの場合）', () async {
      // SharedPreferencesのモック
      SharedPreferences.setMockInitialValues(_initializedPreferences());

      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );

      // 初期化フローを開始
      final flowAsync = container.read(initializationFlowAsyncProvider);

      // ローディング状態から始まる
      expect(flowAsync.isLoading, true);
      await container.read(initializationFlowAsyncProvider.future);
    });

    test('操作復旧に失敗した場合は起動を続行せず再試行できる', () async {
      var attempts = 0;
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryRunnerProvider.overrideWithValue(() async {
            attempts++;
            if (attempts == 1) {
              return Result.failure(AppError.file('復旧に失敗'));
            }
            return Result.success(null);
          }),
        ],
      );

      await expectLater(
        container.read(initializationFlowAsyncProvider.future),
        throwsA(isA<AppError>()),
      );
      expect(container.read(initializationFlowAsyncProvider).hasError, isTrue);

      container.invalidate(initializationFlowAsyncProvider);
      final state = await container.read(
        initializationFlowAsyncProvider.future,
      );

      expect(state, InitFlowState.onboarding);
      expect(attempts, 2);
    });

    test('中断されたストレージ消去を通常の操作復旧より先に完了する', () async {
      final order = <String>[];
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryRunnerProvider.overrideWithValue(() async {
            order.add('storage-clear');
            return Result.success(null);
          }),
          operationRecoveryRunnerProvider.overrideWithValue(() async {
            order.add('operation-recovery');
            return Result.success(null);
          }),
        ],
      );

      await container.read(initializationFlowAsyncProvider.future);

      expect(order, ['storage-clear', 'operation-recovery']);
    });

    test('ストレージ消去復旧に失敗した場合は通常起動せず再試行できる', () async {
      var attempts = 0;
      var operationRecoveryCalls = 0;
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryRunnerProvider.overrideWithValue(() async {
            attempts++;
            if (attempts == 1) {
              return Result.failure(AppError.file('消去復旧に失敗'));
            }
            return Result.success(null);
          }),
          operationRecoveryRunnerProvider.overrideWithValue(() async {
            operationRecoveryCalls++;
            return Result.success(null);
          }),
        ],
      );

      await expectLater(
        container.read(initializationFlowAsyncProvider.future),
        throwsA(isA<AppError>()),
      );
      expect(operationRecoveryCalls, 0);

      container.invalidate(initializationFlowAsyncProvider);
      await container.read(initializationFlowAsyncProvider.future);

      expect(attempts, 2);
      expect(operationRecoveryCalls, 1);
    });

    test('完了済みごみ箱の欠損は警告を確認して続行でき、再確認で欠損解消を検出する', () async {
      final journal = _RecoveryJournal();
      final files = _RecoveryFiles();
      final repository = _RecoveryRepository();
      const entry = OperationJournalEntry(
        id: 'missing-staged-file',
        kind: OperationKind.delete,
        stage: OperationStage.committed,
        payload: {
          'rootItemId': 1,
          'originalPath': 'library/a.jpg',
          'trashPath': '.trash/missing-staged-file/a.jpg',
          'isLocal': true,
        },
      );
      final item = MediaItem()
        ..id = 1
        ..path = 'library/a.jpg'
        ..isTrashed = true
        ..isTrashRoot = true
        ..trashRootPath = 'library/a.jpg'
        ..trashPath = '.trash/missing-staged-file/a.jpg';
      when(() => journal.readReport()).thenAnswer(
        (_) async => const OperationJournalReadReport(
          entries: [entry],
          quarantinedOperationIds: {},
        ),
      );
      when(
        () => repository.getById(1),
      ).thenAnswer((_) async => Result.success(item));
      when(
        () => files.managedEntityExists(any()),
      ).thenAnswer((_) async => Result.success(false));
      when(
        () => repository.getTrashedRoots(),
      ).thenAnswer((_) async => Result.success([item]));
      when(
        () => files.listTrashStagingEntries(),
      ).thenAnswer((_) async => Result.success([]));
      // 既定の復旧は欠損を許可しない。
      expect(
        (await OperationRecoveryService(
          journal,
          files,
          repository,
        ).recover()).isFailure,
        isTrue,
      );
      final recovery = OperationRecoveryService(
        journal,
        files,
        repository,
        allowMissingCommittedTrash: true,
      );
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryRunnerProvider.overrideWithValue(() async {
            final result = await recovery.recover();
            container.read(missingCommittedTrashCountProvider.notifier).state =
                recovery.missingCommittedTrashCount;
            return result;
          }),
        ],
      );
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.recoveryWarning,
      );
      expect(container.read(missingCommittedTrashCountProvider), 1);
      container
          .read(initializationFlowAsyncProvider.notifier)
          .acknowledgeRecoveryWarning();
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.onboarding,
      );
      container.read(initializationFlowAsyncProvider.notifier).retryRecovery();
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.recoveryWarning,
      );
      when(
        () => files.managedEntityExists(item.trashPath!),
      ).thenAnswer((_) async => Result.success(true));
      container.read(initializationFlowAsyncProvider.notifier).retryRecovery();
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.onboarding,
      );
      expect(container.read(missingCommittedTrashCountProvider), 0);
      verifyNever(() => journal.remove(any()));
      verifyNever(() => files.deleteFile(any()));
    });

    test('オンボーディング未完了の場合はonboarding状態になる', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        'onboarding_completed': false,
      });

      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );

      // 待機してデータを取得
      await container.read(initializationFlowAsyncProvider.future);

      final state = container.read(initializationFlowProvider);
      // 注: FeatureFlagsの設定によって結果が変わる
      // テンプレートのデフォルト設定ではonboarding: enabled
      expect(state, InitFlowState.onboarding);
    });

    test('復元データ検出に失敗した場合は起動を止めて再試行可能にする', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.restorePromptHandledKey: false,
        AppPreferences.onboardingCompletedKey: false,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          dataRestoreNotifierProvider.overrideWith(
            () => _TestDataRestoreNotifier(
              Result.failure(AppError.file('検出に失敗しました')),
            ),
          ),
        ],
      );

      await expectLater(
        container.read(initializationFlowAsyncProvider.future),
        throwsA(isA<StateError>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferences.restorePromptHandledKey), isFalse);
    });

    test('復元データ検出が正常終了して対象がない場合だけ完了フラグを保存する', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.restorePromptHandledKey: false,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          dataRestoreNotifierProvider.overrideWith(
            () => _TestDataRestoreNotifier(
              Result.success(RestorableDataSummary.empty),
            ),
          ),
        ],
      );

      await container.read(initializationFlowAsyncProvider.future);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferences.restorePromptHandledKey), isTrue);
    });

    test('復元確認キー導入前から利用済みの端末には公開フォルダ確認を表示しない', () async {
      final preferences = _initializedPreferences()
        ..[AppPreferences.onboardingCompletedKey] = true
        ..remove(AppPreferences.restorePromptHandledKey);
      SharedPreferences.setMockInitialValues(preferences);
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 1,
        collectionCount: 0,
        mediaItemCount: 0,
        folderCount: 0,
        storagePath: '/legacy-public',
      );
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          dataRestoreNotifierProvider.overrideWith(
            () => _TestDataRestoreNotifier(Result.success(summary)),
          ),
        ],
      );

      final state = await container.read(
        initializationFlowAsyncProvider.future,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(state, InitFlowState.ready);
      expect(prefs.getBool(AppPreferences.restorePromptHandledKey), isTrue);
    });

    test('復元対象を検出した場合は通知画面へ遷移し完了フラグを保存しない', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.restorePromptHandledKey: false,
      });
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 1,
        collectionCount: 0,
        mediaItemCount: 0,
        folderCount: 0,
        storagePath: '/test',
      );
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          dataRestoreNotifierProvider.overrideWith(
            () => _TestDataRestoreNotifier(Result.success(summary)),
          ),
        ],
      );

      final state = await container.read(
        initializationFlowAsyncProvider.future,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(state, InitFlowState.restorePrompt);
      expect(prefs.getBool(AppPreferences.restorePromptHandledKey), isFalse);
    });

    test('completeOnboarding後にSharedPreferencesが更新される', () async {
      SharedPreferences.setMockInitialValues(_initializedPreferences());

      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );

      // 初期化完了を待つ
      await container.read(initializationFlowAsyncProvider.future);

      // オンボーディング完了
      await container
          .read(initializationFlowAsyncProvider.notifier)
          .completeOnboarding();

      // SharedPreferencesを確認
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), true);
      expect(prefs.getInt('last_selected_tab'), 0);
      expect(prefs.getBool('tutorial.library.completed'), true);
      expect(prefs.getBool('tutorial.home.completed'), true);
    });

    test('オンボーディングをスキップした場合も後続チュートリアルを完了する', () async {
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      await container.read(initializationFlowAsyncProvider.future);

      await container
          .read(initializationFlowAsyncProvider.notifier)
          .completeOnboarding(skipped: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), true);
      expect(prefs.getBool('tutorial.library.completed'), true);
      expect(prefs.getBool('tutorial.home.completed'), true);
    });

    test('新規ユーザーは見本やタグを自動投入せず、再起動後も空の棚から始める', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.restorePromptHandledKey: true,
        AppPreferences.onboardingCompletedKey: false,
        AppPreferences.startupMaintenanceVersionKey:
            currentStartupMaintenanceVersion,
      });
      for (var launch = 0; launch < 2; launch++) {
        final freshContainer = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            freshStartRecoveryRunnerProvider.overrideWithValue(
              () async => false,
            ),
            storageClearRecoveryEnabledProvider.overrideWithValue(false),
            operationRecoveryEnabledProvider.overrideWithValue(false),
            templateCollectionServiceProvider.overrideWith(
              (ref) => throw StateError('Startup must not create sample files'),
            ),
            tagPresetServiceProvider.overrideWith(
              (ref) => throw StateError('Startup must not create preset tags'),
            ),
          ],
        );
        try {
          expect(
            await freshContainer.read(initializationFlowAsyncProvider.future),
            InitFlowState.onboarding,
          );
        } finally {
          freshContainer.dispose();
        }
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('template_collection_initialized'), isNull);
      expect(prefs.getBool('tag_presets_initialized'), isNull);
    });

    test('旧サンプル投入済みのユーザーにも追加・削除を行わず既存の棚を維持する', () async {
      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.onboardingCompletedKey: true,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          templateCollectionServiceProvider.overrideWith(
            (ref) => throw StateError('Existing library must remain untouched'),
          ),
          tagPresetServiceProvider.overrideWith(
            (ref) => throw StateError('Existing tags must remain untouched'),
          ),
        ],
      );
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.ready,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('template_collection_initialized'), isTrue);
      expect(prefs.getBool('tag_presets_initialized'), isTrue);
    });

    test('サンプルを作成しない新規環境でもタグ保守の完了を保存する', () async {
      final ensureUseCase = _MockEnsureTagDefaultsUseCase();
      when(
        () => ensureUseCase.invoke(),
      ).thenAnswer((_) async => Result<void, AppError>.success(null));
      SharedPreferences.setMockInitialValues({
        'tag_presets_initialized': true,
        'restore_prompt_handled': true,
        'onboarding_completed': false,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          ensureTagDefaultsUseCaseProvider.overrideWithValue(ensureUseCase),
          templateCollectionServiceProvider.overrideWith(
            (ref) => throw StateError('New startup must not access templates'),
          ),
        ],
      );
      expect(
        await container.read(initializationFlowAsyncProvider.future),
        InitFlowState.onboarding,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AppPreferences.startupMaintenanceVersionKey),
        currentStartupMaintenanceVersion,
      );
      expect(prefs.getBool('template_collection_initialized'), isNull);
    });

    test('旧データの起動メンテナンスに成功すると完了バージョンを保存する', () async {
      final ensureUseCase = _MockEnsureTagDefaultsUseCase();
      final templateService = _MockTemplateCollectionService();
      when(
        () => ensureUseCase.invoke(),
      ).thenAnswer((_) async => Result<void, AppError>.success(null));
      when(
        () => templateService.repairLegacyCovers(),
      ).thenAnswer((_) async => true);
      when(
        () => templateService.repairLegacyWelcomeDirectory(),
      ).thenAnswer((_) async => true);
      when(
        () => templateService.repairInvalidRootCollections(),
      ).thenAnswer((_) async => true);

      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.startupMaintenanceVersionKey: 0,
        'restore_prompt_handled': true,
        'onboarding_completed': false,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          ensureTagDefaultsUseCaseProvider.overrideWithValue(ensureUseCase),
          templateCollectionServiceProvider.overrideWith(
            (ref) async => templateService,
          ),
        ],
      );

      await container.read(initializationFlowAsyncProvider.future);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AppPreferences.startupMaintenanceVersionKey),
        currentStartupMaintenanceVersion,
      );
      verify(() => ensureUseCase.invoke()).called(1);
      verify(() => templateService.repairLegacyCovers()).called(1);
      verify(() => templateService.repairLegacyWelcomeDirectory()).called(1);
      verify(() => templateService.repairInvalidRootCollections()).called(1);
      verifyNever(() => templateService.createWelcomeCollection());
    });

    test('起動メンテナンスの一部に失敗した場合は完了扱いにせず次回へ残す', () async {
      final ensureUseCase = _MockEnsureTagDefaultsUseCase();
      final templateService = _MockTemplateCollectionService();
      when(
        () => ensureUseCase.invoke(),
      ).thenAnswer((_) async => Result<void, AppError>.success(null));
      when(
        () => templateService.repairLegacyCovers(),
      ).thenAnswer((_) async => true);
      when(
        () => templateService.repairLegacyWelcomeDirectory(),
      ).thenAnswer((_) async => false);
      when(
        () => templateService.repairInvalidRootCollections(),
      ).thenAnswer((_) async => true);

      SharedPreferences.setMockInitialValues({
        ..._initializedPreferences(),
        AppPreferences.startupMaintenanceVersionKey: 0,
        'restore_prompt_handled': true,
        'onboarding_completed': false,
      });
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
          ensureTagDefaultsUseCaseProvider.overrideWithValue(ensureUseCase),
          templateCollectionServiceProvider.overrideWith(
            (ref) async => templateService,
          ),
        ],
      );

      await container.read(initializationFlowAsyncProvider.future);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppPreferences.startupMaintenanceVersionKey), 0);
    });
  });

  group('initializationFlowProvider（互換性Provider）', () {
    test('AsyncValueがloadingの場合はlaunchを返す', () {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          freshStartRecoveryRunnerProvider.overrideWithValue(() async => false),
          storageClearRecoveryEnabledProvider.overrideWithValue(false),
          operationRecoveryEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      // 初期状態（loading）
      final state = container.read(initializationFlowProvider);
      expect(state, InitFlowState.launch);
    });
  });
}

Map<String, Object> _initializedPreferences() => {
  'tag_presets_initialized': true,
  'template_collection_initialized': true,
  AppPreferences.restorePromptHandledKey: true,
  AppPreferences.startupMaintenanceVersionKey: currentStartupMaintenanceVersion,
};

Future<void> _freshStartFixture(String choice) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setString(AppPreferences.legacyEntryChoiceKey, choice);
  await prefs.setBool(AppPreferences.legacyWelcomeHandledKey, true);
  await prefs.setBool(AppPreferences.restorePromptHandledKey, true);
  await prefs.setInt(
    AppPreferences.startupMaintenanceVersionKey,
    currentStartupMaintenanceVersion,
  );
}
