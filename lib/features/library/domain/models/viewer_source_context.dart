import 'package:flutter/foundation.dart';
import 'media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/settings/domain/models/app_mode.dart';

/// ビューワーの起動元コンテキスト種別
enum ViewerSourceKind {
  folder,
  recent,
  favorites,
  tag,
  customList,
  catalog,
  single,
}

/// ビューワーで表示する対象アイテムのソースコンテキスト
@immutable
class ViewerSourceContext {
  final ViewerSourceKind kind;
  final String? parentPath;
  final AppMode? appMode;
  final String? tagName;
  final List<MediaItem>? customItems;
  final MediaFilter? catalogFilter;

  const ViewerSourceContext._({
    required this.kind,
    this.parentPath,
    this.appMode,
    this.tagName,
    this.customItems,
    this.catalogFilter,
  });

  /// フォルダ内アイテムを対象とする
  const ViewerSourceContext.folder({
    required String? parentPath,
    AppMode? appMode,
  }) : this._(
         kind: ViewerSourceKind.folder,
         parentPath: parentPath,
         appMode: appMode,
       );

  /// ホーム画面の「最近のアイテム」を対象とする
  const ViewerSourceContext.recent() : this._(kind: ViewerSourceKind.recent);

  /// お気に入りアイテム一覧を対象とする
  const ViewerSourceContext.favorites()
    : this._(kind: ViewerSourceKind.favorites);

  /// タグ絞り込み一覧を対象とする
  const ViewerSourceContext.tag(String tagName)
    : this._(kind: ViewerSourceKind.tag, tagName: tagName);

  /// 明示的に渡されたアイテム一覧を対象とする
  const ViewerSourceContext.customList(List<MediaItem> items)
    : this._(kind: ViewerSourceKind.customList, customItems: items);

  /// カタログ内のアイテム一覧を対象とする
  const ViewerSourceContext.catalog({
    required List<MediaItem> items,
    required String parentPath,
    required AppMode appMode,
    MediaFilter? catalogFilter,
  }) : this._(
         kind: ViewerSourceKind.catalog,
         parentPath: parentPath,
         appMode: appMode,
         customItems: items,
         catalogFilter: catalogFilter,
       );

  /// 単一アイテムのみを対象とする
  const ViewerSourceContext.single() : this._(kind: ViewerSourceKind.single);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerSourceContext &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          parentPath == other.parentPath &&
          appMode == other.appMode &&
          tagName == other.tagName &&
          catalogFilter == other.catalogFilter &&
          listEquals(customItems, other.customItems);

  @override
  int get hashCode => Object.hash(
    kind,
    parentPath,
    appMode,
    tagName,
    catalogFilter,
    customItems == null ? null : Object.hashAll(customItems!),
  );
}

/// ルート遷移時に渡すオプショナル引数
@immutable
class ViewerRouteArgs {
  final MediaItem? initialItem;
  final ViewerSourceContext? sourceContext;

  const ViewerRouteArgs({this.initialItem, this.sourceContext});
}
