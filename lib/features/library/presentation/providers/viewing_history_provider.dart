import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/isar_provider.dart';
import '../../../library/data/repositories/viewing_history_repository.dart';
import '../../../library/domain/models/media_item.dart';
import '../../../library/domain/models/recently_opened_file.dart';
import '../../../library/presentation/providers/secret_mode_provider.dart';
import '../../../settings/presentation/providers/app_mode_provider.dart';

final viewingHistoryRepositoryProvider =
    FutureProvider<ViewingHistoryRepository>((ref) async {
      return ViewingHistoryRepository(await ref.watch(isarProvider.future));
    });

final recentlyOpenedFilesProvider =
    StreamProvider.autoDispose<List<RecentlyOpenedFile>>((ref) async* {
      final mode = ref.watch(appModeProvider);
      final includeHidden = ref.watch(secretModeProvider).value ?? false;
      final repository = await ref.watch(
        viewingHistoryRepositoryProvider.future,
      );
      yield* repository.watchRecent(
        sourceType: mode == AppMode.internal
            ? MediaSourceType.localCopy
            : MediaSourceType.externalReference,
        includeHidden: includeHidden,
        limit: 5,
      );
    });

final recentFilesHistoryProvider =
    StreamProvider.autoDispose<List<RecentlyOpenedFile>>((ref) async* {
      final mode = ref.watch(appModeProvider);
      final hidden = ref.watch(secretModeProvider).value ?? false;
      final repository = await ref.watch(
        viewingHistoryRepositoryProvider.future,
      );
      yield* repository.watchRecent(
        sourceType: mode == AppMode.internal
            ? MediaSourceType.localCopy
            : MediaSourceType.externalReference,
        includeHidden: hidden,
        limit: 20,
      );
    });
