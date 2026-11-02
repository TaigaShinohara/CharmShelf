import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/services/local_notification_service_io.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/application/use_cases/create_folder_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';

part 'internal_import_service_provider.g.dart';

@riverpod
Future<InternalImportService> internalImportService(
  Ref ref,
) async {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  return InternalImportService(
    ref.read(importMediaUseCaseProvider),
    ref.read(createFolderUseCaseProvider),
    await ref.watch(externalStorageServiceProvider.future),
    ref.read(fileServiceProvider),
    ref.read(operationJournalServiceProvider),
    repository,
    ref.read(localNotificationServiceProvider),
    isCancelled: () => ref.read(syncProgressNotifierProvider).isCancelled,
    invalidateCollection: (path) {
      ref.invalidate(collectionNotifierProvider(path));
    },
    invalidateLibrary: () {
      ref.invalidate(recentMediaProvider);
      ref.invalidate(libraryViewModelProvider);
    },
  );
}

@riverpod
Future<AdvancedImportUseCase> advancedImportUseCase(
  Ref ref,
) async {
  final importService = await ref.watch(internalImportServiceProvider.future);
  return AdvancedImportUseCase(importService);
}
