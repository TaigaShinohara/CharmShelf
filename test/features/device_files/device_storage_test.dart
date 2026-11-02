import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/device_files/data/device_storage.dart';
import 'package:private_shelf/features/device_files/domain/device_file.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';

DeviceFile entry(String path, {bool dir = false}) => DeviceFile(
  uri: Uri.file(path),
  identity: 'id:$path',
  name: path.split('/').last,
  directory: dir,
  size: dir ? null : 3,
);

class FakeStorage extends DeviceStorage {
  final listings = <String, DeviceListing>{};
  final visited = <String>[];
  Future<void> Function()? delay;
  @override
  Future<void> validate(List<DeviceFile> entries) async {}
  @override
  Future<DeviceListing> children(Uri uri) async {
    visited.add('$uri');
    await delay?.call();
    final result = listings['$uri'];
    if (result == null) throw StateError('read failed');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceStorage.channel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceStorage.channel, null);
  });
  test(
    'scan crosses folders, skips exclusions and reports unreadable count',
    () async {
      final s = FakeStorage();
      final root = entry('/volume', dir: true);
      s.listings['${root.uri}'] = DeviceListing([
        entry('/volume/A', dir: true),
        entry('/volume/B', dir: true),
      ], skipped: 1);
      s.listings['${Uri.file('/volume/A')}'] = DeviceListing([
        entry('/volume/A/file.txt'),
      ]);
      final result = await s.scan(
        [root],
        excluded: {'${Uri.file('/volume/B')}'},
      );
      expect(result.entries.map((e) => e.name), ['A', 'file.txt']);
      expect(result.skipped, 1);
      expect(s.visited.length, 2);
    },
  );
  test(
    'an unreadable directory fails the snapshot instead of returning an incomplete success',
    () async {
      final s = FakeStorage();
      s.listings['${Uri.file('/v')}'] = DeviceListing([
        entry('/v/a', dir: true),
      ]);
      await expectLater(s.scan([entry('/v', dir: true)]), throwsStateError);
    },
  );
  test('cancelling a delayed scan ignores its eventual response', () async {
    final s = FakeStorage();
    final gate = Completer<void>();
    s.delay = () => gate.future;
    s.listings['${Uri.file('/v')}'] = DeviceListing([entry('/v/a.txt')]);
    final future = s.scan([entry('/v', dir: true)]);
    final expectation = expectLater(
      future,
      throwsA(isA<DeviceScanCancelled>()),
    );
    await s.cancel();
    gate.complete();
    await expectation;
  });
  test(
    'selection normalizes parent overlap and retains identity through drafts',
    () async {
      final s = FakeStorage();
      final folder = entry('/v/A', dir: true), file = entry('/v/A/a.txt');
      s.listings['${folder.uri}'] = DeviceListing([file]);
      final tree = await s.selection(entry('/v', dir: true), [folder, file]);
      expect(tree.children.length, 1);
      expect(s.visited, ['${folder.uri}']);
      final restored = FileTreeNode.fromMap(tree.toMap());
      expect(
        restored.children.single.children.single.sourceIdentity,
        file.identity,
      );
      expect(restored.children.single.children.single.relativePath, 'A/a.txt');
    },
  );
  test('selection refuses a partial folder listing', () async {
    final s = FakeStorage();
    final folder = entry('/v/A', dir: true);
    s.listings['${folder.uri}'] = const DeviceListing([], skipped: 1);
    await expectLater(
      s.selection(entry('/v', dir: true), [folder]),
      throwsStateError,
    );
  });
  test('method channel validates identities in bounded batches', () async {
    final sizes = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceStorage.channel, (call) async {
          expect(call.method, 'validate');
          sizes.add((call.arguments['entries'] as List).length);
          return true;
        });
    await DeviceStorage().validate(
      List.generate(401, (i) => entry('/v/$i.txt')),
    );
    expect(sizes, [200, 200, 1]);
  });
  test(
    'permission failure cannot be reported as successful validation',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceStorage.channel, (call) async {
            throw PlatformException(code: 'permission');
          });
      await expectLater(
        DeviceStorage().validate([entry('/v/a.txt')]),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
