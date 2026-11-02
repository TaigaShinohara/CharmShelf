import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/device_files/data/device_file_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';
import 'package:private_shelf/features/onboarding/data/fresh_start_recovery_store.dart';
import 'package:private_shelf/features/onboarding/data/fresh_start_service.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_recovery_store.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late _FailingStore store;
  late _Harness harness;

  setUp(() async {
    final fixtures = Directory('build/test-fixtures/fresh-start-service');
    await fixtures.create(recursive: true);
    support = await fixtures.createTemp('support-');
    store = _FailingStore(support);
    harness = _Harness(store);
    StorageOperationGate.recoveryRequired = false;
  });

  tearDown(() async {
    StorageOperationGate.recoveryRequired = false;
    if (await support.exists()) await support.delete(recursive: true);
  });

  test('provider構築時はDBと設定を開かない', () {
    var opened = 0;
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWith((ref) async {
          opened++;
          throw StateError('Unexpected database open');
        }),
        sharedPreferencesProvider.overrideWith((ref) async {
          opened++;
          throw StateError('Unexpected preferences open');
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(freshStartServiceProvider), isA<FreshStartService>());
    expect(opened, 0);
  });

  test('pendingなしの復旧確認はDB・資格情報・設定を開かない', () async {
    expect(await harness.service.recoverPending(), isFalse);
    expect(harness.events, isEmpty);
    expect(harness.preferenceOpens, 0);
  });

  test('確定markerの保存失敗なら消去ゼロ', () async {
    store.failPhase = FreshStartPhase.clearingStorage;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect(harness.events, isEmpty);
    expect(harness.preferenceOpens, 0);
    expect(harness.preferences.values['old_setting'], 'kept');
    expect(await store.readState(), isNull);
  });

  for (final choice in ['first', 'fresh']) {
    test('$choiceは依存順で全消去を検証し導入未完了で開始する', () async {
      await harness.service.start(choice);
      expect(harness.events, [
        'storage',
        'credentials',
        'preferences',
        AppPreferences.legacyEntryChoiceKey,
        AppPreferences.legacyWelcomeHandledKey,
        AppPreferences.restorePromptHandledKey,
      ]);
      expect(harness.preferences.values, {
        AppPreferences.legacyEntryChoiceKey: choice,
        AppPreferences.legacyWelcomeHandledKey: true,
        AppPreferences.restorePromptHandledKey: true,
      });
      expect(harness.credentials, isEmpty);
      expect(await store.readState(), isNull);
      expect(StorageOperationGate.recoveryRequired, isFalse);
    });
  }

  test('legacy復旧必須状態でも確認済みfresh-startを実行できる', () async {
    StorageOperationGate.recoveryRequired = true;
    await harness.service.start('fresh');
    expect(await store.readState(), isNull);
    expect(StorageOperationGate.recoveryRequired, isFalse);
  });

  test('他のstorage操作と競合したらmarker保存前に止まる', () async {
    await StorageOperationGate.run(() async {
      await expectLater(
        harness.service.start('fresh'),
        throwsA(isA<StorageOperationBusy>()),
      );
    });
    expect(await store.readState(), isNull);
    expect(harness.events, isEmpty);
  });

  test('storageの途中失敗は資格情報と設定を消さず次回復旧する', () async {
    harness.failStorage = true;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect(harness.events, ['storage']);
    expect(harness.preferences.values['old_setting'], 'kept');
    expect(harness.credentials, isNotEmpty);
    expect((await store.readState())!.phase, FreshStartPhase.clearingStorage);
    expect(StorageOperationGate.recoveryRequired, isTrue);
    harness.failStorage = false;
    expect(await harness.service.recoverPending(), isTrue);
    expect(harness.events.take(2), ['storage', 'recoverStorage']);
    expect(await store.readState(), isNull);
  });

  test('credential削除失敗・残留はstorageを再消去せず再試行', () async {
    harness.leaveCredentials = true;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect(
      (await store.readState())!.phase,
      FreshStartPhase.clearingCredentials,
    );
    expect(harness.events, ['storage', 'credentials']);
    harness.leaveCredentials = false;
    expect(await harness.service.recoverPending(), isTrue);
    expect(harness.events.where((event) => event == 'storage').length, 1);
    expect(harness.credentials, isEmpty);
  });

  test('prefs.clear falseを成功扱いせず再試行する', () async {
    harness.preferences.failClear = true;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect(
      (await store.readState())!.phase,
      FreshStartPhase.clearingPreferences,
    );
    expect(harness.preferences.values['old_setting'], 'kept');
    harness.preferences.failClear = false;
    expect(await harness.service.recoverPending(), isTrue);
    expect(harness.events.where((event) => event == 'storage').length, 1);
    expect(harness.events.where((event) => event == 'credentials').length, 1);
  });

  test('prefs.clear trueでも残留keyがあれば完了しない', () async {
    harness.preferences.leaveKeys = true;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect(
      (await store.readState())!.phase,
      FreshStartPhase.clearingPreferences,
    );
    expect(
      harness.preferences.values.containsKey(
        AppPreferences.legacyWelcomeHandledKey,
      ),
      isFalse,
    );
    harness.preferences.leaveKeys = false;
    expect(await harness.service.recoverPending(), isTrue);
  });

  for (final phase in FreshStartPhase.values.skip(1)) {
    test('$phaseへの保存失敗後もpendingを残して復旧できる', () async {
      store.failPhase = phase;
      await expectLater(harness.service.start('fresh'), throwsStateError);
      expect(await store.readState(), isNotNull);
      expect(StorageOperationGate.recoveryRequired, isTrue);
      store.failPhase = null;
      expect(await harness.service.recoverPending(), isTrue);
      expect(await store.readState(), isNull);
    });
  }

  for (final key in [
    AppPreferences.legacyEntryChoiceKey,
    AppPreferences.legacyWelcomeHandledKey,
    AppPreferences.restorePromptHandledKey,
  ]) {
    test('$key保存false後はfinishingから再試行し新データを再消去しない', () async {
      harness.preferences.failSaveKey = key;
      await expectLater(harness.service.start('fresh'), throwsStateError);
      expect((await store.readState())!.phase, FreshStartPhase.finishing);
      harness.preferences.values['new_data'] = 'kept';
      harness.preferences.failSaveKey = null;
      expect(await harness.service.recoverPending(), isTrue);
      expect(harness.preferences.values['new_data'], 'kept');
      expect(harness.events.where((event) => event == 'storage').length, 1);
      expect(harness.events.where((event) => event == 'preferences').length, 1);
    });
  }

  test('marker削除失敗は成功扱いせず完了保存だけ再試行', () async {
    store.failComplete = true;
    await expectLater(harness.service.start('fresh'), throwsStateError);
    expect((await store.readState())!.phase, FreshStartPhase.finishing);
    expect(StorageOperationGate.recoveryRequired, isTrue);
    store.failComplete = false;
    expect(await harness.service.recoverPending(), isTrue);
    expect(harness.events.where((event) => event == 'storage').length, 1);
    expect(harness.events.where((event) => event == 'preferences').length, 1);
  });

  test('残留は設定・資格情報・storageそれぞれで検出する', () async {
    expect(await harness.service.hasResidualData(), isTrue);
    harness.preferences.values.clear();
    expect(await harness.service.hasResidualData(), isTrue);
    harness.credentials.clear();
    harness.hasStorageData = true;
    expect(await harness.service.hasResidualData(), isTrue);
    harness.hasStorageData = false;
    harness.preferences.values.addAll({
      AppPreferences.onboardingCompletedKey: false,
      AppPreferences.startupMaintenanceVersionKey: 1,
      'collection_item_links_v1:empty-database': true,
      'app_review.launch_count': 1,
      'app_review.first_launch_at': 'test-timestamp',
      'isar_schema_version': 1,
    });
    expect(await harness.service.hasResidualData(), isFalse);
  });

  test('隔離fixtureの全schemaと私有コピーを消去し外部元ファイル・バックアップを保持', () async {
    final privateRoot = Directory('${support.path}/private').absolute;
    final cache = Directory('${support.path}/cache');
    final external = Directory('${support.path}/external');
    await privateRoot.create(recursive: true);
    await cache.create();
    await external.create();
    final isar = await Isar.open(
      [
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
        ViewingHistorySchema,
        ReferenceMigrationSchema,
      ],
      directory: privateRoot.path,
      name: 'fresh_start_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final metadata = Directory('${privateRoot.path}/.tagshelf');
      await metadata.create();
      Future<bool> hasStorageData() =>
          FreshStartService.hasPersistedStorageData(
            isar,
            privateDirectory: () async => privateRoot,
            supportDirectory: () async => support,
          );
      expect(await hasStorageData(), isFalse);
      final deviceIndex = File('${support.path}/device_files_v1.json');
      final deviceRepository = DeviceFileRepository(deviceIndex);
      await deviceRepository.clear();
      expect(await hasStorageData(), isFalse);
      await deviceRepository.setExcluded({'content://external/kept'});
      expect(await hasStorageData(), isTrue);
      await deviceRepository.clear();

      // どのschemaのレコードだけが残っていても確認対象になる。
      final now = DateTime(2026);
      final insertions = <Future<void> Function()>[
        () async {
          await isar.mediaItems.put(MediaItem());
        },
        () async {
          await isar.mediaCollections.put(MediaCollection());
        },
        () async {
          await isar.tags.put(Tag());
        },
        () async {
          await isar.tagFacets.put(
            TagFacet()
              ..name = 'old'
              ..createdAt = now,
          );
        },
        () async {
          await isar.storageRefs.put(
            StorageRef()
              ..ownerUid = 'test-owner'
              ..ownerType = StorageOwnerType.item
              ..sourceType = StorageSourceType.external
              ..locator = 'content://external/kept'
              ..createdAt = now
              ..updatedAt = now,
          );
        },
        () async {
          await isar.viewingHistorys.put(ViewingHistory());
        },
        () async {
          await isar.referenceMigrations.put(
            ReferenceMigration()
              ..key = 'old'
              ..snapshot = '{}',
          );
        },
      ];
      for (final insert in insertions) {
        await isar.writeTxn(() async {
          await isar.clear();
          await insert();
        });
        expect(await hasStorageData(), isTrue);
      }
      // 全schemaを同時に含む実データでStorageClearServiceとの接続も検証する。
      await isar.writeTxn(() async {
        await isar.clear();
        for (final insert in insertions) {
          await insert();
        }
      });
      final privateCopy = File('${privateRoot.path}/encrypted-copy.bin');
      final cacheCopy = File('${cache.path}/thumbnail.jpg');
      final original = File('${external.path}/original.txt');
      final backup = File('${external.path}/backup.zip');
      await privateCopy.writeAsString('private fixture');
      await cacheCopy.writeAsString('cache fixture');
      await original.writeAsString('external original fixture');
      await backup.writeAsString('external backup fixture');
      var released = false;
      final clearService = StorageClearService(
        isar,
        LocalStorageManager(
          privateRootDirectory: privateRoot,
          isAndroid: false,
        ),
        recoveryStore: StorageClearRecoveryStore(
          supportDirectory: () async => support,
        ),
        temporaryDirectory: () async => cache,
        clearTransientPreferences: deviceRepository.clear,
        releaseAllExternalAccess: () async {
          released = true;
        },
      );
      final service = FreshStartService(
        recoveryStore: store,
        clearStorage: () async {
          final result = await clearService.clearStorage();
          if (result.isFailure) throw result.errorOrNull!;
        },
        recoverStorage: () async {
          final result = await clearService.recoverPendingClear();
          if (result.isFailure) throw result.errorOrNull!;
        },
        hasPendingStorageClear: clearService.hasPendingClear,
        preferences: () async => harness.preferences,
        deleteCredentials: () async {
          expect(await privateCopy.exists(), isFalse);
          expect(released, isTrue);
          harness.credentials.clear();
        },
        hasCredentials: () async => harness.credentials.isNotEmpty,
        hasStorageData: hasStorageData,
      );
      await service.start('fresh');
      expect(await hasStorageData(), isFalse);
      expect(await privateCopy.exists(), isFalse);
      expect(await cacheCopy.exists(), isFalse);
      expect(await original.readAsString(), 'external original fixture');
      expect(await backup.readAsString(), 'external backup fixture');
      expect(await store.readState(), isNull);
    } finally {
      await isar.close(deleteFromDisk: true);
    }
  });
}

