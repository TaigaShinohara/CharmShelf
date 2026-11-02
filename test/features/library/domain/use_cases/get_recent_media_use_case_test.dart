import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/get_recent_media_use_case.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late MockMediaRepository mockMediaRepository;
  late GetRecentMediaUseCase useCase;

  setUp(() {
    mockMediaRepository = MockMediaRepository();
    useCase = GetRecentMediaUseCase(mockMediaRepository);
  });

  group('GetRecentMediaUseCase.invoke', () {
    test('正常系: デフォルトのlimit=10で最近閲覧したメディアを取得できること', () async {
      // Setup
      final items = List.generate(10, (i) => MediaItem()..id = i + 1);
      when(
        () => mockMediaRepository.getRecentMedia(
          limit: 10,
          sourceType: null,
          isHidden: false,
        ),
      ).thenAnswer((_) async => Result.success(items));

      // Execute
      final result = await useCase.invoke();

      // Verify
      expect(result.isSuccess, true);
      expect(result.dataOrNull!.length, 10);

      verify(
        () => mockMediaRepository.getRecentMedia(
          limit: 10,
          sourceType: null,
          isHidden: false,
        ),
      ).called(1);
      verifyNever(() => mockMediaRepository.getAll());
    });

    test('正常系: カスタムlimitで取得できること', () async {
      // Setup
      final items = List.generate(5, (i) => MediaItem()..id = i + 1);
      when(
        () => mockMediaRepository.getRecentMedia(
          limit: 5,
          sourceType: null,
          isHidden: false,
        ),
      ).thenAnswer((_) async => Result.success(items));

      // Execute
      final result = await useCase.invoke(limit: 5);

      // Verify
      expect(result.isSuccess, true);
      expect(result.dataOrNull!.length, 5);
    });

    test('異常系: Repository がエラーを返した場合、Failureを返すこと', () async {
      // Setup
      final error = AppError.database('DB error');
      when(
        () => mockMediaRepository.getRecentMedia(
          limit: 10,
          sourceType: null,
          isHidden: false,
        ),
      ).thenAnswer((_) async => Result.failure(error));

      // Execute
      final result = await useCase.invoke();

      // Verify
      expect(result.isFailure, true);
      expect(result.errorOrNull, error);
    });

    test('シークレットモードでは非表示条件をリポジトリへ渡さない', () async {
      when(
        () => mockMediaRepository.getRecentMedia(
          limit: 10,
          sourceType: MediaSourceType.localCopy,
          isHidden: null,
        ),
      ).thenAnswer((_) async => Result.success([]));

      await useCase.invoke(
        sourceType: MediaSourceType.localCopy,
        includeHidden: true,
      );

      verify(
        () => mockMediaRepository.getRecentMedia(
          limit: 10,
          sourceType: MediaSourceType.localCopy,
          isHidden: null,
        ),
      ).called(1);
    });
  });
}
