import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/helpers/catalog_navigation_helper.dart';

MediaItem _item(int id, MediaType type) => MediaItem()
  ..id = id
  ..path = 'catalog/$id'
  ..type = type;

void main() {
  test('前回閲覧したファイルを初期表示に選ぶ', () {
    final items = [
      _item(1, MediaType.folder),
      _item(2, MediaType.file),
      _item(3, MediaType.file),
    ];

    expect(selectCatalogInitialItem(items, 3)?.id, 3);
  });

  test('前回位置がない場合は先頭ファイルを選ぶ', () {
    final items = [
      _item(1, MediaType.folder),
      _item(2, MediaType.file),
      _item(3, MediaType.file),
    ];

    expect(selectCatalogInitialItem(items, 99)?.id, 2);
    expect(selectCatalogInitialItem(items, null)?.id, 2);
  });

  test('ファイルがない場合は初期表示を選ばない', () {
    expect(
      selectCatalogInitialItem([_item(1, MediaType.folder)], null),
      isNull,
    );
  });
}
