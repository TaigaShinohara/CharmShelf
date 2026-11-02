import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/import_copy_artifacts.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  MockPathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late FileService service;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('file_service_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(documents.path);
    service = FileService();
    await Directory(p.join(documents.path, 'library')).create();
  });

  tearDown(() async {
    if (await documents.exists()) {
      await documents.delete(recursive: true);
    }
  });

  test(
    'copyEntity rejects an existing file without changing its content',
    () async {
      final source = File(p.join(documents.path, 'library', 'source.txt'));
      final destination = File(
        p.join(documents.path, 'library', 'destination.txt'),
      );
      await source.writeAsString('source');
      await destination.writeAsString('keep');

      final result = await service.copyEntity(
        'library/source.txt',
        'library/destination.txt',
      );

      expect(result.isFailure, isTrue);
      expect(await source.readAsString(), 'source');
      expect(await destination.readAsString(), 'keep');
    },
  );

  test(
    'copyEntity rejects an existing directory instead of merging into it',
    () async {
      final source = Directory(p.join(documents.path, 'library', 'source'));
      final destination = Directory(
        p.join(documents.path, 'library', 'destination'),
      );
      await source.create();
      await destination.create();
      await File(p.join(source.path, 'source.txt')).writeAsString('source');
      await File(p.join(destination.path, 'keep.txt')).writeAsString('keep');

      final result = await service.copyEntity(
        'library/source',
        'library/destination',
      );

      expect(result.isFailure, isTrue);
      expect(
        await File(p.join(destination.path, 'keep.txt')).readAsString(),
        'keep',
      );
      expect(
        File(p.join(destination.path, 'source.txt')).existsSync(),
        isFalse,
      );
    },
  );

  test('importFileは選択後に容量が変わったファイルをコピーしない', () async {
    final source = File(p.join(documents.path, 'source.jpg'));
    await source.writeAsBytes([1, 2, 3, 4]);

    final result = await service.importFile(source, expectedBytes: 3);

    expect(result.isFailure, isTrue);
    expect(
      await Directory(p.join(documents.path, 'library')).list().toList(),
      isEmpty,
    );
  });

  test('importFileは上限内かつ容量一致の通常ファイルをコピーする', () async {
    final source = File(p.join(documents.path, 'source.jpg'));
    await source.writeAsBytes([1, 2, 3]);

    final result = await service.importFile(
      source,
      maxBytes: 3,
      expectedBytes: 3,
    );

    expect(result.isSuccess, isTrue);
    expect(
      await File(p.join(documents.path, result.dataOrNull!)).readAsBytes(),
      [1, 2, 3],
    );
  });

  test('同名ファイルの並行インポートは排他的に別名へ確定する', () async {
    final source = File(p.join(documents.path, 'same.jpg'));
    await source.writeAsBytes([1, 2, 3]);

    final results = await Future.wait([
      service.importFile(source, sourceFileName: 'same.jpg'),
      service.importFile(source, sourceFileName: 'same.jpg'),
    ]);

    expect(results.every((result) => result.isSuccess), isTrue);
    expect(results.map((result) => result.dataOrNull).toSet(), hasLength(2));
    final names = await Directory(
      p.join(documents.path, 'library'),
    ).list().map((entity) => p.basename(entity.path)).toList();
    expect(
      names.where((name) => name.endsWith('.tagshelf-reservation')),
      isEmpty,
    );
  });

  test('コピーの正確な所有パスを作成前に記録し元ファイルと他者の予約を保護する', () async {
    final source = File(p.join(documents.path, 'source.jpg'));
    await source.writeAsBytes([1, 2, 3]);
    final otherReservation = File(
      p.join(documents.path, 'library', 'same.jpg.tagshelf-reservation'),
    );
    await otherReservation.writeAsString('another operation');
    final planned = <ImportCopyArtifacts>[];
    final result = await service.importFile(
      source,
      sourceFileName: 'same.jpg',
      importOperationId: 'exact-operation',
      onDestinationPrepared: (path) async {
        final artifacts = ImportCopyArtifacts(
          operationId: 'exact-operation',
          destinationPath: path,
        );
        planned.add(artifacts);
        expect(FileService.isImportActive('exact-operation'), isTrue);
        expect(
          await File(p.join(documents.path, artifacts.partialPath)).exists(),
          isFalse,
        );
      },
    );
    expect(result.dataOrNull, 'library/same_2.jpg');
    expect(planned.map((entry) => entry.destinationPath), [
      'library/same.jpg',
      'library/same_2.jpg',
    ]);
    expect(await otherReservation.readAsString(), 'another operation');
    expect(await source.readAsBytes(), [1, 2, 3]);
    expect(
      await File(p.join(documents.path, result.dataOrNull!)).readAsBytes(),
      [1, 2, 3],
    );
    expect(
      await File(p.join(documents.path, planned.last.partialPath)).exists(),
      isFalse,
    );
    expect(
      await File(p.join(documents.path, planned.last.reservationPath)).exists(),
      isFalse,
    );
    expect(FileService.isImportActive('exact-operation'), isFalse);
  });

  test('journal記録失敗は一時物作成より先に止まり元ファイルを保つ', () async {
    final source = File(p.join(documents.path, 'source.jpg'));
    await source.writeAsString('original');
    final result = await service.importFile(
      source,
      importOperationId: 'journal-failure',
      onDestinationPrepared: (_) async =>
          throw StateError('journal unavailable'),
    );
    expect(result.isFailure, isTrue);
    expect(
      await Directory(p.join(documents.path, 'library')).list().toList(),
      isEmpty,
    );
    expect(await source.readAsString(), 'original');
    expect(FileService.isImportActive('journal-failure'), isFalse);
  });
}
