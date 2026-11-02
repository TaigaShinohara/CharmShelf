import '../core/services/storage_operation_gate.dart';
import 'package:isar/isar.dart';
import '../core/providers/isar_provider.dart';
import '../features/library/domain/models/reference_migration.dart';
import 'dart:async';
import '../features/library/presentation/providers/legacy_migration_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/features/library/presentation/providers/template_collection_provider.dart';
import '../core/config/feature_flags.dart';
import '../core/logger/app_logger.dart';
import '../core/logger/log_tag.dart';
import '../core/database/migration_helper.dart';
import '../core/preferences/app_preferences.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../core/services/file_service.dart';
import '../core/services/operation_journal_service.dart';
import '../features/library/data/repositories/media_repository_provider.dart';
import '../features/library/data/services/operation_recovery_service.dart';
import '../features/library/data/services/external_storage_service.dart';
import '../features/settings/data/services/storage_clear_service.dart';
import '../core/providers/tutorial_providers.dart';

import '../features/library/presentation/providers/data_restore_provider.dart';
import '../features/onboarding/data/fresh_start_service.dart';
import '../features/library/data/services/legacy_migration_service.dart';
import 'fresh_start_scope.dart';

enum InitFlowState {
  launch,
  recoveryWarning,
  restorePrompt,
  welcome,
  onboarding,
  ready,
}

const currentStartupMaintenanceVersion = 1;
final operationRecoveryEnabledProvider = Provider<bool>((ref) => true);
final storageClearRecoveryEnabledProvider = Provider<bool>((ref) => true);
final missingCommittedTrashCountProvider = StateProvider<int>((ref) => 0);
final freshStartRecoveryRunnerProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () => ref.read(freshStartServiceProvider).recoverPending(),
);
final freshStartRunnerProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (choice) => ref.read(freshStartServiceProvider).start(choice),
);

typedef OperationRecoveryRunner = Future<Result<void, AppError>> Function();
typedef StorageClearRecoveryRunner = Future<Result<void, AppError>> Function();

final storageClearRecoveryRunnerProvider = Provider<StorageClearRecoveryRunner>(
  (ref) {
    return () async {
      final service = await ref.read(storageClearServiceProvider.future);
      return service.recoverPendingClear();
    };
  },
);

final operationRecoveryRunnerProvider = Provider<OperationRecoveryRunner>((
  ref,
) {
  return () async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final externalStorage = await ref.read(
      externalStorageServiceProvider.future,
    );
    final recovery = OperationRecoveryService(
      ref.read(operationJournalServiceProvider),
      ref.read(fileServiceProvider),
      repository,
      releaseExternalAccess: externalStorage.releasePersistedAccess,
      allowMissingCommittedTrash: true,
      additionalProtectedTrashIds: () async {
        final db = await ref.read(isarProvider.future);
        return (await db.referenceMigrations.where().findAll())
            .map((r) => r.key)
            .toSet();
      },
    );
    final result = await recovery.recover();
    ref.read(missingCommittedTrashCountProvider.notifier).state =
        result.isSuccess ? recovery.missingCommittedTrashCount : 0;
    return result;
  };
});

/// 初期化フローの「状態マシン」
///
/// このテンプレでは SharedPreferences に完了状態を保存し、
/// 中断しても再開できるようにします。
class InitializationFlowNotifier extends AsyncNotifier<InitFlowState> {
  static const _templateCollectionInitializedKey =
      'template_collection_initialized';

  // 初期化タスクのメモ化（プロセス生存期間中、一度だけ実行を保証）
  Future<void>? _initTask;

  bool _recoveryWarningAcknowledged = false;
  bool _legacyRequested = false;

