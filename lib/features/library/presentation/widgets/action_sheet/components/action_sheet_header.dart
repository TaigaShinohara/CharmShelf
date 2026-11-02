import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/core/utils/file_size_utils.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/shared/widgets/icon/catalogize_icon.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';

/// アクションシート上部ヘッダー（サムネイル・タイトル・親カタログ・インライン詳細情報）
class ActionSheetHeader extends ConsumerStatefulWidget {
  final MediaItem? item;
  final String? collectionPath;
  final MediaCollection? collection;
  final List<Tag>? tags;
  final String title;
  final bool showOpenContentsAction;
  final VoidCallback? onOpenContents;

  const ActionSheetHeader({
    super.key,
    this.item,
    this.collectionPath,
    this.collection,
    this.tags,
    required this.title,
    this.showOpenContentsAction = false,
    this.onOpenContents,
  });

  @override
  ConsumerState<ActionSheetHeader> createState() => _ActionSheetHeaderState();
}

class _ActionSheetHeaderState extends ConsumerState<ActionSheetHeader> {
  bool _isInfoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final collection = widget.collection;
    final isCollection = collection != null;
    final showType = isCollection;

    final parentPath =
        item?.parentPath ??
        (widget.collectionPath != null
            ? p.dirname(widget.collectionPath!)
            : null);
    final parentCatalogAsync = ref.watch(
      parentCatalogProvider(parentPath: parentPath),
    );
    final parentCatalog = parentCatalogAsync.value;
    final isParentCatalog = parentCatalog != null && parentCatalog.isCatalog;

    final subInfoText = _buildSubInfoText(context, l10n);

