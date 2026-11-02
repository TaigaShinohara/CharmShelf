// Application layer: coordinates domain contracts with persistence services.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/data/services/internal_export_service.dart';

part 'export_media_use_case.g.dart';

class ExportMediaUseCase {
  final InternalExportService _exportService;

  ExportMediaUseCase(this._exportService);

  /// 複数のメディアアイテムまたはフォルダを外部にエクスポートまたはダウンロードする
  Future<Result<void, AppError>> invoke(
    List<MediaItem> items, {
    Uri? targetFolderUri,
    void Function(int processed, int total, String? fileName)? onProgress,
  }) async {
    return _exportService.exportMediaItems(
      items,
      targetFolderUri,
      onProgress: onProgress,
    );
  }
}

@riverpod
Future<ExportMediaUseCase> exportMediaUseCase(Ref ref) async {
  final exportService = await ref.watch(internalExportServiceProvider.future);
  return ExportMediaUseCase(exportService);
}
