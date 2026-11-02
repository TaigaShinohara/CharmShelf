import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/tree_view_state_provider.dart';

void main() {
  test('展開した子を平坦化し、更新と折りたたみを反映する', () async {
    final folder = MediaItem()
      ..id = 1
      ..path = 'folder'
      ..type = MediaType.folder;
    final first = MediaItem()
      ..id = 2
      ..path = 'folder/first.jpg'
      ..parentPath = folder.path;
    final second = MediaItem()
      ..id = 3
      ..path = 'folder/second.jpg'
      ..parentPath = folder.path;
    final children = StreamController<List<MediaItem>>.broadcast();
    final container = ProviderContainer(
      overrides: [
        folderChildrenProvider(
          folder.path,
        ).overrideWith((ref) => children.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await children.close();
    });

    final roots = [folder];
    final subscription = container.listen(
      treeMediaItemsProvider(roots),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(container.read(treeMediaItemsProvider(roots)), hasLength(1));

    container
        .read(expandedFoldersNotifierProvider.notifier)
        .toggle(folder.path);
    await Future<void>.delayed(Duration.zero);
    children.add([first]);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(treeMediaItemsProvider(roots)).map((node) => node.item.id),
      [1, 2],
    );
    expect(container.read(treeMediaItemsProvider(roots)).last.depth, 1);

    children.add([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(treeMediaItemsProvider(roots)), hasLength(3));

    children.add([folder]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(treeMediaItemsProvider(roots)), hasLength(1));

    container
        .read(expandedFoldersNotifierProvider.notifier)
        .toggle(folder.path);
    expect(container.read(treeMediaItemsProvider(roots)), hasLength(1));
  });
}
