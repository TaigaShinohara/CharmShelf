// audit: allow-file-io
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/providers/isar_provider.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/services/private_storage_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/storage_operation_gate.dart';
import '../../library/domain/models/collection.dart';
import '../../library/domain/models/media_item.dart';
import '../../library/domain/models/reference_migration.dart';
import '../../library/domain/models/storage_ref.dart';
import '../../library/domain/models/tag.dart';
import '../../library/domain/models/tag_facet.dart';
import '../../library/domain/models/viewing_history.dart';
import '../../settings/data/services/storage_clear_service.dart';
import 'fresh_start_recovery_store.dart';

/// 生成だけではDBや資格情報を開かない。起動時のpending確認はmarkerだけを読む。
final freshStartServiceProvider = Provider<FreshStartService>((ref) {
  return FreshStartService(
    clearStorage: () async {
      final service = await ref.read(storageClearServiceProvider.future);
      _requireSuccess(await service.clearStorage());
    },
    recoverStorage: () async {
      final service = await ref.read(storageClearServiceProvider.future);
      _requireSuccess(await service.recoverPendingClear());
    },
    hasPendingStorageClear: () async {
      final service = await ref.read(storageClearServiceProvider.future);
      return service.hasPendingClear();
    },
    preferences: () => ref.read(sharedPreferencesProvider.future),
    deleteCredentials: () async {
      _requireSuccess(await ref.read(secureStorageServiceProvider).deleteAll());
    },
    hasCredentials: () async {
      final result = await ref.read(secureStorageServiceProvider).readAll();
      return result.when(
        success: (values) => values.isNotEmpty,
        failure: (error) => throw error,
      );
    },
    hasStorageData: () async {
      final isar = await ref.read(isarProvider.future);
      return FreshStartService.hasPersistedStorageData(isar);
    },
  );
});

void _requireSuccess(Result<void, AppError> result) {
  if (result.isFailure) throw result.errorOrNull!;
}

/// 初回画面で明示的に確定された開始だけを初期化する。
/// 通常利用から呼べるかどうかは初回画面・起動側が判定する。
class FreshStartService {
  FreshStartService({
    FreshStartRecoveryStore? recoveryStore,
    required this._clearStorage,
    required this._recoverStorage,
    required this._hasPendingStorageClear,
    required this._preferences,
    required this._deleteCredentials,
    required this._hasCredentials,
    required this._hasStorageData,
  }) : _recoveryStore = recoveryStore ?? FreshStartRecoveryStore();

  final FreshStartRecoveryStore _recoveryStore;
  final Future<void> Function() _clearStorage;
  final Future<void> Function() _recoverStorage;
  final Future<bool> Function() _hasPendingStorageClear;
  final Future<SharedPreferences> Function() _preferences;
  final Future<void> Function() _deleteCredentials;
  final Future<bool> Function() _hasCredentials;
  final Future<bool> Function() _hasStorageData;

  Future<bool> hasPending() async => await _recoveryStore.readState() != null;

  Future<void> start(String entryChoice) =>
      StorageOperationGate.maintenance(() async {
        // この保存に失敗した場合は、消去する依存先を一つも開かない。
        await _recoveryStore.markPending(entryChoice);
        StorageOperationGate.recoveryRequired = true;
        await _finishPending();
      });

  /// markerがない通常起動ではDB・資格情報・設定に一切触れない。
  Future<bool> recoverPending() async {
    if (await _recoveryStore.readState() == null) return false;
    return StorageOperationGate.maintenance(() async {
      StorageOperationGate.recoveryRequired = true;
      await _finishPending();
      return true;
    });
  }

