import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/core/services/import_copy_artifacts.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OperationJournalService 耐障害性テスト', () {
    late Directory tempDir;
    late OperationJournalService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('journal_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      service = OperationJournalService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('正常なジャーナルエントリの読み書きと削除が動作する', () async {
      const entry = OperationJournalEntry(
        id: 'test-1',
        kind: OperationKind.delete,
        stage: OperationStage.planned,
        payload: {
          'rootItemId': 1,
          'originalPath': 'library/sample.jpg',
          'trashPath': '.trash/test-1/sample.jpg',
          'isLocal': true,
        },
      );

      await service.write(entry);
      final entries = await service.readAll();

      expect(entries.length, 1);
      expect(entries.first.id, 'test-1');
      expect(entries.first.kind, OperationKind.delete);

      await service.remove('test-1');
      final remaining = await service.readAll();
      expect(remaining, isEmpty);
    });

    test('importの一時パスはoperation IDと保存先に結び付いた記録だけを許可する', () async {
      final artifacts = ImportCopyArtifacts(
        operationId: 'copy-1',
        destinationPath: 'library/a.jpg',
      );
      final entry = OperationJournalEntry(
        id: 'copy-1',
        kind: OperationKind.import,
        stage: OperationStage.planned,
        payload: {
          'path': artifacts.destinationPath,
          'copyArtifacts': artifacts.toMap(),
        },
      );
      await service.write(entry);
      expect(
        (await service.readAll()).single.payload['copyArtifacts'],
        artifacts.toMap(),
      );
      for (final changed in [
        {
          ...artifacts.toMap(),
          'partialPath': 'library/a.jpg.another.tagshelf-part',
        },
        {...artifacts.toMap(), 'partialPath': '../source.jpg'},
        {...artifacts.toMap(), 'reservationPath': 'library/user.jpg'},
        {...artifacts.toMap(), 'version': 2},
      ]) {
        final invalid = entry.copyWith(
          payload: {...entry.payload, 'copyArtifacts': changed},
        );
        expect(invalid.validate, throwsA(isA<FormatException>()));
      }
      const legacy = OperationJournalEntry(
        id: 'old-import',
        kind: OperationKind.import,
        stage: OperationStage.staged,
        payload: {'path': 'library/old.jpg', 'thumbnailPath': null},
      );
      await service.write(legacy);
      expect(await service.readAll(), hasLength(2));
    });

    test('clearAllは正常・一時・隔離済みの全ジャーナルを削除する', () async {
      final journalDir = Directory('${tempDir.path}/operation_journal');
      await journalDir.create(recursive: true);
      await File('${journalDir.path}/planned.json').writeAsString('{}');
      await File('${journalDir.path}/writing.json.tmp').writeAsString('{}');
      await File('${journalDir.path}/broken.json.corrupt').writeAsString('{}');

      await service.clearAll();

      expect(await journalDir.list().isEmpty, isTrue);
    });

    test('意味的に不正なpayloadを隔離し、次回読込でも実行対象にしない', () async {
      final journalDir = Directory('${tempDir.path}/operation_journal');
      await journalDir.create(recursive: true);
      final invalid = File('${journalDir.path}/invalid-payload.json');
      await invalid.writeAsString(
        jsonEncode({
          'version': 1,
          'id': 'invalid-payload',
          'kind': 'delete',
          'stage': 'planned',
          'payload': {
            'rootItemId': 'not-an-int',
            'originalPath': 'library/sample.jpg',
            'trashPath': '.trash/invalid-payload/sample.jpg',
            'isLocal': true,
          },
        }),
      );

      final first = await service.readReport();
      final second = await service.readReport();

      expect(first.entries, isEmpty);
      expect(first.quarantinedOperationIds, {'invalid-payload'});
      expect(second.entries, isEmpty);
      expect(second.quarantinedOperationIds, {'invalid-payload'});
      expect(await File('${invalid.path}.corrupt').exists(), isTrue);
    });

    test('ファイル名と異なるIDや管理領域外パスを隔離する', () async {
      final journalDir = Directory('${tempDir.path}/operation_journal');
      await journalDir.create(recursive: true);
      await File('${journalDir.path}/expected-id.json').writeAsString(
        jsonEncode({
          'version': 1,
          'id': '../unexpected',
          'kind': 'import',
          'stage': 'staged',
          'payload': {'path': '../outside.jpg', 'thumbnailPath': null},
        }),
      );

      final report = await service.readReport();

      expect(report.entries, isEmpty);
      expect(report.quarantinedOperationIds, {'expected-id'});
    });

    test('削除対象と無関係な退避先・清掃パスを持つjournalを隔離する', () async {
      final journalDir = Directory('${tempDir.path}/operation_journal');
      await journalDir.create(recursive: true);
      final invalid = File('${journalDir.path}/delete-mismatch.json');
      await invalid.writeAsString(
        jsonEncode({
          'version': 1,
          'id': 'delete-mismatch',
          'kind': 'delete',
          'stage': 'committed',
          'payload': {
            'rootItemId': 1,
            'originalPath': 'library/a.jpg',
            'trashPath': '.trash/another/b.jpg',
            'isLocal': true,
            'cleanupPaths': ['library/unrelated.jpg'],
          },
        }),
      );

      final report = await service.readReport();

      expect(report.entries, isEmpty);
      expect(report.quarantinedOperationIds, {'delete-mismatch'});
    });

    test('破損したジャーナルファイルが存在してもスキップして隔離し、正常なエントリを読み出せる', () async {
      // 1. 正常なエントリ
      const validEntry = OperationJournalEntry(
        id: 'valid-1',
        kind: OperationKind.import,
        stage: OperationStage.staged,
        payload: {'path': 'library/valid.jpg', 'thumbnailPath': null},
      );
      await service.write(validEntry);

      // 2. 不正なJSONファイル（破損ジャーナル）を作成
      final journalDir = Directory('${tempDir.path}/operation_journal');
      final corruptFile = File('${journalDir.path}/corrupt-1.json');
      await corruptFile.writeAsString(
        '{ "version": 1, "id": "corrupt-1", invalid json ...',
      );

      // 3. 不正なスキーマのJSONファイルを作成
      final badSchemaFile = File('${journalDir.path}/bad-schema.json');
      await badSchemaFile.writeAsString(jsonEncode({'unknown_key': 123}));

      // 読み出しを実行
      final report = await service.readReport();

      // 正常なエントリのみ取得できること
      expect(report.entries.length, 1);
      expect(report.entries.first.id, 'valid-1');
      expect(
        report.quarantinedOperationIds,
        equals({'corrupt-1', 'bad-schema'}),
      );

      // 破損ファイルが .corrupt にリネームされていること
      expect(
        await File('${journalDir.path}/corrupt-1.json.corrupt').exists(),
        isTrue,
      );
      expect(
        await File('${journalDir.path}/bad-schema.json.corrupt').exists(),
        isTrue,
      );

      // 隔離済みファイルも次回起動時に引き続き報告すること
      final secondReport = await service.readReport();
      expect(
        secondReport.quarantinedOperationIds,
        equals({'corrupt-1', 'bad-schema'}),
      );
    });
  });
}
