import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_progress.freezed.dart';

@freezed
abstract class SyncProgress with _$SyncProgress {
  const factory SyncProgress({
    @Default(SyncStatus.idle) SyncStatus status,
    @Default(0) int totalItems,
    @Default(0) int processedItems,
    @Default(false) bool isCancelled,
    String? currentFileName,
    String? errorMessage,
  }) = _SyncProgress;

  const SyncProgress._();

  double get progress => totalItems > 0 ? processedItems / totalItems : 0.0;
}

enum SyncStatus { idle, scanning, processing, completed, error, cancelling }
