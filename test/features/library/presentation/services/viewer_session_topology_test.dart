import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_session_topology.dart';

void main() {
  test('別インスタンスでもページ構造に関係する値が同じなら等価', () {
    final first = ViewerSessionTopology.capture([
      _item(1, 'one.png'),
      _item(2, 'two.png', splitSpread: true),
    ]);
    final second = ViewerSessionTopology.capture([
      _item(1, 'one.png'),
      _item(2, 'two.png', splitSpread: true),
    ]);

    expect(second, first);
    expect(second.hashCode, first.hashCode);
  });

  test('順序・パス・メディア種別・見開き設定の変更を区別する', () {
    final baseline = ViewerSessionTopology.capture([
      _item(1, 'one.png'),
      _item(2, 'two.png'),
    ]);

    expect(
      ViewerSessionTopology.capture([_item(2, 'two.png'), _item(1, 'one.png')]),
      isNot(baseline),
    );
    expect(
      ViewerSessionTopology.capture([
        _item(1, 'renamed.png'),
        _item(2, 'two.png'),
      ]),
      isNot(baseline),
    );
    expect(
      ViewerSessionTopology.capture([
        _item(1, 'one.png', mimeType: 'video/mp4'),
        _item(2, 'two.png'),
      ]),
      isNot(baseline),
    );
    expect(
      ViewerSessionTopology.capture([
        _item(1, 'one.png', splitSpread: true),
        _item(2, 'two.png'),
      ]),
      isNot(baseline),
    );
  });
}

MediaItem _item(
  int id,
  String path, {
  String mimeType = 'image/png',
  bool splitSpread = false,
}) {
  final item = MediaItem()
    ..id = id
    ..path = path
    ..originalPath = path
    ..type = MediaType.file
    ..mimeType = mimeType
    ..sourceType = MediaSourceType.localCopy;
  item.collection.value = MediaCollection()..splitSpreadView = splitSpread;
  return item;
}
