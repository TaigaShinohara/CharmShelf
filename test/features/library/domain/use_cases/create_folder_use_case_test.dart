import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

class MockOperationJournal extends Mock implements OperationJournalService {}

class FakeOperationJournalEntry extends Fake implements OperationJournalEntry {}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockMediaRepository mockMediaRepository;
  late CreateFolderUseCase useCase;
  late MockPathProviderPlatform mockPathProvider;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(MediaItem());
    registerFallbackValue(FakeOperationJournalEntry());
  });

  setUp(() async {
    mockMediaRepository = MockMediaRepository();
    useCase = CreateFolderUseCase(Future.value(mockMediaRepository));
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
    tempDir = await Directory.systemTemp.createTemp('private_shelf_test_');
    when(
      () => mockPathProvider.getApplicationDocumentsPath(),
    ).thenAnswer((_) async => tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CreateFolderUseCase.invoke', () {
    test('正常系: フォルダ作成とDB保存が成功した場合、MediaItemを返すこと', () async {
      // Setup
      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke('テストフォルダ');

      // Verify
      expect(result.isSuccess, true);
      final item = result.dataOrNull!;
      expect(item.type, MediaType.folder);
      // フォルダ名にサニタイズが適用されていないことを確認（日本語はOK）
      expect(item.path, contains('テストフォルダ'));
      verify(() => mockMediaRepository.save(any<MediaItem>())).called(1);
    });

    test('正常系: parentPath指定時にサブディレクトリのパスが正しいこと', () async {
      // Setup
      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke('子フォルダ', parentPath: '親フォルダ');

      // Verify
      expect(result.isSuccess, true);
      final item = result.dataOrNull!;
      expect(item.parentPath, 'library/親フォルダ');
      // パスに親子構造が含まれること
      expect(item.path, contains('親フォルダ'));
      expect(item.path, contains('子フォルダ'));
    });

    test('正常系: 同名の物理フォルダが存在する場合、連番を付与すること', () async {
      // Setup
      final docsDir = await mockPathProvider.getApplicationDocumentsPath();
      final duplicateDir = Directory(p.join(docsDir!, 'library', '重複フォルダ'));
      await duplicateDir.create(recursive: true);

      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke('重複フォルダ');

      // Verify
      expect(result.isSuccess, true);
      final item = result.dataOrNull!;
      expect(item.path, contains('重複フォルダ (1)'));
    });

    test('異常系: DB保存に失敗した場合、Failureを返すこと', () async {
      final error = AppError.database('DB save failed');
      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.failure(error));

      // Execute
      final result = await useCase.invoke('テスト');

      // Verify
      expect(result.isFailure, true);
      expect(result.errorOrNull?.category, ErrorCategory.database);
      final created = Directory(p.join(tempDir.path, 'library', 'テスト'));
      expect(await created.exists(), isFalse);
    });

    test('異常系: 管理ライブラリ外へ逸脱する親パスを拒否する', () async {
      final result = await useCase.invoke('危険', parentPath: '../outside');

      expect(result.isFailure, isTrue);
      verifyNever(() => mockMediaRepository.save(any<MediaItem>()));
      expect(
        await Directory(p.join(tempDir.path, 'outside')).exists(),
        isFalse,
      );
    });

    test('異常系: 空白だけのフォルダ名を拒否する', () async {
      final result = await useCase.invoke('   ');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.category, ErrorCategory.validation);
      verifyNever(() => mockMediaRepository.save(any<MediaItem>()));
    });

    test('異常系: 不正な文字を含むフォルダ名を拒否する', () async {
      final invalidNames = [
        'test/folder',
        r'test\folder',
        'test:folder',
        'test*folder',
        'test?folder',
        '<test>',
        'test|folder',
      ];
      for (final invalidName in invalidNames) {
        final result = await useCase.invoke(invalidName);
        expect(result.isFailure, isTrue, reason: 'Failed for $invalidName');
        expect(result.errorOrNull?.category, ErrorCategory.validation);
      }
      verifyNever(() => mockMediaRepository.save(any<MediaItem>()));
    });

    test('正常系: 作成ジャーナルをplanned・staged・committedへ進める', () async {
      final journal = MockOperationJournal();
      final journaledUseCase = CreateFolderUseCase(
        Future.value(mockMediaRepository),
        FileService(),
        journal,
      );
      when(
        () => mockMediaRepository.save(any<MediaItem>()),
      ).thenAnswer((_) async => Result.success(null));
      when(() => journal.write(any())).thenAnswer((_) async {});
      when(() => journal.remove(any())).thenAnswer((_) async {});

      final result = await journaledUseCase.invoke('安全なフォルダ');

      expect(result.isSuccess, isTrue);
      final entries = verify(
        () => journal.write(captureAny()),
      ).captured.cast<OperationJournalEntry>().toList();
      expect(entries.map((entry) => entry.stage), [
        OperationStage.planned,
        OperationStage.staged,
        OperationStage.committed,
      ]);
      expect(entries.first.kind, OperationKind.createFolder);
      verify(() => journal.remove(entries.first.id)).called(1);
    });
  });
}
