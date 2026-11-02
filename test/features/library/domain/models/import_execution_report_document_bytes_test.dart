import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';

void main() {
  test(
    'measured source bytes survive report persistence and a retry-state copy',
    () {
      const report = ImportExecutionReport(
        sessionId: 'document-session',
        totalItems: 2,
        processedItems: 1,
        failedItems: 1,
        failureThresholdCount: 5,
        committedItems: [
          ImportCommittedItem(
            id: 1,
            path: 'library/photo.jpg',
            sourcePath: 'document-one',
            sizeBytes: 4096,
          ),
        ],
        pendingSourcePaths: ['document-two'],
      );

      final restored = ImportExecutionReport.fromMap(report.toMap());
      final copied = restored.copyWith(failedItems: 0);

      expect(copied.sessionId, 'document-session');
      expect(copied.committedFiles.single.sizeBytes, 4096);
      expect(copied.committedFiles.single.sourcePath, 'document-one');
      expect(copied.pendingSourcePaths, ['document-two']);
    },
  );

  test(
    'old report entries remain readable with unknown committed byte size',
    () {
      final item = ImportCommittedItem.fromMap({
        'id': 1,
        'path': 'library/photo.jpg',
        'sourcePath': 'document-one',
      });

      expect(item.sizeBytes, isNull);
      expect(item.id, 1);
      expect(item.sourcePath, 'document-one');
      expect(ImportCommittedItem.fromMap(item.toMap()).sizeBytes, isNull);
    },
  );
}
