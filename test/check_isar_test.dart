import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';

void main() {
  test('Isar schemas open and close correctly in temp directory', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('isar_test_');
    try {
      final isar = await Isar.open([
        MediaItemSchema,
        MediaCollectionSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ], directory: tempDir.path);
      expect(isar.isOpen, isTrue);
      await isar.close();
    } catch (e) {
      final message = e.toString();
      if (message.contains('initializeCoreBinary') ||
          message.contains('Could not initialize IsarCore') ||
          message.contains('Failed to load dynamic library') ||
          message.contains('libisar')) {
        // Native Isar library might not be present in unit test environment
        return;
      }
      rethrow;
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