  @override
  Future<InitFlowState> build() async {
    ref.keepAlive();

    // This marker survives internal file and preference clearing. It takes
    // priority over legacy records, whose files may already have been removed.
    await ref.read(freshStartRecoveryRunnerProvider).call();

    // An unfinished legacy write takes priority over reconciliation.
    if (ref.read(dataRestoreIsAndroidProvider)) {
      final record = await ref.read(legacyMigrationRecordProvider.future);
      StorageOperationGate.recoveryRequired = record?.requiresRecovery ?? false;
      if (record?.requiresRecovery == true) return InitFlowState.restorePrompt;
    }

    // 1. 必須の初期化処理（マイグレーション、操作復旧）を実行
    try {
      await (_initTask ??= _ensureInitialized());
    } catch (e) {
      _initTask = null; // リトライ可能にするためキャッシュをクリア
      rethrow;
    }

    if (!_recoveryWarningAcknowledged &&
        ref.read(missingCommittedTrashCountProvider) > 0) {
      return InitFlowState.recoveryWarning;
    }

    AppLogger.i(LogTag.lifecycle, '初期化フローの状態判定を開始');
    final stopwatch = AppLogger.startTimer(LogTag.lifecycle, '状態判定');

    final prefs = await ref.read(sharedPreferencesProvider.future);

    if (ref.read(dataRestoreIsAndroidProvider)) {
      if (_legacyRequested) return InitFlowState.restorePrompt;
      final welcomeHandled =
          prefs.getBool(AppPreferences.legacyWelcomeHandledKey) ?? false;
      final alreadyOnboarded =
          prefs.getBool(AppPreferences.onboardingCompletedKey) ?? false;
      if (!alreadyOnboarded &&
          prefs.getString(AppPreferences.legacyEntryChoiceKey) == 'transfer') {
        return InitFlowState.restorePrompt;
      }
      if (!welcomeHandled && !alreadyOnboarded) return InitFlowState.welcome;
      await _ensureLibraryMaintenance();
      final onboardingDone =
          prefs.getBool(AppPreferences.onboardingCompletedKey) ?? false;
      return FeatureFlags.enableOnboarding && !onboardingDone
          ? InitFlowState.onboarding
          : InitFlowState.ready;
    }

    // 2. 状態遷移判定
    // 3.1 復元可能データの検出（新規・再インストール時）
    final storedRestoreHandled = prefs.getBool(
      AppPreferences.restorePromptHandledKey,
    );
    final onboardingDone =
        prefs.getBool(AppPreferences.onboardingCompletedKey) ?? false;

    // 復元確認キーの導入前から利用している端末では、キーが存在しないだけで
    // Androidの公開フォルダ確認を初回導線として再表示しない。
    // 明示的に false の場合と、オンボーディングも未完了の新規・再インストール時は
    // 従来どおり復元確認を行う。
    final restoreHandled = storedRestoreHandled ?? onboardingDone;
    if (storedRestoreHandled == null && onboardingDone) {
      await prefs.setBool(AppPreferences.restorePromptHandledKey, true);
    }
    if (!restoreHandled) {
      final detection = await ref
          .read(dataRestoreNotifierProvider.notifier)
          .detect();
      if (detection.isFailure) {
        final restoreState = ref.read(dataRestoreNotifierProvider);
        if (restoreState.status == DataRestoreStatus.permissionRequired) {
          AppLogger.i(LogTag.lifecycle, '状態: 公開フォルダ確認の権限案内へ遷移');
          AppLogger.endTimer(LogTag.lifecycle, '状態判定', stopwatch);
          return InitFlowState.restorePrompt;
        }
        // 権限待ちや一時的なI/O失敗は「データなし」ではない。完了フラグを
        // 保存せず、次回起動時に再検出できる状態を維持する。
        AppLogger.w(
          LogTag.lifecycle,
          '復元可能データを確認できなかったため次回起動時に再試行します: '
          '${detection.errorOrNull?.message}',
        );
        throw StateError('復元できるデータを確認できませんでした。再試行してください。');
      } else {
        final summary = detection.dataOrNull!;
        if (summary.hasRestorableData && summary.hasAnyItems) {
          AppLogger.i(LogTag.lifecycle, '状態: データ復元通知画面へ遷移');
          AppLogger.endTimer(LogTag.lifecycle, '状態判定', stopwatch);
          return InitFlowState.restorePrompt;
        }

        // 検出が正常終了し、復元対象が存在しない場合だけ完了扱いにする。
        await prefs.setBool(AppPreferences.restorePromptHandledKey, true);
      }
    }

    if (FeatureFlags.enableOnboarding) {
      if (!onboardingDone) {
        AppLogger.i(LogTag.lifecycle, '状態: オンボーディング画面へ遷移');
        AppLogger.endTimer(LogTag.lifecycle, '状態判定', stopwatch);
        return InitFlowState.onboarding;
      }
    }

    AppLogger.i(LogTag.lifecycle, '状態: 準備完了、メイン画面へ遷移');
    AppLogger.endTimer(LogTag.lifecycle, '状態判定', stopwatch);
    return InitFlowState.ready;
  }