  Future<void> _finishPending() async {
    var state = await _recoveryStore.readState();
    if (state == null) {
      throw StateError('The confirmed fresh start marker is missing');
    }
    final entryChoice = state.entryChoice;

    Future<void> advance(FreshStartPhase phase) async {
      await _recoveryStore.writePhase(entryChoice, phase);
      state = FreshStartRecoveryState(entryChoice: entryChoice, phase: phase);
    }

    if (state!.phase == FreshStartPhase.clearingStorage) {
      if (await _hasPendingStorageClear()) {
        await _recoverStorage();
      } else {
        await _clearStorage();
      }
      await advance(FreshStartPhase.clearingCredentials);
    }
    if (state!.phase == FreshStartPhase.clearingCredentials) {
      await _deleteCredentials();
      if (await _hasCredentials()) {
        throw StateError('Credentials remain after fresh start cleanup');
      }
      await advance(FreshStartPhase.clearingPreferences);
    }
    if (state!.phase == FreshStartPhase.clearingPreferences) {
      final preferences = await _preferences();
      if (!await preferences.clear() || preferences.getKeys().isNotEmpty) {
        throw StateError('Preferences remain after fresh start cleanup');
      }
      // 設定保存の失敗時はこのphaseから再開し、消去済みの新データを巻き込まない。
      await advance(FreshStartPhase.finishing);
    }
    final preferences = await _preferences();
    if (!await preferences.setString(
          AppPreferences.legacyEntryChoiceKey,
          entryChoice,
        ) ||
        preferences.getString(AppPreferences.legacyEntryChoiceKey) !=
            entryChoice) {
      throw StateError('Could not persist fresh start choice');
    }
    for (final key in [
      AppPreferences.legacyWelcomeHandledKey,
      AppPreferences.restorePromptHandledKey,
    ]) {
      if (!await preferences.setBool(key, true) ||
          preferences.getBool(key) != true) {
        throw StateError('Could not persist fresh start completion');
      }
    }
    // onboardingCompletedは保存しない。開始後に通常の導入画面を完了してもらう。
    await _recoveryStore.markComplete();
    StorageOperationGate.recoveryRequired = false;
  }

  Future<bool> hasResidualData() async {
    if (await hasPending()) return true;
    final preferences = await _preferences();
    const entryKeys = {
      AppPreferences.onboardingCompletedKey,
      AppPreferences.legacyWelcomeHandledKey,
      AppPreferences.legacyEntryChoiceKey,
      AppPreferences.restorePromptHandledKey,
      AppPreferences.startupMaintenanceVersionKey,
      'app_review.launch_count',
      'app_review.first_launch_at',
      'isar_schema_version',
    };
    if (preferences.getKeys().any(
      (key) =>
          !entryKeys.contains(key) &&
          !key.startsWith('collection_item_links_v1:'),
    )) {
      return true;
    }
    if (await _hasCredentials()) return true;
    return _hasStorageData();
  }

  /// 全schemaのレコードとアプリ私有ファイルを調べる。外部の元ファイルは読まない。
  static Future<bool> hasPersistedStorageData(
    Isar isar, {
    Future<Directory> Function()? privateDirectory,
    Future<Directory> Function()? supportDirectory,
  }) async {
    final counts = await Future.wait([
      isar.mediaItems.count(),
      isar.mediaCollections.count(),
      isar.tags.count(),
      isar.tagFacets.count(),
      isar.storageRefs.count(),
      isar.viewingHistorys.count(),
      isar.referenceMigrations.count(),
    ]);
    if (counts.any((count) => count > 0)) return true;

    final root = await (privateDirectory ?? getPrivateStorageDirectory)();
    final databasePath = isar.path;
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        final path = entity.absolute.path;
        if (databasePath != null &&
            (path == databasePath || path == '$databasePath.lock')) {
          continue;
        }
        if (entity is Directory && p.basename(entity.path) == '.tagshelf') {
          await for (final metadata in entity.list(
            recursive: true,
            followLinks: false,
          )) {
            if (metadata is! Directory) return true;
          }
          continue;
        }
        return true;
      }
    }

    final support =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final deviceIndex = File(p.join(support.path, 'device_files_v1.json'));
    if (!await deviceIndex.exists()) return false;
    final decoded = jsonDecode(await deviceIndex.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['entries'] is! List ||
        decoded['labels'] is! Map ||
        decoded['excluded'] is! List) {
      throw const FormatException('Invalid device file index');
    }
    return (decoded['entries'] as List<dynamic>).isNotEmpty ||
        (decoded['labels'] as Map<String, dynamic>).isNotEmpty ||
        (decoded['excluded'] as List<dynamic>).isNotEmpty ||
        decoded['indexedAt'] != null ||
        decoded['skipped'] != 0;
  }
}
