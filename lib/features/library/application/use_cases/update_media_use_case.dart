// Application layer: coordinates domain contracts with repository providers.
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_media_use_case.g.dart';

@riverpod
UpdateMediaUseCase updateMediaUseCase(Ref ref) {
  return UpdateMediaUseCase(ref);
}

class UpdateMediaUseCase {
  final Ref _ref;

  UpdateMediaUseCase(this._ref);

  Future<Result<void, AppError>> invoke(MediaItem item) async {
    final repository = await _ref.read(mediaRepositoryProvider.future);
    return repository.save(item);
  }
}
