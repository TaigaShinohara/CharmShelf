// QA-only entry point. The preserved baseline library is added only to a
// disposable QA copy as libisar_baseline.so, never to the production source tree.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/reference_migration.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/viewing_history.dart';

import '../tool/performance_qa_package.dart';

const _databaseName = 'native-db-compatibility';
const _baselineLibrary = 'libisar_baseline.so';
const _candidateLibrary = 'libisar.so';
const _mediaUid = 'native-synthetic-media-01';
const _secondUid = 'native-synthetic-media-02';
const _collectionUid = 'native-synthetic-collection';
const _fixtureText = 'Synthetic native database compatibility fixture.\n';
final _fixtureDate = DateTime.utc(2026, 1, 1);
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('old native DB survives candidate writes and cold reopen', (
    tester,
  ) async {
    const expectedPackage = String.fromEnvironment(
      'TAGSHELF_NATIVE_QA_PACKAGE',
    );
    const sourceHash = String.fromEnvironment('TAGSHELF_NATIVE_QA_SOURCE_HASH');
    const baselineHash = String.fromEnvironment(
      'TAGSHELF_NATIVE_QA_BASELINE_SHA256',
    );
    const candidateHash = String.fromEnvironment(
      'TAGSHELF_NATIVE_QA_CANDIDATE_SHA256',
    );

    // These guards precede every storage access and every Isar API call. Never
    // call app.main(): onboarding and the real default library are not fixtures.
    expect(Platform.isAndroid, isTrue);
    expect(kProfileMode, isTrue, reason: 'Use one isolated Profile QA APK');
    expect(
      RegExp(
        r'^com\.tsmusic\.privateshelf\.opensource\.performanceqa[0-9]{1,8}$',
      ).hasMatch(expectedPackage),
      isTrue,
    );
    for (final hash in [sourceHash, baselineHash, candidateHash]) {
      expect(_sha256Pattern.hasMatch(hash), isTrue);
    }
    expect(baselineHash, isNot(candidateHash));
    final packageName = (await PackageInfo.fromPlatform()).packageName;
    requirePerformanceQaPackage(packageName);
    expect(packageName, expectedPackage);
    expect(Abi.current(), Abi.androidArm64);
    final pageSize = DynamicLibrary.open(
      'libc.so',
    ).lookupFunction<Int32 Function(), int Function()>('getpagesize')();
    expect(pageSize, 16384, reason: 'A dedicated 16KB emulator is required');

    final support = await getApplicationSupportDirectory();
    final appData = await support.parent.resolveSymbolicLinks();
    expect(p.basename(appData), packageName);
    final root = Directory(p.join(support.path, 'native-db-compatibility'));
    await root.create(recursive: true);
    expect(p.isWithin(appData, await root.resolveSymbolicLinks()), isTrue);
    final stateFile = File(p.join(root.path, 'state.json'));
    final database = File(p.join(root.path, '$_databaseName.isar'));
    final snapshot = File(p.join(root.path, 'baseline-snapshot.isar'));
    final fixture = File(p.join(root.path, 'synthetic-original.txt'));
    final state = await stateFile.exists()
        ? jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>
        : null;
    final previousPids = <int>[];
    var stage = 'seed-old';
    String? beforeDatabaseHash;
    if (state == null) {
      for (final file in [database, snapshot, fixture]) {
        expect(
          await file.exists(),
          isFalse,
          reason: 'Refusing to reseed an interrupted or existing QA fixture',
        );
      }
    } else {
      expect(state['schema'], 1);
      expect(state['packageName'], packageName);
      expect(state['sourceHash'], sourceHash);
      expect(state['baselineSha256'], baselineHash);
      expect(state['candidateSha256'], candidateHash);
      previousPids.addAll((state['pids'] as List).cast<int>());
      expect(previousPids, isNot(contains(pid)));
      stage = state['nextStage'] as String;
      expect(stage, isIn(['read-write-new', 'verify-new']));
      expect(previousPids, hasLength(stage == 'read-write-new' ? 1 : 2));
      expect(previousPids.toSet(), hasLength(previousPids.length));
      beforeDatabaseHash = await _digest(database);
      expect(beforeDatabaseHash, state['databaseSha256']);
      expect(await _digest(snapshot), state['baselineSnapshotSha256']);
      expect(await fixture.readAsString(), _fixtureText);
    }

    final library = stage == 'seed-old' ? _baselineLibrary : _candidateLibrary;
    // The Isar core is initialized once per process. A cold restart is required
    // before selecting the other library; importing schemas does not open Isar.
    await Isar.initializeIsarCore(
      libraries: {Abi.androidArm64: library},
      download: false,
    );

    late final String nextStage;
    if (stage == 'seed-old') {
      await fixture.writeAsString(_fixtureText, flush: true);
      await _withDatabase(root, (db) async {
        await _seed(db);
        await _expectFixture(db, updated: false);
        await db.copyToFile(snapshot.path);
      });
      await _withDatabase(root, (db) => _expectFixture(db, updated: false));
      nextStage = 'read-write-new';
    } else if (stage == 'read-write-new') {
      await _withDatabase(root, (db) async {
        await _expectFixture(db, updated: false);
        await _update(db);
      });
      await _withDatabase(root, (db) => _expectFixture(db, updated: true));
      nextStage = 'verify-new';
    } else {
      await _withDatabase(root, (db) => _expectFixture(db, updated: true));
      nextStage = 'completed';
    }

    expect(await fixture.readAsString(), _fixtureText);
    final databaseHash = await _digest(database);
    if (stage == 'read-write-new') {
      expect(databaseHash, isNot(beforeDatabaseHash));
    }
    final snapshotHash = await _digest(snapshot);
    if (state != null) {
      expect(snapshotHash, state['baselineSnapshotSha256']);
    }
    final nextState = <String, dynamic>{
      'schema': 1,
      'packageName': packageName,
      'sourceHash': sourceHash,
      'baselineSha256': baselineHash,
      'candidateSha256': candidateHash,
      'nextStage': nextStage,
      'pids': [...previousPids, pid],
      'databaseSha256': databaseHash,
      'baselineSnapshotSha256': snapshotHash,
    };
    final temporary = File('${stateFile.path}.$pid.tmp');
    expect(await temporary.exists(), isFalse);
    await temporary.writeAsString(jsonEncode(nextState), flush: true);
    expect(jsonDecode(await temporary.readAsString()), nextState);
    await temporary.rename(stateFile.path);

    // Only synthetic identifiers and evidence hashes cross the driver boundary.
    // Do not log app-container paths or any database contents.
    binding.reportData = {
      'nativeDbCompatibility': {
        ...nextState,
        'completed': true,
        'stage': stage,
        'pid': pid,
        'previousPids': previousPids,
        'library': library,
        'librarySha256': stage == 'seed-old' ? baselineHash : candidateHash,
        'pageSize': pageSize,
        'abi': 'arm64-v8a',
        'buildMode': 'profile',
        'isarVersion': Isar.version,
        'beforeDatabaseSha256': beforeDatabaseHash,
        'fixtureFileSha256': await _digest(fixture),
        'recordCounts': {
          'mediaItems': stage == 'seed-old' ? 1 : 2,
          'collections': 1,
          'tags': 1,
          'facets': 1,
          'storageRefs': 1,
          'viewingHistory': 1,
          'referenceMigrations': 1,
        },
      },
    };
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<String> _digest(File file) async =>
    (await file.openRead().transform(sha256).first).toString();

Future<void> _withDatabase(
  Directory root,
  Future<void> Function(Isar db) operation,
) async {
  final db = await Isar.open(
    [
      MediaItemSchema,
      TagSchema,
      TagFacetSchema,
      MediaCollectionSchema,
      StorageRefSchema,
      ViewingHistorySchema,
      ReferenceMigrationSchema,
    ],
    directory: root.path,
    name: _databaseName,
    inspector: false,
  );
  try {
    await operation(db);
  } finally {
    // Retain the DB and baseline snapshot for investigation; never clear data.
    expect(await db.close(), isTrue);
  }
}

Future<void> _seed(Isar db) async {
  expect(await db.mediaItems.count(), 0);
  final item = MediaItem()
    ..id = 10
    ..uid = _mediaUid
    ..path = 'native-fixture/original.txt'
    ..originalPath = 'synthetic-original.txt'
    ..addedAt = _fixtureDate
    ..isFavorite = true;
  final facet = TagFacet()
    ..id = 40
    ..name = '合成属性 / Synthetic facet'
    ..createdAt = _fixtureDate;
  final tag = Tag()
    ..id = 30
    ..key = Tag.buildKey(facet.id, '互換性タグ')
    ..name = '互換性タグ'
    ..facetId = facet.id
    ..ancestorIds = [101, 202]
    ..usageCount = 1
    ..createdAt = _fixtureDate;
  final collection = MediaCollection()
    ..id = 20
    ..uid = _collectionUid
    ..path = 'native-fixture'
    ..title = '合成データ / Synthetic ✅'
    ..isCatalog = true
    ..createdAt = _fixtureDate
    ..updatedAt = _fixtureDate;
  final storage = StorageRef()
    ..id = 50
    ..uid = 'native-synthetic-storage'
    ..ownerUid = _mediaUid
    ..ownerType = StorageOwnerType.item
    ..sourceType = StorageSourceType.local
    ..locator = item.path
    ..createdAt = _fixtureDate
    ..updatedAt = _fixtureDate;
  final history = ViewingHistory()
    ..id = 60
    ..itemUid = _mediaUid
    ..openedAt = _fixtureDate;
  final migration = ReferenceMigration()
    ..id = 70
    ..key = 'native-synthetic-migration'
    ..snapshot = jsonEncode({'synthetic': true, 'uid': _mediaUid})
    ..checkpoints = '{"seed":true}'
    ..committed = true
    ..cleanupPending = false;
  await db.writeTxn(() async {
    await db.mediaItems.put(item);
    await db.tagFacets.put(facet);
    await db.tags.put(tag);
    await db.mediaCollections.put(collection);
    await db.storageRefs.put(storage);
    await db.viewingHistorys.put(history);
    await db.referenceMigrations.put(migration);
    collection.items.add(item);
    collection.tags.add(tag);
    await collection.items.save();
    await collection.tags.save();
  });
}

Future<void> _update(Isar db) async {
  final item = (await db.mediaItems.get(10))!;
  final collection = (await db.mediaCollections.get(20))!;
  final tag = (await db.tags.get(30))!;
  final history = (await db.viewingHistorys.get(60))!;
  final second = MediaItem()
    ..id = 11
    ..uid = _secondUid
    ..path = 'native-fixture/second.txt'
    ..addedAt = _fixtureDate.add(const Duration(seconds: 1));
  item.isFavorite = false;
  collection.title = '合成データ更新 / Updated ✅';
  tag.usageCount = 2;
  history.openedAt = _fixtureDate.add(const Duration(minutes: 1));
  await db.writeTxn(() async {
    await db.mediaItems.put(item);
    await db.mediaItems.put(second);
    await db.mediaCollections.put(collection);
    await db.tags.put(tag);
    await db.viewingHistorys.put(history);
    collection.items.add(second);
    await collection.items.save();
  });
}

Future<void> _expectFixture(Isar db, {required bool updated}) async {
  expect(await db.mediaItems.count(), updated ? 2 : 1);
  expect(await db.mediaCollections.count(), 1);
  expect(await db.tags.count(), 1);
  expect(await db.tagFacets.count(), 1);
  expect(await db.storageRefs.count(), 1);
  expect(await db.viewingHistorys.count(), 1);
  expect(await db.referenceMigrations.count(), 1);
  final item = (await db.mediaItems.where().uidEqualTo(_mediaUid).findFirst())!;
  expect(item.id, 10);
  expect(item.path, 'native-fixture/original.txt');
  expect(item.originalPath, 'synthetic-original.txt');
  expect(item.addedAt.toUtc(), _fixtureDate);
  expect(item.isFavorite, !updated);
  final collection = (await db.mediaCollections.get(20))!;
  expect(collection.uid, _collectionUid);
  expect(
    collection.title,
    updated ? '合成データ更新 / Updated ✅' : '合成データ / Synthetic ✅',
  );
  await collection.items.load();
  await collection.tags.load();
  expect(collection.items.map((item) => item.uid).toSet(), {
    _mediaUid,
    if (updated) _secondUid,
  });
  expect(collection.tags.map((tag) => tag.id).toList(), [30]);
  await item.collection.load();
  expect(item.collection.value?.id, 20);
  final tag = (await db.tags.get(30))!;
  expect(tag.name, '互換性タグ');
  expect(tag.ancestorIds, [101, 202]);
  expect(tag.usageCount, updated ? 2 : 1);
  expect((await db.tagFacets.get(40))!.name, '合成属性 / Synthetic facet');
  final storage = (await db.storageRefs.get(50))!;
  expect(storage.ownerUid, _mediaUid);
  expect(storage.locator, item.path);
  expect(storage.ownerType, StorageOwnerType.item);
  final history = (await db.viewingHistorys.get(60))!;
  expect(history.itemUid, _mediaUid);
  expect(
    history.openedAt.toUtc(),
    updated ? _fixtureDate.add(const Duration(minutes: 1)) : _fixtureDate,
  );
  final migration = (await db.referenceMigrations.get(70))!;
  expect(jsonDecode(migration.snapshot), {'synthetic': true, 'uid': _mediaUid});
  expect(migration.committed, isTrue);
  expect(migration.cleanupPending, isFalse);
}
