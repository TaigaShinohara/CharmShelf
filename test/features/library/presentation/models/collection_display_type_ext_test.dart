import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';

void main() {
  test('registration alone controls catalog display for every source type', () {
    for (final type in CollectionType.values) {
      final collection = MediaCollection()
        ..type = type
        ..tier = 5;
      expect(collection.displayType, isNot(CollectionDisplayType.catalog));
      collection.isCatalog = true;
      expect(collection.displayType, CollectionDisplayType.catalog);
      collection.isCatalog = false;
      expect(collection.displayType, isNot(CollectionDisplayType.catalog));
    }
  });

  test('catalog registration takes precedence over the source type', () {
    final folderCatalog = MediaCollection()
      ..type = CollectionType.folder
      ..isCatalog = true;
    final fileCatalog = MediaCollection()
      ..type = CollectionType.file
      ..isCatalog = true;

    expect(folderCatalog.displayType, CollectionDisplayType.catalog);
    expect(fileCatalog.displayType, CollectionDisplayType.catalog);
  });

  test('unregistered folders and files use their source type', () {
    final folder = MediaCollection()
      ..type = CollectionType.folder
      ..isCatalog = false;
    final externalFolder = MediaCollection()
      ..type = CollectionType.externalFolder
      ..isCatalog = false;
    final file = MediaCollection()
      ..type = CollectionType.file
      ..isCatalog = false;

    expect(folder.displayType, CollectionDisplayType.folder);
    expect(externalFolder.displayType, CollectionDisplayType.folder);
    expect(file.displayType, CollectionDisplayType.file);
  });
}
