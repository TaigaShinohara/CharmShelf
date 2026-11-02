import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/device_files/data/device_file_repository.dart';
import 'package:private_shelf/features/device_files/domain/device_file.dart';

DeviceFile item(String path, {String identity = 'inode1'}) => DeviceFile(
  uri: Uri.file(path),
  identity: identity,
  name: path.split('/').last,
  directory: false,
  size: 3,
);
void main() {
  late Directory temp;
  late DeviceFileRepository repository;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('device-index-test-');
    repository = DeviceFileRepository(File('${temp.path}/index.json'));
    await repository.load();
  });
  tearDown(() => temp.delete(recursive: true));
  test(
    'labels and index survive a new instance; originals are not written',
    () async {
      final original = File('${temp.path}/source.txt');
      await original.writeAsString('abc');
      final file = item(original.path);
      await repository.saveLabels(
        file,
        const DeviceFileLabels(tags: ['work'], catalog: 'A', favorite: true),
      );
      await repository.replaceIndex([file, item('/volume/second.txt')], 2);
      final restored = DeviceFileRepository(repository.file);
      await restored.load();
      expect(restored.entries.length, 2);
      expect(restored.labels(file).tags, ['work']);
      expect(restored.labels(file).catalog, 'A');
      expect(restored.labels(file).favorite, isTrue);
      expect(restored.skipped, 2);
      expect(restored.indexedAt, isNotNull);
      expect(await original.readAsString(), 'abc');
    },
  );
  test(
    'a replacement at the same path never inherits labels automatically',
    () async {
      final old = item('/volume/a.txt');
      final replacement = item('/volume/a.txt', identity: 'inode2');
      await repository.saveLabels(
        old,
        const DeviceFileLabels(tags: ['private']),
      );
      await repository.replaceIndex([replacement], 0);
      expect(repository.labels(replacement).tags, isEmpty);
      expect(repository.previousLabels(replacement)!.tags, ['private']);
      await repository.saveLabels(
        replacement,
        const DeviceFileLabels(tags: ['confirmed']),
      );
      expect(repository.previousLabels(replacement), isNull);
      expect(repository.labels(replacement).tags, ['confirmed']);
    },
  );
  test(
    'concurrent label writes are serialized without losing either update',
    () async {
      await Future.wait([
        repository.saveLabels(
          item('/a.txt'),
          const DeviceFileLabels(tags: ['a']),
        ),
        repository.saveLabels(
          item('/b.txt'),
          const DeviceFileLabels(tags: ['b']),
        ),
      ]);
      expect(repository.entries.length, 2);
    },
  );
  test('failed persistence retains the previous in-memory snapshot', () async {
    final entry = item('/a.txt');
    await repository.saveLabels(entry, const DeviceFileLabels(tags: ['old']));
    await Directory('${repository.file.path}.pending').create();
    await expectLater(
      repository.saveLabels(entry, const DeviceFileLabels(tags: ['new'])),
      throwsA(isA<FileSystemException>()),
    );
    expect(repository.labels(entry).tags, ['old']);
    final loaded = DeviceFileRepository(repository.file);
    await loaded.load();
    expect(loaded.labels(entry).tags, ['old']);
  });
  test(
    'corrupt storage fails visibly and is not overwritten by load',
    () async {
      await repository.file.writeAsString('{invalid');
      await expectLater(repository.load(), throwsFormatException);
      expect(await repository.file.readAsString(), '{invalid');
    },
  );
  test(
    'exclusions use directory boundaries; clearing only clears index',
    () async {
      await repository.replaceIndex([
        item('/volume/one/a.txt'),
        item('/volume/one-more/b.txt'),
      ], 0);
      await repository.setExcluded({'${Uri.file('/volume/one')}'});
      expect(repository.entries.single.uri, Uri.file('/volume/one-more/b.txt'));
      final excludedFile = item('/volume/one/a.txt');
      await repository.saveLabels(
        excludedFile,
        const DeviceFileLabels(tags: ['retained']),
      );
      final restored = DeviceFileRepository(repository.file);
      await restored.load();
      expect(restored.entries.single.uri, Uri.file('/volume/one-more/b.txt'));
      expect(restored.labels(excludedFile).tags, ['retained']);
      await repository.clear();
      expect(repository.entries, isEmpty);
      expect(repository.excluded, isEmpty);
    },
  );
}
