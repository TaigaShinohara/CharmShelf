import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/services/internal_import_service.dart';
import 'package:private_shelf/features/library/application/use_cases/advanced_import_use_case.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';

class _ImportService extends Mock implements InternalImportService {}

void main() {
  test(
    'extensionless documents stage with a MIME extension and preserve rejection rules',
    () async {
      final service = _ImportService();
      final source = Uri.parse('content://provider/document/photo');
      final photo = FileTreeNode(
        uri: source,
        sourceDocumentUri: source,
        name: 'photo',
        relativePath: 'document-photo',
        isDirectory: false,
        mimeType: 'image/png',
        size: 3,
      );
      when(
        () => service.importContentFile(
          source,
          'photo.png',
          photo.relativePath,
          expectedBytes: 3,
          maxBytes: any(named: 'maxBytes'),
          onMeasuredBytes: any(named: 'onMeasuredBytes'),
          targetParentPath: null,
          isCatalog: false,
          onProgress: null,
        ),
      ).thenAnswer(
        (_) async => Result.success(
          const ImportExecutionReport(
            totalItems: 1,
            processedItems: 1,
            failedItems: 0,
            failureThresholdCount: 5,
            committedItems: [
              ImportCommittedItem(
                id: 1,
                path: 'library/photo.png',
                sourcePath: 'document-photo',
                sizeBytes: 3,
              ),
            ],
          ),
        ),
      );
      final result = await AdvancedImportUseCase(service).invoke([
        photo,
        FileTreeNode(
          uri: Uri.parse('content://provider/document/unknown'),
          sourceDocumentUri: Uri.parse('content://provider/document/unknown'),
          name: 'unknown',
          relativePath: 'document-unknown',
          isDirectory: false,
          mimeType: 'image/unknown',
        ),
        FileTreeNode(
          uri: Uri.parse('content://provider/document/unsupported'),
          sourceDocumentUri: Uri.parse(
            'content://provider/document/unsupported',
          ),
          name: 'unsupported.bin',
          relativePath: 'document-unsupported',
          isDirectory: false,
          mimeType: 'image/png',
        ),
      ]);

      expect(result.isSuccess, isTrue);
      final report = result.dataOrNull!;
      expect(report.processedItems, 1);
      expect(report.failedItems, 2);
      expect(report.committedFiles.single.path, 'library/photo.png');
      expect(report.failedEntries.map((entry) => entry.reason), [
        ImportFailureReasonCode.unsupported,
        ImportFailureReasonCode.unsupported,
      ]);
      expect(photo.name, 'photo');
    },
  );
}