  /// マイグレーション・操作復旧・既存データの保守を一度だけ実行する。
  Future<void> _ensureInitialized() async {
    // 0. Isar DBスキーママイグレーション
    try {
      await IsarMigrationHelper().runMigrations();
    } catch (e, st) {
      AppLogger.e(LogTag.lifecycle, 'DBマイグレーションに失敗しました', e, st);
      rethrow;
    }

    // 中断されたストレージ消去は、通常の操作復旧や既存データの保守より先に
    // 完了させる。残存ファイルが同期で再登録されることを防ぐ。
    if (ref.read(storageClearRecoveryEnabledProvider)) {
      try {
        final recoveryResult = await ref
            .read(storageClearRecoveryRunnerProvider)
            .call();
        if (recoveryResult.isFailure) {
          throw recoveryResult.errorOrNull!;
        }
      } catch (e, st) {
        AppLogger.e(LogTag.lifecycle, '起動時ストレージ消去復旧に失敗しました', e, st);
        rethrow;
      }
    }

    if (ref.read(operationRecoveryEnabledProvider)) {
      try {
        final recoveryResult = await ref
            .read(operationRecoveryRunnerProvider)
            .call();
        if (recoveryResult.isFailure) {
          throw recoveryResult.errorOrNull!;
        }
      } catch (e, st) {
        AppLogger.e(LogTag.lifecycle, '起動時ジャーナル復旧に失敗しました', e, st);
        rethrow;
      }
    }

    if (!ref.read(dataRestoreIsAndroidProvider)) {
      await _ensureLibraryMaintenance();
    }
  }

