import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

part 'media_filter.freezed.dart';

@freezed
abstract class MediaFilter with _$MediaFilter {
  const MediaFilter._();

  const factory MediaFilter({
    String? parentPath, // フォルダ階層
    List<int>? tagIds, // タグ絞り込み (AND/OR)
    List<int>? excludedTagIds, // 除外タグ
    List<int>? tiers, // ティア絞り込み (複数選択)
    String? searchQuery, // テキスト検索
    SearchTarget? searchTarget, // 検索対象（未選択時は表示モードを引き継ぐ）
    bool? hasTags, // タグあり/なし/すべて (null=すべて, true=あり, false=なし)
    bool? isFavorite, // お気に入り
    @Default(false) bool? isArchived, // アーカイブ
    @Default(false) bool? isHidden, // 非表示
    List<MediaType>? mediaTypes, // 種別 (file/folder)
    int? limit, // 取得件数制限
    MediaSourceType? sourceType, // データソース種別
    String? path, // パス (完全一致)
    bool? rootOnly, // ルート階層のみ (parentPath == null)
    @Default(SortOrder.addedDesc) SortOrder sortOrder,
    @Default(false) bool onlyCatalogs,

    /// 検索中も今開いているフォルダに限る。未指定時は棚全体を探す。
    @Default(false) bool searchWithinParent,
  }) = _MediaFilter;

  bool get keepsParentWhileSearching =>
      (searchQuery?.trim().isNotEmpty ?? false) &&
      searchWithinParent &&
      parentPath != null;
}

enum SortOrder {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc, // 名前順 (降順)
  sizeDesc, // サイズ (大きい順)
  sizeAsc, // サイズ (小さい順)
  tierDesc,
  tierAsc, // ティア (低い順)
  favoriteDesc,
  lastViewedDesc, // 閲覧日時順 (降順)
  addedDesc,
  updatedDesc,
  addedAsc,
  updatedAsc,
}

enum ViewMode { grid, list }

enum SearchTarget { catalogsOnly, filesIncluded }

/// Searching is independent from the library's catalog display mode.
extension MediaFilterSearchTarget on MediaFilter {
  SearchTarget get effectiveSearchTarget =>
      searchTarget ?? SearchTarget.filesIncluded;
}
