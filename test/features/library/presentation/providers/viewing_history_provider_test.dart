import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/data/repositories/viewing_history_repository.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/recently_opened_file.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewing_history_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _History extends Mock implements ViewingHistoryRepository {}

final _mode = StateProvider((ref) => AppMode.internal);
final _hidden = StateProvider((ref) => false);

class _Secret extends SecretMode {
  @override
  bool build() => ref.watch(_hidden);
}

void main() {
  test(
    'recent history switches source and privacy scope without mixing entries',
    () async {
      final repository = _History();
      for (final source in MediaSourceType.values) {
        for (final hidden in [false, true]) {
          when(
            () => repository.watchRecent(
              sourceType: source,
              includeHidden: hidden,
              limit: 5,
            ),
          ).thenAnswer(
            (_) => Stream.value([
              RecentlyOpenedFile(
                item: MediaItem()..uid = '${source.name}-$hidden',
              ),
            ]),
          );
        }
      }
      final container = ProviderContainer(
        overrides: [
          viewingHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          appModeProvider.overrideWith((ref) => ref.watch(_mode)),
          secretModeProvider.overrideWith(_Secret.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(recentlyOpenedFilesProvider, (_, _) {});
      Future<String?> currentUid() async => (await container.read(
        recentlyOpenedFilesProvider.future,
      )).single.item.uid;
      expect(await currentUid(), 'localCopy-false');
      container.read(_mode.notifier).state = AppMode.external;
      expect(container.read(recentlyOpenedFilesProvider).isLoading, isTrue);
      expect(await currentUid(), 'externalReference-false');
      container.read(_hidden.notifier).state = true;
      expect(await currentUid(), 'externalReference-true');
      container.read(_hidden.notifier).state = false;
      expect(await currentUid(), 'externalReference-false');
      container.read(_mode.notifier).state = AppMode.internal;
      expect(await currentUid(), 'localCopy-false');
    },
  );
}
