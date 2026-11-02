import 'collection.dart';
import 'media_item.dart';

/// A visible history entry and its current catalog, without persisted UI state.
class RecentlyOpenedFile {
  const RecentlyOpenedFile({required this.item, this.catalog});

  final MediaItem item;
  final MediaCollection? catalog;
}
