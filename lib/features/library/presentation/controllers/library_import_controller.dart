import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/presentation/helpers/import_picker_notification_helper.dart';
import 'package:private_shelf/features/library/presentation/models/import_catalog_options.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/internal_import_service_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

part 'library_import_controller.g.dart';

@riverpod
class LibraryImportController extends _$LibraryImportController {
  @override
  void build() {}

  /// ファイルをインポートする
  Future<void> importFiles({
    required Future<ImportCatalogOptions?> Function() askCatalogOptions,
  }) async {
    final result = await runImportPicker(
      pick: () => FilePicker.pickFiles(type: FileType.any),
    );

    if (result != null && result.isNotEmpty) {
      final files = result
          .map((f) => f.path)
          .whereType<String>()
          .map((p) => File(p))
          .toList();

      final catalogOptions = await askCatalogOptions();
      if (catalogOptions == null) return;
      final isCatalog = catalogOptions.isCatalog;

      final parentPath = ref
          .read(mediaFilterNotifierProvider(AppMode.internal))
          .parentPath;
      final importService = await ref.read(
        internalImportServiceProvider.future,
      );
      final notifier = ref.read(syncProgressNotifierProvider.notifier);
      notifier.reset();

      await importService.importFiles(
        files,
        targetParentPath: parentPath,
        isCatalog: isCatalog,
        onProgress: (progress) => notifier.updateProgress(progress),
      );
      ref.invalidate(recentMediaProvider);
    }
  }

  /// フォルダをインポートする（再帰的かつフォルダ構造を作成）
  Future<void> importFolder({
    required Future<ImportCatalogOptions?> Function() askCatalogOptions,
  }) async {
    final storageService = await ref.read(
      externalStorageServiceProvider.future,
    );
    final dirUri = await runImportPicker(pick: storageService.pickFolder);
    if (dirUri == null) return;

    final notifier = ref.read(syncProgressNotifierProvider.notifier);
    notifier.reset();
    final catalogOptions = await askCatalogOptions();
    if (catalogOptions == null) return;
    final isCatalog = catalogOptions.isCatalog;
    final registerChildFolders = catalogOptions.registerChildFolders;

    final parentPath = ref
        .read(mediaFilterNotifierProvider(AppMode.internal))
        .parentPath;
    final importService = await ref.read(internalImportServiceProvider.future);
    notifier.reset();

    await importService.importFolder(
      dirUri,
      targetParentPath: parentPath,
      isCatalog: isCatalog,
      registerChildFolders: registerChildFolders,
      onProgress: (progress) => notifier.updateProgress(progress),
    );
    ref.invalidate(recentMediaProvider);
  }
}
