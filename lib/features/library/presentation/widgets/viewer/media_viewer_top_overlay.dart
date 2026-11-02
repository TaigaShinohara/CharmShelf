import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

class MediaViewerTopOverlay extends ConsumerWidget {
  final MediaItem item;

  const MediaViewerTopOverlay({super.key, required this.item});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.settingsFileName,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SelectableText(p.basename(item.path)),
          const SizedBox(height: 12),
          if (item.collection.value?.tags.isNotEmpty ?? false)
            Consumer(
              builder: (context, ref, child) {
                final asyncFacets = ref.watch(tagFacetListViewModelProvider);
                return asyncFacets.when(
                  data: (facets) {
                    final facetById = {for (final f in facets) f.id: f};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AppTagWrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: (() {
                          final secretModeAsync = ref.watch(secretModeProvider);
                          final allTags =
                              item.collection.value?.tags.toList() ?? [];

                          final isSecretMode =
                              secretModeAsync.asData?.value ?? false;
                          final filteredTags = isSecretMode
                              ? allTags
                              : allTags.where((t) => !t.isHidden).toList();

                          return filteredTags.map((t) {
                            final facet = t.facetId != null
                                ? facetById[t.facetId!]
                                : null;
                            final color = t.getEffectiveColor(context, facet);
                            return AppTag(
                              label: t.name,
                              size: AppTagSize.large,
                              maxLines: null,
                              color: color,
                              isDimmed: t.isHidden,
                            );
                          }).toList();
                        })(),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${l10n.settingsFileSize}: ${item.size == null ? l10n.viewerUnknownFileSize : _formatBytes(item.size!)}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${l10n.settingsFileAddedAt}: ${DateTimeUtils.formatDate(context, item.addedAt)}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
