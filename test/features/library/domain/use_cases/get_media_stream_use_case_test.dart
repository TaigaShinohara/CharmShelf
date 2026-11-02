import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/get_media_stream_use_case.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late MockMediaRepository mockMediaRepository;
  late GetMediaStreamUseCase useCase;

  setUp(() {
    mockMediaRepository = MockMediaRepository();
    useCase = GetMediaStreamUseCase(Future.value(mockMediaRepository));
    registerFallbackValue(const MediaFilter());
  });

  test('正常系: Repositoryから得られたストリームがそのまま返されること', () async {
    // Setup
    final items = [MediaItem()..id = 1];
    when(
      () => mockMediaRepository.watchAll(filter: any(named: 'filter')),
    ).thenAnswer((_) => Stream.value(items));

    // Execute
    final stream = useCase.invoke(const MediaFilter());

    // Verify
    await expectLater(stream, emits(items));
    verify(
      () => mockMediaRepository.watchAll(filter: any(named: 'filter')),
    ).called(1);
  });
}
