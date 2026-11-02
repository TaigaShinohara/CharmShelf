import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/application/use_cases/empty_trash_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/permanently_delete_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/trash_provider.dart';

part 'trash_view_model.g.dart';

@immutable
class TrashState {
  const TrashState({
    this.items = const AsyncValue.loading(),
    this.busyItemIds = const {},
    this.isBusy = false,
  });

  final AsyncValue<List<MediaItem>> items;
  final Set<int> busyItemIds;
  final bool isBusy;

  TrashState copyWith({
    AsyncValue<List<MediaItem>>? items,
    Set<int>? busyItemIds,
    bool? isBusy,
  }) {
    return TrashState(
      items: items ?? this.items,
      busyItemIds: busyItemIds ?? this.busyItemIds,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

@riverpod
class TrashViewModel extends _$TrashViewModel {
  @override
  TrashState build() {
    final itemsAsync = ref.watch(trashedMediaRootsProvider);
    return TrashState(items: itemsAsync);
  }

  void refresh() {
    ref.invalidate(trashedMediaRootsProvider);
  }

  Future<Result<void, AppError>> restoreItem(
    MediaItem item, {
    String? newName,
    String? newParentPath,
  }) async {
    final busyIds = Set<int>.from(state.busyItemIds)..add(item.id);
    state = state.copyWith(busyItemIds: busyIds);

    try {
      final useCase = ref.read(restoreTrashedMediaUseCaseProvider);
      final result = await useCase.invoke(
        item,
        newName: newName,
        newParentPath: newParentPath,
      );

      if (result.isSuccess) {
        ref.invalidate(trashedMediaRootsProvider);
      }
      return result;
    } catch (e, st) {
      AppLogger.e(LogTag.provider, 'ゴミ箱アイテム復元処理で例外発生', e, st);
      return Result.failure(
        AppError.unknown('アイテムの復元に失敗しました', original: e, stackTrace: st),
      );
    } finally {
      final updatedBusy = Set<int>.from(state.busyItemIds)..remove(item.id);
      state = state.copyWith(busyItemIds: updatedBusy);
    }
  }

  Future<Result<void, AppError>> permanentlyDeleteItem(MediaItem item) async {
    final busyIds = Set<int>.from(state.busyItemIds)..add(item.id);
    state = state.copyWith(busyItemIds: busyIds);

    try {
      final useCase = ref.read(permanentlyDeleteTrashedMediaUseCaseProvider);
      final result = await useCase.invoke(item);

      if (result.isSuccess) {
        ref.invalidate(trashedMediaRootsProvider);
      }
      return result;
    } catch (e, st) {
      AppLogger.e(LogTag.provider, 'ゴミ箱アイテム完全削除処理で例外発生', e, st);
      return Result.failure(
        AppError.unknown('アイテムの完全削除に失敗しました', original: e, stackTrace: st),
      );
    } finally {
      final updatedBusy = Set<int>.from(state.busyItemIds)..remove(item.id);
      state = state.copyWith(busyItemIds: updatedBusy);
    }
  }

  Future<Result<int, AppError>> emptyTrash() async {
    state = state.copyWith(isBusy: true);

    try {
      final useCase = ref.read(emptyTrashUseCaseProvider);
      final result = await useCase.invoke();

      ref.invalidate(trashedMediaRootsProvider);
      return result;
    } catch (e, st) {
      AppLogger.e(LogTag.provider, 'ゴミ箱を空にする処理で例外発生', e, st);
      return Result.failure(
        AppError.unknown('ゴミ箱を空にする処理に失敗しました', original: e, stackTrace: st),
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }
}
