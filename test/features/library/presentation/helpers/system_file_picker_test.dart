import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:private_shelf/features/library/presentation/helpers/system_file_picker.dart';

saf.DocumentFile metadata(Uri uri, {bool folder = false, int? size = 42}) =>
    saf.DocumentFile(
      id: uri.path,
      parentUri: null,
      size: size,
      name: folder ? 'Photos' : 'Original image.jpg',
      type: folder ? 'vnd.android.document/directory' : 'image/jpeg',
      uri: uri,
      isDirectory: folder,
      isFile: !folder,
      isVirtual: false,
      lastModified: null,
    );

saf.UriPermission permission(Uri uri) => saf.UriPermission(
  isReadPermission: true,
  isWritePermission: false,
  persistedTime: 1,
  uri: uri,
  isTreeDocumentFile: uri.path.startsWith('/tree/'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = Uri.parse('content://provider/document/opaque-1');
  final second = Uri.parse('content://provider/document/opaque-2');

  test(
    'open uses a single read-only temporary grant and display metadata',
    () async {
      var permissionsQueried = false;
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async {
              expect(grantWritePermission, isFalse);
              expect(persistablePermission, isFalse);
              expect(multiple, isFalse);
              expect(mimeType, '*/*');
              return [first];
            },
        permissions: () async {
          permissionsQueried = true;
          return [];
        },
        metadata: (uri) async => metadata(uri, size: null),
        canRead: (_) async => true,
      );
      final document = await picker.openFile();
      expect(document!.uri, first);
      expect(document.name, 'Original image.jpg');
      expect(document.mimeType, 'image/jpeg');
      expect(document.size, isNull);
      expect(document.ownsGrant, isFalse);
      expect(permissionsQueried, isFalse);
    },
  );

  test(
    'import keeps opaque URIs, deduplicates picks and owns only new grants',
    () async {
      var queries = 0;
      final released = <Uri>[];
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async {
              expect(grantWritePermission, isFalse);
              expect(persistablePermission, isTrue);
              expect(multiple, isTrue);
              return [first, second, first];
            },
        permissions: () async => queries++ == 0
            ? [permission(first)]
            : [permission(first), permission(second)],
        metadata: (uri) async => metadata(uri),
        canRead: (_) async => true,
        release: (uri) async => released.add(uri),
      );
      final documents = (await picker.pickFiles())!;
      expect(documents.map((document) => document.uri), [first, second]);
      expect(documents.map((document) => document.ownsGrant), [false, true]);
      await picker.releaseDocuments(documents);
      expect(released, [second]);
    },
  );

  test('cancel returns null while native picker failure is thrown', () async {
    final picker = SystemFilePicker(
      documents:
          ({
            initialUri,
            required grantWritePermission,
            required persistablePermission,
            required mimeType,
            required multiple,
          }) async => null,
      permissions: () async => [],
    );
    expect(await picker.pickFiles(), isNull);
    final failed = SystemFilePicker(
      documents:
          ({
            initialUri,
            required grantWritePermission,
            required persistablePermission,
            required mimeType,
            required multiple,
          }) async => throw StateError('picker unavailable'),
      permissions: () async => [],
    );
    await expectLater(failed.pickFiles(), throwsStateError);
  });

  test(
    'metadata failure releases every new selection grant, preserves existing access',
    () async {
      var queries = 0;
      final released = <Uri>[];
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async => [first, second],
        permissions: () async => queries++ == 0
            ? [permission(first)]
            : [permission(first), permission(second)],
        metadata: (_) async => null,
        canRead: (_) async => true,
        release: (uri) async => released.add(uri),
      );
      await expectLater(
        picker.pickFiles(),
        throwsA(isA<SystemFilePickerException>()),
      );
      expect(released, [second]);
    },
  );

  test(
    'folder requests a read-only persistent tree and cleans unreadable metadata',
    () async {
      final tree = Uri.parse('content://provider/tree/photos');
      var queries = 0;
      final released = <Uri>[];
      final picker = SystemFilePicker(
        folder:
            ({
              required grantWritePermission,
              required persistablePermission,
              initialUri,
            }) async {
              expect(grantWritePermission, isFalse);
              expect(persistablePermission, isTrue);
              return tree;
            },
        permissions: () async => queries++ == 0 ? [] : [permission(tree)],
        metadata: (uri) async => metadata(uri, folder: true),
        canRead: (_) async => true,
        release: (uri) async => released.add(uri),
      );
      final folder = (await picker.pickFolder())!;
      expect(folder.uri, tree);
      expect(folder.ownsGrant, isTrue);
      await picker.releaseFolder(folder);
      expect(released, [tree]);

      queries = 0;
      released.clear();
      final unreadable = SystemFilePicker(
        folder:
            ({
              required grantWritePermission,
              required persistablePermission,
              initialUri,
            }) async => tree,
        permissions: () async => queries++ == 0 ? [] : [permission(tree)],
        metadata: (_) async => null,
        release: (uri) async => released.add(uri),
      );
      await expectLater(
        unreadable.pickFolder(),
        throwsA(isA<SystemFilePickerException>()),
      );
      expect(released, [tree]);
    },
  );

  test('one shared picker session suppresses repeated taps', () async {
    final pending = Completer<List<Uri>?>();
    var opened = 0;
    final picker = SystemFilePicker(
      documents:
          ({
            initialUri,
            required grantWritePermission,
            required persistablePermission,
            required mimeType,
            required multiple,
          }) {
            opened++;
            return pending.future;
          },
      metadata: (uri) async => metadata(uri),
      canRead: (_) async => true,
    );
    final opening = picker.openFile();
    await Future<void>.delayed(Duration.zero);
    expect(await picker.openFile(), isNull);
    expect(opened, 1);
    pending.complete([first]);
    expect((await opening)!.uri, first);
  });

  test('a late cancelled result releases only newly acquired access', () async {
    final native = Completer<List<Uri>?>();
    var queries = 0;
    final released = <Uri>[];
    Future<T?> cancelRunner<T>({required Future<T?> Function() pick}) async {
      unawaited(pick().then<void>((_) {}));
      return null;
    }

    final picker = SystemFilePicker(
      runPicker: cancelRunner,
      documents:
          ({
            initialUri,
            required grantWritePermission,
            required persistablePermission,
            required mimeType,
            required multiple,
          }) => native.future,
      permissions: () async => queries++ == 0
          ? [permission(first)]
          : [permission(first), permission(second)],
      metadata: (uri) async => metadata(uri),
      canRead: (_) async => true,
      release: (uri) async => released.add(uri),
    );
    expect(await picker.pickFiles(), isNull);
    native.complete([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(released, [second]);
  });

  test(
    'native partial-persistence failure never releases a previous URI',
    () async {
      final released = <Uri>[];
      final failure = PlatformException(
        code: 'persist',
        details: {
          'unreleasedUriGrants': [
            {'uri': '$first', 'flags': 1},
            {'uri': '$second', 'flags': 1},
          ],
        },
      );
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async => throw failure,
        permissions: () async => [permission(first)],
        release: (uri) async => released.add(uri),
      );
      await expectLater(picker.pickFiles(), throwsA(same(failure)));
      expect(released, [second]);
    },
  );

  test(
    'failed cleanup is journaled without replacing the metadata error',
    () async {
      final failure = StateError('metadata unavailable');
      var queries = 0;
      final remembered = <Uri>{};
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async => [first, second],
        permissions: () async => queries++ == 0
            ? [permission(first)]
            : [permission(first), permission(second)],
        metadata: (_) async => throw failure,
        release: (_) async => throw PlatformException(code: 'cannot_release'),
        rememberUnreleasedGrants: (uris) async => remembered.addAll(uris),
      );
      await expectLater(picker.pickFiles(), throwsA(same(failure)));
      expect(remembered, {second});
    },
  );

  test(
    'runner failure after selection cleans new grants and preserves its error',
    () async {
      final failure = StateError('runner failed after picker completed');
      Future<T?> failAfterPick<T>({required Future<T?> Function() pick}) async {
        await pick();
        throw failure;
      }

      for (final cleanupFails in [false, true]) {
        var queries = 0;
        final released = <Uri>[];
        final remembered = <Uri>{};
        final picker = SystemFilePicker(
          runPicker: failAfterPick,
          documents:
              ({
                initialUri,
                required grantWritePermission,
                required persistablePermission,
                required mimeType,
                required multiple,
              }) async => [first, second],
          permissions: () async => queries++ == 0
              ? [permission(first)]
              : [permission(first), permission(second)],
          metadata: (uri) async => metadata(uri),
          canRead: (_) async => true,
          release: (uri) async {
            released.add(uri);
            if (cleanupFails) throw StateError('cleanup failed');
          },
          rememberUnreleasedGrants: (uris) async => remembered.addAll(uris),
        );
        await expectLater(picker.pickFiles(), throwsA(same(failure)));
        expect(released, [second]);
        expect(remembered, cleanupFails ? {second} : isEmpty);
      }
    },
  );

  test(
    'ownership discovery failure journals only selected URIs absent before picking',
    () async {
      final failure = PlatformException(code: 'permission_query_failed');
      var queries = 0;
      final remembered = <Uri>{};
      final picker = SystemFilePicker(
        documents:
            ({
              initialUri,
              required grantWritePermission,
              required persistablePermission,
              required mimeType,
              required multiple,
            }) async => [first, second],
        permissions: () async {
          if (queries++ == 0) return [permission(first)];
          throw failure;
        },
        rememberUnreleasedGrants: (uris) async => remembered.addAll(uris),
      );
      await expectLater(picker.pickFiles(), throwsA(same(failure)));
      expect(remembered, {second});
    },
  );
}
