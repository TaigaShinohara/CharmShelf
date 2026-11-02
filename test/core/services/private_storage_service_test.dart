import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/services/private_storage_service.dart';

void main() {
  late Directory sandbox;
  late Directory source;
  late Directory destination;
  late File marker;
  late PrivateStorageMigrator migrator;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('private_storage_test_');
    source = Directory(p.join(sandbox.path, 'Documents'));
    destination = Directory(p.join(sandbox.path, 'Support', 'PrivateShelf'));
    marker = File(
      p.join(sandbox.path, 'Support', '.private_storage_migration_v1.json'),
    );
    migrator = PrivateStorageMigrator();
    await source.create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('全ファイルを検証して移行し、完了後に旧Documentsの内容を削除する', () async {
    await File(p.join(source.path, 'default.isar')).writeAsBytes([1, 2, 3]);
    final media = File(p.join(source.path, 'library', 'album', 'photo.jpg'));
    await media.parent.create(recursive: true);
    await media.writeAsBytes([4, 5, 6, 7]);
    final metadata = File(p.join(source.path, '.tagshelf', 'metadata.json'));
    await metadata.parent.create(recursive: true);
    await metadata.writeAsString('{"version":2}');

    await migrator.migrate(
      source: source,
      destination: destination,
      marker: marker,
    );

    expect(await File(p.join(destination.path, 'default.isar')).readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(
      await File(
        p.join(destination.path, 'library', 'album', 'photo.jpg'),
      ).readAsBytes(),
      [4, 5, 6, 7],
    );
    expect(await source.exists(), isTrue, reason: 'Documents自体は維持する');
    expect(await source.list().isEmpty, isTrue, reason: '検証完了後だけ内容を削除する');

    final markerJson =
        jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
    expect(markerJson['version'], PrivateStorageMigrator.migrationVersion);
    expect(markerJson['fileCount'], 3);
    expect(markerJson['totalBytes'], greaterThan(0));
    expect(
      await migrator.isComplete(destination: destination, marker: marker),
      isTrue,
    );

    await File(p.join(source.path, 'stale-copy.bin')).writeAsBytes([8]);
    await migrator.migrate(
      source: source,
      destination: destination,
      marker: marker,
    );
    expect(
      await source.list().isEmpty,
      isTrue,
      reason: 'commit後に残った旧コピーも再実行で削除する',
    );
  });

  test('途中終了後は同一ファイルを再利用し、一時ファイルを置換して再開する', () async {
    final first = File(p.join(source.path, 'first.bin'));
    final second = File(p.join(source.path, 'nested', 'second.bin'));
    await first.writeAsBytes([1, 1, 1]);
    await second.parent.create(recursive: true);
    await second.writeAsBytes([2, 2]);

    await destination.create(recursive: true);
    await File(p.join(destination.path, 'first.bin')).writeAsBytes([1, 1, 1]);
    final partial = File(
      p.join(destination.path, 'nested', 'second.bin.migrating'),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes([9]);

    await migrator.migrate(
      source: source,
      destination: destination,
      marker: marker,
    );

    expect(await partial.exists(), isFalse);
    expect(
      await File(
        p.join(destination.path, 'nested', 'second.bin'),
      ).readAsBytes(),
      [2, 2],
    );
    expect(await marker.exists(), isTrue);
    expect(await source.list().isEmpty, isTrue);
  });

  test('コピー先の同名ファイルが異なる場合は上書きせず失敗する', () async {
    await File(p.join(source.path, 'media.bin')).writeAsBytes([1, 2, 3]);
    await destination.create(recursive: true);
    await File(p.join(destination.path, 'media.bin')).writeAsBytes([9, 9, 9]);

    await expectLater(
      migrator.migrate(
        source: source,
        destination: destination,
        marker: marker,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await File(p.join(destination.path, 'media.bin')).readAsBytes(), [
      9,
      9,
      9,
    ]);
    expect(await File(p.join(source.path, 'media.bin')).exists(), isTrue);
    expect(await marker.exists(), isFalse);
  });

  test('壊れた完了マーカーは信頼せず再検証して置き換える', () async {
    await File(p.join(source.path, 'media.bin')).writeAsBytes([1, 2, 3]);
    await destination.create(recursive: true);
    await File(p.join(destination.path, 'media.bin')).writeAsBytes([1, 2, 3]);
    await marker.parent.create(recursive: true);
    await marker.writeAsString('{broken');

    await migrator.migrate(
      source: source,
      destination: destination,
      marker: marker,
    );

    expect(
      await migrator.isComplete(destination: destination, marker: marker),
      isTrue,
    );
    expect(
      jsonDecode(await marker.readAsString()),
      isA<Map<String, dynamic>>(),
    );
    expect(await source.list().isEmpty, isTrue);
  });
}
