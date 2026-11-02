import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/services/local_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageManager manager;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tagshelf_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );

    manager = LocalStorageManager();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalStorageManager Tests', () {
    test('ルートディレクトリとメタデータディレクトリを取得できる', () async {
      final rootDir = await manager.getRootDirectory();
      expect(rootDir, isNotNull);
      expect(await rootDir.exists(), isTrue);

      final metaDir = await manager.getMetadataDirectory();
      expect(metaDir, isNotNull);
      expect(
        p.basename(metaDir.path),
        equals(LocalStorageManager.sidecarMetaDirName),
      );
      expect(await metaDir.exists(), isTrue);

      final metaFile = await manager.getMetadataFile();
      expect(
        p.basename(metaFile.path),
        equals(LocalStorageManager.metadataFileName),
      );
    });

    test('相対パスと絶対パスの相互変換が正しく行える', () async {
      final rootDir = await manager.getRootDirectory();
      const sampleRelativePath = 'Photos/vacation.jpg';
      final sampleAbsolutePath = p.join(rootDir.path, sampleRelativePath);

      final resolvedRelative = await manager.toRelativePath(sampleAbsolutePath);
      expect(resolvedRelative, equals(sampleRelativePath));

      final resolvedAbsolute = await manager.toAbsolutePath(sampleRelativePath);
      expect(resolvedAbsolute, equals(sampleAbsolutePath));
    });

    test('Androidの権限変更後はキャッシュを更新して公開復元を再選択できる', () async {
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final androidManager = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );

      final deniedRoot = await androidManager.getRootDirectory(
        allowPublic: false,
      );
      expect(deniedRoot.path, privateRoot.path);

      final stillCached = await androidManager.getRootDirectory();
      expect(stillCached.path, privateRoot.path);

      final grantedRoot = await androidManager.getRootDirectory(
        forceRefresh: true,
      );
      expect(grantedRoot.path, publicRoot.path);
      expect(await androidManager.isExternalPublicDirectory(), isTrue);
    });

    test('Androidのメタデータは常に私有領域で、旧公開パスは移行読み込み専用', () async {
      final privateRoot = Directory(p.join(tempDir.path, 'private'));
      final publicRoot = Directory(p.join(tempDir.path, 'public'));
      final androidManager = LocalStorageManager(
        isAndroid: true,
        privateRootDirectory: privateRoot,
        androidPublicRootDirectory: publicRoot,
      );
      await androidManager.getRootDirectory();

      final current = await androidManager.getMetadataFile();
      final legacy = await androidManager.getLegacyMetadataFile();

      expect(p.isWithin(privateRoot.path, current.path), isTrue);
      expect(legacy, isNotNull);
      expect(p.isWithin(publicRoot.path, legacy!.path), isTrue);
      expect(
        await Directory(p.join(publicRoot.path, '.tagshelf')).exists(),
        isFalse,
      );
    });
  });
}
