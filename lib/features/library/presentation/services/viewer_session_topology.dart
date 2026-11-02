import 'package:flutter/foundation.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

typedef ViewerSplitSpreadResolver = bool Function(MediaItem item);

/// Immutable description of the values that can change a viewer's page list.
///
/// Repository streams may emit freshly allocated [MediaItem] objects after an
/// unrelated metadata write. Comparing this snapshot keeps the existing
/// PageController and decoded page elements alive unless page topology really
/// changed.
@immutable
class ViewerSessionTopology {
  const ViewerSessionTopology._(this._items);

  factory ViewerSessionTopology.capture(
    List<MediaItem> items, {
    ViewerSplitSpreadResolver? splitSpreadResolver,
  }) {
    final resolveSplit =
        splitSpreadResolver ??
        (item) => item.collection.value?.splitSpreadView ?? false;
    return ViewerSessionTopology._(
      List.unmodifiable(
        items.map(
          (item) => _ViewerSessionItem(
            id: item.id,
            path: item.path,
            originalPath: item.originalPath,
            parentPath: item.parentPath,
            type: item.type,
            mimeType: item.mimeType,
            sourceType: item.sourceType,
            splitSpreadView: resolveSplit(item),
          ),
        ),
      ),
    );
  }

  final List<_ViewerSessionItem> _items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerSessionTopology && listEquals(_items, other._items);

  @override
  int get hashCode => Object.hashAll(_items);
}

@immutable
class _ViewerSessionItem {
  const _ViewerSessionItem({
    required this.id,
    required this.path,
    required this.originalPath,
    required this.parentPath,
    required this.type,
    required this.mimeType,
    required this.sourceType,
    required this.splitSpreadView,
  });

  final int id;
  final String path;
  final String? originalPath;
  final String? parentPath;
  final MediaType type;
  final String? mimeType;
  final MediaSourceType sourceType;
  final bool splitSpreadView;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ViewerSessionItem &&
          id == other.id &&
          path == other.path &&
          originalPath == other.originalPath &&
          parentPath == other.parentPath &&
          type == other.type &&
          mimeType == other.mimeType &&
          sourceType == other.sourceType &&
          splitSpreadView == other.splitSpreadView;

  @override
  int get hashCode => Object.hash(
    id,
    path,
    originalPath,
    parentPath,
    type,
    mimeType,
    sourceType,
    splitSpreadView,
  );
}
