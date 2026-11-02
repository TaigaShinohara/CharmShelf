import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/data/services/import_source_browser.dart';
import 'package:private_shelf/features/library/domain/models/import_source.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final source = ImportSource(
    id: 'source',
    name: 'Source',
    treeUri: Uri.parse('content://test/tree/root'),
  );
  Map<String, Object?> entry(String id, bool dir) => {
    'id': id,
    'uri': 'content://test/tree/root/document/$id',
    'name': id,
    'directory': dir,
    'size': dir ? null : 10,
  };
  late ImportSourceBrowser browser;
  setUp(() {
    browser = ImportSourceBrowser();
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(ImportSourceBrowser.channel, null),
  );

  test(
    'browsing lists only the current directory and retains unknown sizes',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(ImportSourceBrowser.channel, (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'root'
            ? entry('root', true)
            : [
                entry('Folder', true),
                {...entry('a.jpg', false), 'size': null},
              ];
      });
      final root = await browser.root(source.treeUri);
      final children = await browser.children(source, root);
      expect(calls, ['root', 'children']);
      expect(children[1].size, isNull);
      expect(children[0].path, 'Folder');
    },
  );
  test(
    'selected parent and child are scanned once, keeping the source grant in drafts',
    () async {
      final folders = <String>[];
      messenger.setMockMethodCallHandler(ImportSourceBrowser.channel, (
        call,
      ) async {
        folders.add((call.arguments as Map)['directoryUri'] as String);
        return [entry('photo.jpg', false)];
      });
      final parent = ImportSourceEntry.fromMap(entry('Folder', true));
      final child = ImportSourceEntry.fromMap(
        entry('photo.jpg', false),
        parent: 'Folder',
      );
      final tree = await browser.selection(source, [parent, child]);
      expect(folders, hasLength(1));
      expect(
        tree.children.single.children.single.relativePath,
        'Folder/photo.jpg',
      );
      final restored = FileTreeNode.fromMap(tree.toMap());
      expect(
        restored.children.single.children.single.sourceTreeUri,
        source.treeUri,
      );
    },
  );
  test(
    'provider error aborts selection instead of producing an empty successful folder',
    () async {
      messenger.setMockMethodCallHandler(
        ImportSourceBrowser.channel,
        (call) async => throw PlatformException(code: 'unavailable'),
      );
      await expectLater(
        browser.selection(source, [
          ImportSourceEntry.fromMap(entry('Folder', true)),
        ]),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test(
    'closing during a slow scan cancels it and cannot return a selection',
    () async {
      final response = Completer<List<Object?>>();
      var cancelled = false;
      messenger.setMockMethodCallHandler(ImportSourceBrowser.channel, (
        call,
      ) async {
        if (call.method == 'cancel') {
          cancelled = true;
          return null;
        }
        return response.future;
      });
      final pending = browser.selection(source, [
        ImportSourceEntry.fromMap(entry('Folder', true)),
      ]);
      final assertion = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await browser.cancel();
      response.complete([entry('photo.jpg', false)]);
      await assertion;
      expect(cancelled, isTrue);
    },
  );
  test('ambiguous sibling names fail before any import', () async {
    messenger.setMockMethodCallHandler(
      ImportSourceBrowser.channel,
      (call) async => [
        entry('photo.jpg', false),
        {...entry('photo.jpg', false), 'id': 'different'},
      ],
    );
    await expectLater(
      browser.children(source, ImportSourceEntry.fromMap(entry('root', true))),
      throwsStateError,
    );
  });
}
