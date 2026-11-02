// Application layer: coordinates domain contracts with repository providers.
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'create_folder_use_case.g.dart';

@Riverpod(keepAlive: true)
CreateFolderUseCase createFolderUseCase(Ref ref) {
  return CreateFolderUseCase(
    ref.read(mediaRepositoryProvider.future),
    ref.read(fileServiceProvider),
    ref.read(operationJournalServiceProvider),
  );
}

class CreateFolderUseCase {
  final Future<MediaRepository> _mediaRepositoryFuture;
  final FileService _fileService;
  final OperationJournalService? _journal;
  final Uuid _uuid = const Uuid();

  CreateFolderUseCase(
    this._mediaRepositoryFuture, [
    FileService? fileService,
    this._journal,
  ]) : _fileService = fileService ?? FileService();

  /// 新規フォルダを作成する
  /// [name]: フォルダ名
  /// [parentPath]: 親フォルダの相対パス
  Future<Result<MediaItem, AppError>> invoke(
    String name, {
    String? parentPath,
  }) async {
    final operationId = _uuid.v4();
    try {
      final validationError = FileNameValidator.validate(name);
      if (validationError != null) {
        return Result.failure(
          AppError.validation(
            'Invalid folder name: $validationError',
            context: 'CreateFolderUseCase.invoke',
          ),
        );
      }
      final folderName = name.trim();

      final normalizedParent = parentPath == null || parentPath.isEmpty
          ? 'library'
          : parentPath.startsWith('library/') || parentPath == 'library'
          ? parentPath
          : 'library/$parentPath';
      OperationJournalEntry? journalEntry;
      Future<void> prepareJournal(String path) async {
        journalEntry = OperationJournalEntry(
          id: operationId,
          kind: OperationKind.createFolder,
          stage: OperationStage.planned,
          payload: {'path': path},
        );
        await _journal?.write(journalEntry!);
      }

      final createResult = await _fileService.createUniqueDirectory(
        parentRelativePath: normalizedParent,
        name: folderName,
        onDestinationPrepared: _journal == null ? null : prepareJournal,
      );
      if (createResult.isFailure) {
        await _journal?.remove(operationId);
        return Result.failure(createResult.errorOrNull!);
      }
      final relativeDirPath = createResult.dataOrNull!;
      journalEntry = OperationJournalEntry(
        id: operationId,
        kind: OperationKind.createFolder,
        stage: OperationStage.staged,
        payload: {'path': relativeDirPath},
      );
      await _journal?.write(journalEntry!);

      // DB上の MediaItem として登録 (type: folder)
      final item = MediaItem()
        ..path = relativeDirPath
        ..originalPath = ''
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..type = MediaType.folder
        ..parentPath = normalizedParent == 'library' ? null : normalizedParent;

      final repo = await _mediaRepositoryFuture;
      final saveResult = await repo.save(item);

      if (saveResult is Failure<void, AppError>) {
        final cleanupResult = await _fileService.deleteFile(relativeDirPath);
        if (cleanupResult.isFailure) {
          return Result.failure(
            AppError.file(
              'Folder database save failed and cleanup also failed',
              context: 'CreateFolderUseCase.invoke',
            ).withAdditionalData({'path': relativeDirPath}),
          );
        }
        await _journal?.remove(operationId);
        return Result.failure(saveResult.error);
      }

      journalEntry = journalEntry!.copyWith(stage: OperationStage.committed);
      await _journal?.write(journalEntry!);
      await _journal?.remove(operationId);
      return Result.success(item);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          'Folder creation failed: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }
}
