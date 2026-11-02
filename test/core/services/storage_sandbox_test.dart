import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/services/storage_sandbox.dart';

void main() {
  group('StorageSandbox.resolveRelative', () {
    const root = '/app/documents';
    const roots = {'library', '.thumbnails'};

    test('許可された相対パスを解決する', () {
      expect(
        StorageSandbox.resolveRelative(
          root,
          'library/books/本.pdf',
          allowedTopLevelDirectories: roots,
        ),
        p.normalize('/app/documents/library/books/本.pdf'),
      );
    });

    for (final invalid in [
      '',
      '/tmp/file',
      '../Library/file',
      'library/../../../tmp/file',
      'library_evil/file',
      'content://provider/item',
      'library/bad\u0000name',
      r'library\windows\path',
      'other/file',
    ]) {
      test('不正パスを拒否する: $invalid', () {
        expect(
          () => StorageSandbox.resolveRelative(
            root,
            invalid,
            allowedTopLevelDirectories: roots,
          ),
          throwsA(isA<FileSystemException>()),
        );
      });
    }

    test('日本語・空白・Unicodeファイル名を許可する', () {
      expect(
        StorageSandbox.resolveRelative(
          root,
          'library/カタログ ①/表紙📚.jpg',
          allowedTopLevelDirectories: roots,
        ),
        p.normalize('/app/documents/library/カタログ ①/表紙📚.jpg'),
      );
    });
  });

  test('既存の親シンボリックリンクを拒否する', () async {
    final sandbox = await Directory.systemTemp.createTemp('sandbox_test_');
    final outside = await Directory.systemTemp.createTemp('outside_test_');
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
      if (await outside.exists()) await outside.delete(recursive: true);
    });
    await Directory(p.join(sandbox.path, 'library')).create();
    await Link(p.join(sandbox.path, 'library', 'escape')).create(outside.path);
    final resolved = StorageSandbox.resolveRelative(
      sandbox.path,
      'library/escape/file.txt',
      allowedTopLevelDirectories: const {'library'},
    );

    expect(
      () => StorageSandbox.rejectSymbolicLinkAncestors(sandbox.path, resolved),
      throwsA(isA<FileSystemException>()),
    );
  });
}
