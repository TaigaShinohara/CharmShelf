import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';

void main() {
  group('RestorableDataSummary', () {
    test('すべての件数が0の場合は hasAnyItems が false を返す', () {
      const summary = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 0,
        collectionCount: 0,
        mediaItemCount: 0,
        folderCount: 0,
        storagePath: '/test',
      );

      expect(summary.totalItemCount, 0);
      expect(summary.hasAnyItems, isFalse);
    });

    test('メディア・タグ・コレクションのいずれかが1件以上ある場合は hasAnyItems が true を返す', () {
      const mediaOnly = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: false,
        tagCount: 0,
        collectionCount: 0,
        mediaItemCount: 1,
        folderCount: 1,
        storagePath: '/test',
      );
      expect(mediaOnly.totalItemCount, 1);
      expect(mediaOnly.hasAnyItems, isTrue);

      const tagOnly = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 3,
        collectionCount: 0,
        mediaItemCount: 0,
        folderCount: 0,
        storagePath: '/test',
      );
      expect(tagOnly.totalItemCount, 3);
      expect(tagOnly.hasAnyItems, isTrue);

      const collectionOnly = RestorableDataSummary(
        hasRestorableData: true,
        hasMetadataFile: true,
        tagCount: 0,
        collectionCount: 2,
        mediaItemCount: 0,
        folderCount: 2,
        storagePath: '/test',
      );
      expect(collectionOnly.totalItemCount, 2);
      expect(collectionOnly.hasAnyItems, isTrue);
    });
  });
}
