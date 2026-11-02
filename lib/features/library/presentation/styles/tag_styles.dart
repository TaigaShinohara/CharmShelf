import 'package:flutter/material.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

/// ライブラリのカードとリストに直接表示するタグ数の上限。
const libraryTagPreviewLimit = 12;

/// タグの表示色を一貫して取得するための拡張
extension TagColorExtension on Tag {
  /// 表示に使用する色を取得する
  ///
  /// 優先順位:
  /// 1. [Tag] 自体が持つ [colorValue]
  /// 2. 所属する [TagFacet] が持つ [colorValue]
  /// 3. システムデフォルト色 (secondaryContainer の透過色)
  Color getEffectiveColor(BuildContext context, TagFacet? facet) {
    // 1. タグ固有の色
    if (colorValue != null) {
      return Color(colorValue!);
    }

    // 2. ファセットの色
    if (facet?.colorValue != null) {
      return Color(facet!.colorValue!);
    }

    // 3. デフォルト色
    return Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.7);
  }
}
