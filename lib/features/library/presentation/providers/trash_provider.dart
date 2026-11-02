import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trash_provider.g.dart';

@riverpod
Future<List<MediaItem>> trashedMediaRoots(Ref ref) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  final result = await repository.getTrashedRoots();
  if (result.isFailure) throw result.errorOrNull!;
  return result.dataOrNull ?? [];
}