class _FailingStore extends FreshStartRecoveryStore {
  _FailingStore(Directory support)
    : super(supportDirectory: () async => support);

  FreshStartPhase? failPhase;
  bool failComplete = false;

  @override
  Future<void> writePhase(String entryChoice, FreshStartPhase phase) async {
    if (failPhase == phase) throw StateError('Simulated phase write failure');
    await super.writePhase(entryChoice, phase);
  }

  @override
  Future<void> markComplete() async {
    if (failComplete) throw StateError('Simulated marker delete failure');
    await super.markComplete();
  }
}

class _Harness {
  _Harness(FreshStartRecoveryStore store) {
    preferences = _Preferences(events);
    service = FreshStartService(
      recoveryStore: store,
      clearStorage: () async {
        events.add('storage');
        pendingStorage = true;
        if (failStorage) throw StateError('Simulated internal storage failure');
        pendingStorage = false;
      },
      recoverStorage: () async {
        events.add('recoverStorage');
        if (failStorage) throw StateError('Simulated internal storage failure');
        pendingStorage = false;
      },
      hasPendingStorageClear: () async => pendingStorage,
      preferences: () async {
        preferenceOpens++;
        return preferences;
      },
      deleteCredentials: () async {
        events.add('credentials');
        if (!leaveCredentials) credentials.clear();
      },
      hasCredentials: () async => credentials.isNotEmpty,
      hasStorageData: () async => hasStorageData,
    );
  }

  late final FreshStartService service;
  late final _Preferences preferences;
  final events = <String>[];
  final credentials = <String>{'test_credential'};
  bool pendingStorage = false;
  bool failStorage = false;
  bool leaveCredentials = false;
  bool hasStorageData = false;
  int preferenceOpens = 0;
}

class _Preferences extends Fake implements SharedPreferences {
  _Preferences(this.events);
  final List<String> events;
  final values = <String, Object>{'old_setting': 'kept'};
  bool failClear = false;
  bool leaveKeys = false;
  String? failSaveKey;

  @override
  Set<String> getKeys() => values.keys.toSet();

  @override
  Future<bool> clear() async {
    events.add('preferences');
    if (failClear) return false;
    if (!leaveKeys) values.clear();
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    events.add(key);
    values[key] = value;
    return failSaveKey != key;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    events.add(key);
    values[key] = value;
    return failSaveKey != key;
  }

  @override
  String? getString(String key) => values[key] as String?;

  @override
  bool? getBool(String key) => values[key] as bool?;
}
