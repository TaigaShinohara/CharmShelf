import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/media_repository_provider.dart';
import '../../domain/models/media_filter.dart';
import '../../domain/models/media_item.dart';

/// The route already owns its initial item. Complete its navigation topology
/// independently, without blocking the first image or changing source filters.
final catalogViewerItemsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, MediaFilter>((ref, filter) async {
      final repository = await ref.watch(mediaRepositoryProvider.future);
      final result = await repository.getAll(filter: filter);
      if (result.isFailure) throw result.errorOrNull!;
      return result.dataOrNull!;
    });