    final targetPath = widget.collectionPath ?? widget.item?.path;
    final dynamicCollection = targetPath != null
        ? ref.watch(collectionNotifierProvider(targetPath)).value
        : null;
    final effectiveCollection =
        widget.collection ?? dynamicCollection ?? widget.item?.collection.value;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(context, ref),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showType) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    collection.displayTypeLabel(context),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          if (collection?.alias != null &&
                              collection!.alias!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              collection.alias!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            subInfoText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isParentCatalog) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CatalogizeIcon(
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${l10n.libraryParentCatalogLabel}: ${parentCatalog.alias?.isNotEmpty == true ? parentCatalog.alias! : parentCatalog.title}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                _buildTags(context, ref, effectiveCollection),
                if (widget.showOpenContentsAction &&
                    widget.onOpenContents != null &&
                    collection?.type != CollectionType.file)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AppMenuActionFeedback(
                      icon: Icons.view_list,
                      iconColor: theme.colorScheme.primary,
                      iconSize: 20,
                      onPressed: widget.onOpenContents!,
                      builder: (context, animatedIcon, onPressed) =>
                          OutlinedButton.icon(
                            key: const ValueKey('open-catalog-contents'),
                            icon: animatedIcon,
                            label: Text(l10n.libraryOpenCatalogContents),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: onPressed,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          // インライン詳細情報トグルバー
          InkWell(
            onTap: () {
              setState(() {
                _isInfoExpanded = !_isInfoExpanded;
              });
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withValues(
                  alpha: 0.35,
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsFileFileInfo,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isInfoExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 展開される詳細情報（アコーディオン）
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(children: _buildDetailedInfoRows(context, l10n)),
            ),
            crossFadeState: _isInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(
    BuildContext context,
    WidgetRef ref,
    MediaCollection? collection,
  ) {
    List<Tag> allTags;
    if (widget.tags != null) {
      allTags = widget.tags!;
    } else if (collection != null) {
      if (collection.tags.isAttached && !collection.tags.isLoaded) {
        collection.tags
            .load()
            .then((_) {
              if (mounted) setState(() {});
            })
            .catchError((_) {});
        return const SizedBox.shrink();
      }
      allTags = collection.tags.toList();
    } else {
      return const SizedBox.shrink();
    }

    if (allTags.isEmpty) return const SizedBox.shrink();

    final secretModeAsync = ref.watch(secretModeProvider);
    final isSecretMode = secretModeAsync.value ?? false;
    final visibleTags = isSecretMode
        ? allTags
        : allTags.where((t) => !t.isHidden).toList();

    if (visibleTags.isEmpty) return const SizedBox.shrink();

    final asyncFacets = ref.watch(tagFacetListViewModelProvider);
    final facets = asyncFacets.value ?? [];
    final facetById = {for (final f in facets) f.id: f};

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppTagWrap(
        spacing: 6,
        runSpacing: 6,
        children: visibleTags.map((tag) {
          final facet = tag.facetId != null ? facetById[tag.facetId!] : null;
          final color = tag.getEffectiveColor(context, facet);
          return AppTag(
            label: tag.name,
            size: AppTagSize.small,
            color: color,
            isDimmed: tag.isHidden,
          );
        }).toList(),
      ),
    );
  }

  String _buildSubInfoText(BuildContext context, AppLocalizations l10n) {
    final item = widget.item;
    final collection = widget.collection;

    if (item != null) {
      final sizeStr = item.size != null
          ? FileSizeUtils.formatBytes(item.size)
          : null;
      final dateStr = DateTimeUtils.formatCompactDate(context, item.updatedAt);
      if (sizeStr != null && item.type != MediaType.folder) {
        return '$sizeStr • $dateStr';
      }
      return dateStr;
    } else if (collection != null) {
      final dateStr = DateTimeUtils.formatCompactDate(
        context,
        collection.updatedAt,
      );
      return dateStr;
    }
    return '';
  }

  List<Widget> _buildDetailedInfoRows(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final item = widget.item;
    final collection = widget.collection;
    final rows = <Widget>[];

    if (item != null) {
      rows.add(_InfoRow(label: l10n.settingsFilePath, value: item.path));
      if (item.originalPath.isNotEmpty && item.originalPath != item.path) {
        rows.add(
          _InfoRow(
            label: l10n.settingsFileOriginalPath,
            value: item.originalPath,
          ),
        );
      }
      if (item.size != null) {
        rows.add(
          _InfoRow(
            label: l10n.settingsFileSize,
            value: FileSizeUtils.formatBytes(item.size),
          ),
        );
      }
      rows.add(
        _InfoRow(
          label: l10n.settingsFileAddedAt,
          value: DateTimeUtils.formatDateTime(context, item.addedAt),
        ),
      );
      rows.add(
        _InfoRow(
          label: l10n.settingsFileUpdatedAt,
          value: DateTimeUtils.formatDateTime(context, item.updatedAt),
        ),
      );
      rows.add(
        _InfoRow(
          label: l10n.settingsFileSource,
          value: item.sourceType == MediaSourceType.localCopy
              ? l10n.settingsFileSourceLocal
              : l10n.settingsFileSourceExternal,
        ),
      );
    } else if (collection != null) {
      rows.add(_InfoRow(label: l10n.settingsFilePath, value: collection.path));
      rows.add(
        _InfoRow(
          label: l10n.settingsCollectionCreatedAt,
          value: DateTimeUtils.formatDateTime(context, collection.createdAt),
        ),
      );
      rows.add(
        _InfoRow(
          label: l10n.settingsCollectionUpdatedAt,
          value: DateTimeUtils.formatDateTime(context, collection.updatedAt),
        ),
      );
      rows.add(
        _InfoRow(
          label: l10n.settingsCollectionTier,
          value: collection.mediaTier.localizedLabel(context),
        ),
      );
    }

    return rows;
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const size = 64.0;

    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );

    if (useSecretMode) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildItemIcon(
          color: theme.colorScheme.onSurfaceVariant,
          size: 28,
        ),
      );
    }

    final item = widget.item;
    final collection = widget.collection;

    if (collection?.coverImagePath != null) {
      return _buildImageFile(context, ref, collection!.coverImagePath!, size);
    }

    if (item != null) {
      if (item.thumbnailPath != null) {
        return _buildImageFile(context, ref, item.thumbnailPath!, size);
      }
      if (item.sourceType == MediaSourceType.externalReference &&
          item.type == MediaType.file) {
        return _buildExternalThumbnail(context, ref, size);
      }
      if (item.isImage) {
        return _buildImageFile(context, ref, item.path, size);
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildItemIcon(
        color: theme.colorScheme.onSurfaceVariant,
        size: 30,
      ),
    );
  }

  Widget _buildImageFile(
    BuildContext context,
    WidgetRef ref,
    String relativePath,
    double size,
  ) {
    final theme = Theme.of(context);
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, relativePath));

    if (!file.existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildItemIcon(
          color: theme.colorScheme.onSurfaceVariant,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: 200,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.w(
            LogTag.ui,
            'ヘッダー画像デコード失敗: ${file.path}',
            error,
            stackTrace,
          );
          return Container(
            width: size,
            height: size,
            color: theme.colorScheme.surfaceContainerHighest,
            child: _buildItemIcon(
              color: theme.colorScheme.onSurfaceVariant,
              size: 30,
            ),
          );
        },
      ),
    );
  }

  Widget _buildExternalThumbnail(
    BuildContext context,
    WidgetRef ref,
    double size,
  ) {
    final theme = Theme.of(context);
    final asyncBytes = ref.watch(externalThumbnailProvider(widget.item!));
    return asyncBytes.when(
      data: (bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: 200,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildItemIcon(
            color: theme.colorScheme.onSurfaceVariant,
            size: 30,
          ),
        );
      },
      loading: () => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildItemIcon(
          color: theme.colorScheme.onSurfaceVariant,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildItemIcon({Color? color, double? size}) {
    if (widget.collection?.isCatalog ?? false) {
      return CatalogizeIcon(color: color, size: size);
    }
    return Icon(_getIconData(), color: color, size: size);
  }

  IconData _getIconData() {
    final item = widget.item;
    if (item == null) return Icons.folder;
    if (item.type == MediaType.folder) return Icons.folder;
    if (item.isImage) return Icons.image;
    if (item.isVideo) return Icons.movie;
    if (item.isAudio) return Icons.audiotrack;
    if (item.isDocument) return Icons.description;
    if (item.isArchive) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
