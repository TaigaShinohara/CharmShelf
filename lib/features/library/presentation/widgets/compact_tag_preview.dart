import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../../shared/widgets/tag/app_tag.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/tag_facet.dart';
import '../providers/secret_mode_provider.dart';
import '../providers/tag_facet_view_model.dart';
import '../styles/tag_styles.dart';

/// 指定件数までを小サイズで表示し、残りも明示的に確認できるタグ一覧。
class CompactTagPreview extends ConsumerWidget {
  const CompactTagPreview({
    super.key,
    required this.tags,
    required this.onTagTap,
    this.maxVisibleTags = 3,
    this.compactRemainingCount = false,
  }) : assert(maxVisibleTags > 0);

  final List<Tag> tags;
  final ValueChanged<Tag>? onTagTap;
  final int maxVisibleTags;
  final bool compactRemainingCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secretMode = ref.watch(secretModeProvider).asData?.value ?? false;
    final visible = tags.where((tag) => secretMode || !tag.isHidden).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final facets =
        ref.watch(tagFacetListViewModelProvider).value ?? <TagFacet>[];
    final facetById = {for (final facet in facets) facet.id: facet};
    final remaining = visible.length > maxVisibleTags
        ? visible.length - maxVisibleTags
        : 0;
    final l10n = AppLocalizations.of(context)!;

    return AppTagWrap(
      key: const ValueKey('compact-tag-preview-wrap'),
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in visible.take(maxVisibleTags))
          AppTag(
            label: tag.name,
            color: tag.getEffectiveColor(context, facetById[tag.facetId]),
            size: AppTagSize.small,
            isDimmed: tag.isHidden,
            onTap: onTagTap == null ? null : () => onTagTap!(tag),
          ),
        if (remaining > 0)
          TextButton(
            key: const ValueKey('show-more-tags'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              alignment: AlignmentDirectional.centerStart,
            ),
            onPressed: () => showAppBottomSheet(
              context,
              title: l10n.settingsCollectionTag,
              child: Consumer(
                builder: (context, ref, _) {
                  // 開いた後に非表示設定が変わった場合も、非表示タグを漏らさない。
                  final revealHidden =
                      ref.watch(secretModeProvider).asData?.value ?? false;
                  final currentFacets =
                      ref.watch(tagFacetListViewModelProvider).value ??
                      <TagFacet>[];
                  final currentFacetById = {
                    for (final facet in currentFacets) facet.id: facet,
                  };
                  return AppTagWrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in tags.where(
                        (tag) => revealHidden || !tag.isHidden,
                      ))
                        AppTag(
                          label: tag.name,
                          color: tag.getEffectiveColor(
                            context,
                            currentFacetById[tag.facetId],
                          ),
                          size: AppTagSize.large,
                          maxLines: null,
                          isDimmed: tag.isHidden,
                          onTap: onTagTap == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onTagTap!(tag);
                                },
                        ),
                    ],
                  );
                },
              ),
            ),
            child: compactRemainingCount
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '+$remaining',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : Text(l10n.commonMoreCount(remaining)),
          ),
      ],
    );
  }
}