  Future<void> _ensureLibraryMaintenance() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    // 新しい棚は本人のファイルとタグから始める。見本は読み取り専用の
    // プレビュー、プリセットは明示的な取り込みだけで利用できる。
    // 過去に投入した見本や、ユーザーが付けたお気に入りは削除しない。
    await _runStartupMaintenance(
      prefs,
      canRepairTemplates:
          prefs.getBool(_templateCollectionInitializedKey) ?? false,
    );
  }

  Future<void> _runStartupMaintenance(
    SharedPreferences prefs, {
    required bool canRepairTemplates,
  }) async {
    final storedVersion =
        prefs.getInt(AppPreferences.startupMaintenanceVersionKey) ?? 0;
    if (storedVersion >= currentStartupMaintenanceVersion) return;

    var succeeded = true;

    // 旧バージョンのタグ初期値・階層祖先を一度だけ補正する。
    try {
      final ensureUseCase = ref.read(ensureTagDefaultsUseCaseProvider);
      final result = await ensureUseCase.invoke();
      if (result.isFailure) {
        succeeded = false;
        AppLogger.w(
          LogTag.lifecycle,
          'タグ初期値の自動補正に失敗しました: ${result.errorOrNull}',
        );
      }
    } catch (e, st) {
      succeeded = false;
      AppLogger.w(LogTag.lifecycle, 'タグ初期値の自動補正に失敗しました', e, st);
    }

    // 既存環境の保守は維持するが、新規環境の完了条件にはしない。
    if (canRepairTemplates) {
      try {
        final templateService = await ref.read(
          templateCollectionServiceProvider.future,
        );
        // 同じIsarインスタンスへ書き込む可能性があるため、修復は直列で実行する。
        final repairResults = [
          await templateService.repairLegacyCovers(),
          await templateService.repairLegacyWelcomeDirectory(),
          await templateService.repairInvalidRootCollections(),
        ];
        if (repairResults.any((result) => !result)) {
          succeeded = false;
        }
      } catch (e, st) {
        succeeded = false;
        AppLogger.w(LogTag.lifecycle, 'テンプレートカタログの修復に失敗', e, st);
      }
    }

    if (succeeded) {
      final saved = await prefs.setInt(
        AppPreferences.startupMaintenanceVersionKey,
        currentStartupMaintenanceVersion,
      );
      if (saved) {
        AppLogger.i(
          LogTag.lifecycle,
          '起動メンテナンス完了 (version: $currentStartupMaintenanceVersion)',
        );
      } else {
        AppLogger.w(LogTag.lifecycle, '起動メンテナンスの完了状態を保存できませんでした');
      }
    }
  }

  void acknowledgeRecoveryWarning() {
    if (state.asData?.value != InitFlowState.recoveryWarning) return;
    _recoveryWarningAcknowledged = true;
    ref.invalidateSelf();
  }

  void retryRecovery() {
    _initTask = null;
    _recoveryWarningAcknowledged = false;
    ref.invalidateSelf();
  }

  Future<void> _saveEntryChoice(String choice) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!await prefs.setString(AppPreferences.legacyEntryChoiceKey, choice) ||
        !await prefs.setBool(AppPreferences.legacyWelcomeHandledKey, true)) {
      throw StateError('Could not save the startup choice');
    }
  }

  Future<void> chooseLegacyEntry(String choice) async {
    if (!{'first', 'transfer', 'fresh'}.contains(choice)) {
      throw ArgumentError.value(choice);
    }
    if (state.asData?.value != InitFlowState.welcome ||
        !ref.read(dataRestoreIsAndroidProvider)) {
      throw StateError('A fresh start is only available at first launch');
    }
    if (choice != 'transfer') {
      await ref.read(freshStartRunnerProvider).call(choice);
      StorageOperationGate.recoveryRequired = false;
      _legacyRequested = false;
      _initTask = null;
      ref.invalidateSelf();
      ref.read(freshStartCompletedCallbackProvider).call();
      return;
    }
    await _saveEntryChoice(choice);
    _legacyRequested = true;
    ref.invalidateSelf();
  }

  Future<void> deferLegacyTransfer() async {
    if (state.asData?.value != InitFlowState.restorePrompt) return;
    ref.invalidate(legacyMigrationRecordProvider);
    final record = await ref.read(legacyMigrationRecordProvider.future);
    if (record?.requiresRecovery == true) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    // Continuation/settings users never have their onboarding state cleared.
    if (prefs.getBool(AppPreferences.onboardingCompletedKey) == true) {
      _legacyRequested = false;
      ref.invalidateSelf();
      return;
    }
    if (!await prefs.remove(AppPreferences.legacyWelcomeHandledKey) ||
        !await prefs.remove(AppPreferences.legacyEntryChoiceKey)) {
      throw StateError('Could not return to the startup choice');
    }
    _legacyRequested = false;
    ref.invalidateSelf();
  }

  Future<void> completeRestorePrompt({bool restored = false}) async {
    if (ref.read(dataRestoreIsAndroidProvider)) {
      ref.invalidate(legacyMigrationRecordProvider);
      final record = await ref.read(legacyMigrationRecordProvider.future);
      if (record?.requiresRecovery == true) return;
      if (record?.completedOutcome != LegacyOutcome.restored) {
        await deferLegacyTransfer();
        return;
      }
      await _saveEntryChoice('later');
      _legacyRequested = false;
      await completeOnboarding();
      return;
    }
    AppLogger.i(LogTag.lifecycle, 'データ復元プロンプト完了 (復元実行: $restored)');
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(AppPreferences.restorePromptHandledKey, true);
    if (restored) {
      await prefs.setBool(AppPreferences.onboardingCompletedKey, true);
      final tutorialNotifier = ref.read(tutorialStateProvider.notifier);
      await tutorialNotifier.complete('library');
      await tutorialNotifier.complete('home');
    }
    ref.invalidateSelf();
  }

  Future<void> completeOnboarding({bool skipped = false}) async {
    AppLogger.i(LogTag.lifecycle, 'オンボーディング完了');
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!await prefs.setBool(AppPreferences.onboardingCompletedKey, true)) {
      throw StateError('Could not save onboarding completion');
    }
    await prefs.setInt(
      AppPreferences.lastSelectedTabKey,
      AppPreferences.libraryTabIndex,
    );
    // 「スキップ」は案内をまとめて閉じる操作として扱い、直後に別の
    // チュートリアルを重ねて表示しない。
    final tutorialNotifier = ref.read(tutorialStateProvider.notifier);
    await tutorialNotifier.complete('library');
    await tutorialNotifier.complete('home');
    ref.invalidateSelf();
  }
}

final initializationFlowAsyncProvider =
    AsyncNotifierProvider<InitializationFlowNotifier, InitFlowState>(
      InitializationFlowNotifier.new,
    );

/// 互換性Provider（常に値が欲しい場面用）
final initializationFlowProvider = Provider<InitFlowState>((ref) {
  return ref.watch(initializationFlowAsyncProvider).value ??
      InitFlowState.launch;
});
