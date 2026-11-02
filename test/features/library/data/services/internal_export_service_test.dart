import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/services/internal_export_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockExternalStorageService extends Mock
    implements ExternalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(File('fallback'));
  });

  late Directory tempDirectory;
  late _MockMediaRepository repository;
  late _MockExternalStorageService storage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'internal_export_service_test_',
    );
    repository = _MockMediaRepository();
    storage = _MockExternalStorageService();
    when(
      () => repository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    PrivateStorageService.resetForTesting();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDirectory.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    PrivateStorageService.resetForTesting();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('iOSの一時エクスポート先は永続化せず、処理後に必ず解放する', () async {
    final target = Uri.file('${tempDirectory.path}/export');
    when(
      () => storage.pickFolder(persistAccess: false),
    ).thenAnswer((_) async => target);
    when(() => storage.releaseFolder(target)).thenAnswer((_) async {});

    final service = InternalExportService(repository, storage, isIOS: true);
    final result = await service.exportMediaItems(const [], null);

    expect(result.isSuccess, isTrue);
    verify(() => storage.pickFolder(persistAccess: false)).called(1);
    verify(() => storage.releaseFolder(target)).called(1);
  });

  test('呼び出し元が渡した永続参照先は自動解放しない', () async {
    final target = Uri.file('${tempDirectory.path}/persistent');
    final service = InternalExportService(repository, storage, isIOS: true);

    final result = await service.exportMediaItems(const [], target);

    expect(result.isSuccess, isTrue);
    verifyNever(
      () => storage.pickFolder(persistAccess: any(named: 'persistAccess')),
    );
    verifyNever(() => storage.releaseFolder(target));
  });

  test('エクスポートはファイルを一括バイト化せずストリームコピーに渡す', () async {
    final source = File('${tempDirectory.path}/library/large.bin');
    await source.parent.create(recursive: true);
    await source.writeAsBytes(List<int>.filled(1024 * 1024, 7));
    final targetFolder = Uri.file('${tempDirectory.path}/export');
    final targetFile = Uri.file('${tempDirectory.path}/export/large.bin');
    when(
      () => storage.createFile(
        targetFolder,
        'large.bin',
        'application/octet-stream',
      ),
    ).thenAnswer((_) async => targetFile);
    when(
      () => storage.copyFileToUri(any(), targetFile),
    ).thenAnswer((_) async => true);
    final item = MediaItem()
      ..path = 'library/large.bin'
      ..type = MediaType.file;

    final result = await InternalExportService(
      repository,
      storage,
      isIOS: false,
    ).exportMediaItems([item], targetFolder);

    expect(result.isSuccess, isTrue);
    final captured =
        verify(
              () => storage.copyFileToUri(captureAny(), targetFile),
            ).captured.single
            as File;
    expect(captured.path, source.path);
  });

  test('ダウンロードは専用フォルダに保存し、メタデータJSONを同梱する', () async {
    final source = File('${tempDirectory.path}/library/photo.jpg');
    await source.parent.create(recursive: true);
    await source.writeAsBytes(<int>[1, 2, 3]);
    final savedMetadata = <String, dynamic>{};
    final savedSubdirectories = <String>[];
    when(
      () => storage.saveToDownloadFolder(
        any(),
        any(),
        subdirectory: any(named: 'subdirectory'),
      ),
    ).thenAnswer((invocation) async {
      final sourcePath = invocation.positionalArguments[0] as String;
      final fileName = invocation.positionalArguments[1] as String;
      final subdirectory = invocation.namedArguments[#subdirectory] as String?;
      savedSubdirectories.add(subdirectory!);
      if (fileName == 'tagshelf-metadata.json') {
        savedMetadata.addAll(
          jsonDecode(await File(sourcePath).readAsString())
              as Map<String, dynamic>,
        );
      }
      return true;
    });
    final item = MediaItem()
      ..uid = 'item-1'
      ..path = 'library/photo.jpg'
      ..type = MediaType.file;
    final collection = MediaCollection()
      ..uid = 'collection-1'
      ..path = item.path
      ..title = '旅行の写真';
    when(
      () => repository.getCollectionByPath(item.path),
    ).thenAnswer((_) async => Result.success(collection));

    final result = await InternalExportService(
      repository,
      storage,
      isIOS: false,
    ).exportMediaItems([item], null);

    expect(result.isSuccess, isTrue);
    expect(savedSubdirectories, hasLength(2));
    expect(savedSubdirectories[0], startsWith('CharmShelf_'));
    expect(savedSubdirectories[1], savedSubdirectories[0]);
    expect(savedMetadata['schemaVersion'], 1);
    expect(savedMetadata['items'], hasLength(1));
    expect(savedMetadata['items'][0]['relativePath'], 'photo.jpg');
    expect(savedMetadata['items'][0]['collection']['title'], '旅行の写真');
  });

  test('元ファイル欠落をエクスポート成功や進捗完了として扱わない', () async {
    final targetFolder = Uri.file('${tempDirectory.path}/export');
    final item = MediaItem()
      ..path = 'library/missing.jpg'
      ..type = MediaType.file;
    var progressCalls = 0;

    final result =
        await InternalExportService(
          repository,
          storage,
          isIOS: false,
        ).exportMediaItems(
          [item],
          targetFolder,
          onProgress: (_, _, _) => progressCalls++,
        );

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull?.message, contains('見つかりません'));
    expect(progressCalls, 0);
    verifyNever(
      () => storage.createFile(targetFolder, 'missing.jpg', 'image/jpeg'),
    );
  });
}
