import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';

part 'sync_progress_provider.g.dart';

/// ライブラリ（内部・外部）の同期・インポート状態を管理するプロバイダー。
@riverpod
class SyncProgressNotifier extends _$SyncProgressNotifier {
  @override
  SyncProgress build() => const SyncProgress();

  void updateProgress(SyncProgress progress) {
    // Preserve isCancelled and cancelling status
    final isCancelled = state.isCancelled;
    final status = state.status == SyncStatus.cancelling
        ? SyncStatus.cancelling
        : progress.status;

    state = progress.copyWith(isCancelled: isCancelled, status: status);
  }

  void setStatus(SyncStatus status, {String? errorMessage}) {
    state = state.copyWith(status: status, errorMessage: errorMessage);
  }

  void setTotalItems(int total) {
    state = state.copyWith(totalItems: total, processedItems: 0);
  }

  void incrementProcessed({String? fileName}) {
    state = state.copyWith(
      processedItems: state.processedItems + 1,
      currentFileName: fileName,
    );
  }

  void cancel() {
    state = state.copyWith(isCancelled: true, status: SyncStatus.cancelling);
  }

  void reset() {
    state = const SyncProgress();
  }
}
