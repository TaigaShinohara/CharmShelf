import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _Filter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(rootOnly: true);
}

class _Folders extends ExternalFolderList {
  _Folders(this.folders);
  final List<MediaCollection> folders;
  @override
  List<MediaCollection> build() => folders;
}

class _Items extends ExternalFolderItems {
  _Items(this.items);
  final List<MediaItem> items;
  @override
  List<MediaItem> build(String? folderPath) => items;
}

void main() {
  test('外部フォルダの一括操作も項目自身のカタログ登録状態だけで判定する', () async {
    final catalog = MediaCollection()
      ..path = 'content://provider/catalog'
      ..type = CollectionType.externalFolder
      ..isCatalog = true;
    final plain = MediaCollection()
      ..path = 'content://provider/plain'
      ..type = CollectionType.externalFolder
      ..tier = 5;
    final catalogItem = MediaItem()
      ..id = 1
      ..path = catalog.path
      ..collection.value = catalog;
    final child = MediaItem()
      ..id = 2
      ..path = '${catalog.path}/child.jpg'
      ..parentPath = catalog.path
      ..collection.value = catalog;
    final container = ProviderContainer(
      overrides: [
        mediaFilterNotifierProvider(AppMode.external).overrideWith(_Filter.new),
        externalFolderListProvider.overrideWith(
          () => _Folders([catalog, plain]),
        ),
        externalFolderItemsProvider(
          null,
        ).overrideWith(() => _Items([catalogItem, child])),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      externalFolderListProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(externalFolderListProvider.future);
    await container.read(externalLibraryViewModelProvider.future);
    final model = container.read(externalLibraryViewModelProvider.notifier);

    model.toggleCollectionSelection(plain.path);
    expect(model.canApplyBulkTags, isFalse);
    expect(model.canApplyBulkTier, isFalse);
    model.clearSelection();
    model.toggleCollectionSelection(catalog.path);
    expect(model.canApplyBulkTags, isTrue);
    model.toggleCollectionSelection(plain.path);
    expect(model.canApplyBulkTags, isFalse);
    model.clearSelection();
    model.toggleSelection(child.id);
    expect(model.canApplyBulkTags, isFalse);
    model.clearSelection();
    model.toggleSelection(catalogItem.id);
    expect(model.canApplyBulkTags, isTrue);
  });
}
