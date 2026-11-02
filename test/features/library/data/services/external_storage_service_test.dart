import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../helpers/test_helpers.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;
  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selectUniqueDestinationPath keeps an unused requested name', () async {
    final result = await selectUniqueDestinationPath(
      '/downloads/report.pdf',
      (_) async => false,
    );

    expect(result, '/downloads/report.pdf');
  });

  test(
    'selectUniqueDestinationPath appends a suffix without losing extension',
    () async {
      final existing = {'/downloads/report.pdf', '/downloads/report (1).pdf'};

      final result = await selectUniqueDestinationPath(
        '/downloads/report.pdf',
        (path) async => existing.contains(path),
      );

      expect(result, '/downloads/report (2).pdf');
    },
  );

  test(
    'selectUniqueDestinationPath supports files without an extension',
    () async {
      final result = await selectUniqueDestinationPath(
        '/downloads/README',
        (path) async => path == '/downloads/README',
      );

      expect(result, '/downloads/README (1)');
    },
  );

  group('SAF復元元の読み取り', () {
    const events = EventChannel(
      'io.alexrintt.plugins/sharedstorage/event/documentfile',
    );
    const native = MethodChannel('com.tsmusic.privateshelf/saf');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory temporary;
    late PathProviderPlatform originalPathProvider;
    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('saf_snapshot_test_');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = FakePathProviderPlatform(temporary.path);
      setupMockSharedPreferences();
    });
    tearDown(() async {
      messenger.setMockStreamHandler(events, null);
      messenger.setMockMethodCallHandler(native, null);
      PathProviderPlatform.instance = originalPathProvider;
      await temporary.delete(recursive: true);
    });
    for (final scenario in [
      'success',
      'short-copy',
      'scan-error',
      'unsafe-name',
      'over-count',
      'empty',
    ]) {
      test('復元スナップショット: $scenario', () async {
        final copiedUris = <String>[];
        // 各SAFフォルダ走査で新しいEventChannelの購読を再現する。
        void installStreamHandler() {
          messenger.setMockStreamHandler(
            events,
            MockStreamHandler.inline(
              onListen: (arguments, sink) {
                final uri = (arguments as Map)['uri'] as String;
                if (scenario == 'scan-error') {
                  sink.error(code: 'denied', message: 'permission lost');
                } else if (scenario != 'empty') {
                  if (uri.endsWith('/metadata')) {
                    sink.success({
                      'uri': 'content://test/backup',
                      'name': 'metadata.json.bak',
                      'type': 'application/json',
                      'size': 3,
                    });
                    if (scenario == 'over-count') {
                      sink.success({
                        'uri': 'content://test/photo-2',
                        'name': 'photo-2.jpg',
                        'type': 'image/jpeg',
                        'size': 3,
                      });
                    }
                  } else {
                    sink.success({
                      'uri': 'content://test/photo',
                      'name': scenario == 'unsafe-name'
                          ? '../photo.jpg'
                          : 'photo.jpg',
                      'type': 'image/jpeg',
                      'size': 3,
                    });
                    sink.success({
                      'uri': 'content://test/metadata',
                      'name': '.tagshelf',
                      'type': 'vnd.android.document/directory',
                    });
                  }
                }
                sink.endOfStream();
                installStreamHandler();
              },
            ),
          );
        }

        installStreamHandler();
        messenger.setMockMethodCallHandler(native, (call) async {
          expect(call.method, 'copyUriToFile');
          final arguments = call.arguments as Map;
          copiedUris.add(arguments['uri'] as String);
          await File(
            arguments['destPath'] as String,
          ).writeAsBytes(scenario == 'short-copy' ? [1] : [1, 2, 3]);
          return true;
        });
        final service = ExternalStorageService(
          await SharedPreferences.getInstance(),
          maxImportFileCount: scenario == 'over-count' ? 1 : 100000,
        );
        final result = service.stageRecoveryFolder(
          Uri.parse('content://test/root'),
        );
        if (scenario == 'success') {
          final staged = await result;
          expect(
            await File(
              p.join(staged.path, '.tagshelf/metadata.json.bak'),
            ).readAsBytes(),
            [1, 2, 3],
          );
          expect(copiedUris, ['content://test/photo', 'content://test/backup']);
        } else {
          await expectLater(
            result,
            scenario == 'scan-error'
                ? throwsA(isA<PlatformException>())
                : throwsA(isA<FileSystemException>()),
          );
          expect(await temporary.list().toList(), isEmpty);
        }
      });
    }
  });

  group('ExternalStorageService 一時ファイルクリーンアップテスト', () {
    late Directory fakeTempDir;
    late Directory viewDir;

    setUp(() async {
      fakeTempDir = await Directory.systemTemp.createTemp('ext_storage_test');
      viewDir = Directory(p.join(fakeTempDir.path, 'external_view'));
      await viewDir.create(recursive: true);
      PathProviderPlatform.instance = FakePathProviderPlatform(
        fakeTempDir.path,
      );
    });

    tearDown(() async {
      if (await fakeTempDir.exists()) {
        await fakeTempDir.delete(recursive: true);
      }
    });

    test('cleanupTemp は external_view 内の全ファイルを削除する', () async {
      setupMockSharedPreferences();
      final prefs = await SharedPreferences.getInstance();
      final file1 = File(p.join(viewDir.path, 'file1.tmp'));
      await file1.writeAsString('test');
      final service = ExternalStorageService(prefs);

      expect(await file1.exists(), isTrue);
      await service.cleanupTemp();
      expect(await viewDir.exists(), isFalse);
    });

    test('cleanupOldTempFiles は期限切れファイルのみを削除する', () async {
      setupMockSharedPreferences();
      final prefs = await SharedPreferences.getInstance();
      final oldFile = File(p.join(viewDir.path, 'old.tmp'));
      await oldFile.writeAsString('old');
      // 最終更新日を2日前に設定
      await oldFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final newFile = File(p.join(viewDir.path, 'new.tmp'));
      await newFile.writeAsString('new');

      final service = ExternalStorageService(prefs);
      await service.cleanupOldTempFiles(maxAge: const Duration(hours: 24));

      expect(await oldFile.exists(), isFalse);
      expect(await newFile.exists(), isTrue);
    });

    test('cleanupOldTempFiles は削除対象ファイルが既に存在しない場合でも安全に処理を完了する', () async {
      setupMockSharedPreferences();
      final prefs = await SharedPreferences.getInstance();
      final oldFile = File(p.join(viewDir.path, 'old2.tmp'));
      await oldFile.writeAsString('old2');
      await oldFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final service = ExternalStorageService(prefs);
      // 例外がスローされずに正常完了することを確認
      await expectLater(
        service.cleanupOldTempFiles(maxAge: const Duration(hours: 24)),
        completes,
      );
      expect(await oldFile.exists(), isFalse);
    });
  });

  group('原子的な外部ファイルコピー', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atomic_external_copy_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('途中コピーが失敗した場合は完成ファイルもpartファイルも残さない', () async {
      final destination = File(p.join(tempDir.path, 'snapshot.bin'));

      final copied = await writeAtomicExternalSnapshot(
        destination: destination,
        writePartial: (partialFile) async {
          await partialFile.writeAsBytes([1, 2, 3], flush: true);
          return false;
        },
      );

      expect(copied, isFalse);
      expect(await destination.exists(), isFalse);
      expect(await File('${destination.path}.part').exists(), isFalse);
    });

    test('コピー完了時だけpartファイルを完成名へ確定する', () async {
      final destination = File(p.join(tempDir.path, 'snapshot.bin'));

      final copied = await writeAtomicExternalSnapshot(
        destination: destination,
        writePartial: (partialFile) async {
          await partialFile.writeAsBytes([4, 5, 6], flush: true);
          return true;
        },
      );

      expect(copied, isTrue);
      expect(await destination.readAsBytes(), [4, 5, 6]);
      expect(await File('${destination.path}.part').exists(), isFalse);
    });

    test('空ファイルも正しい完成コピーとして扱う', () async {
      final destination = File(p.join(tempDir.path, 'empty.bin'));

      final copied = await writeAtomicExternalSnapshot(
        destination: destination,
        writePartial: (partialFile) async {
          await partialFile.writeAsBytes(const [], flush: true);
          return true;
        },
      );

      expect(copied, isTrue);
      expect(await destination.length(), 0);
    });

    test('コピー処理が例外終了してもpartファイルを残さない', () async {
      final destination = File(p.join(tempDir.path, 'exception.bin'));

      await expectLater(
        writeAtomicExternalSnapshot(
          destination: destination,
          writePartial: (partialFile) async {
            await partialFile.writeAsBytes([7, 8, 9], flush: true);
            throw StateError('simulated copy failure');
          },
        ),
        throwsStateError,
      );

      expect(await destination.exists(), isFalse);
      expect(await File('${destination.path}.part').exists(), isFalse);
    });

    test('大きなファイルを外部file URIへストリームコピーできる', () async {
      setupMockSharedPreferences();
      final prefs = await SharedPreferences.getInstance();
      final service = ExternalStorageService(prefs);
      final source = File(p.join(tempDir.path, 'source.bin'));
      final target = File(p.join(tempDir.path, 'export', 'target.bin'));
      final payload = List<int>.generate(
        8 * 1024 * 1024,
        (index) => index % 251,
        growable: false,
      );
      await source.writeAsBytes(payload, flush: true);

      final copied = await service.copyFileToUri(source, target.uri);

      expect(copied, isTrue);
      expect(await target.length(), await source.length());
      expect(await target.openRead(0, 4096).first, payload.sublist(0, 4096));
    });
  });
}
