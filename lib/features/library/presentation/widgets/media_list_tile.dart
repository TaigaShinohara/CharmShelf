import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_summary_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/utils/file_size_utils.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_selection_indicator.dart';
import 'package:private_shelf/features/library/presentation/widgets/catalog_status_icon.dart';

class MediaListTile extends ConsumerWidget {
  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isSimpleDisplay;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? subtitle;
  final Widget? trailing;

  const MediaListTile({
    super.key,
    required this.item,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isSimpleDisplay = false,
    this.depth = 0,
    this.isExpanded = false,
    this.onToggleExpand,
    this.onTap,
    this.onLongPress,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestCollection = item.collection.value;
    final representsCollection =
        latestCollection != null &&
        latestCollection.path == item.path &&
        latestCollection.isCatalog;
    final isItemHidden = item.isHidden || (latestCollection?.isHidden ?? false);
    final surfaceColor = isSelected
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface;

    final isFolder = item.type == MediaType.folder;
    final clampedDepth = depth.clamp(0, 4);
    final indentWidth = depth > 0 ? (clampedDepth * 16.0) : 0.0;

    return Opacity(
      opacity: isItemHidden ? 0.6 : 1.0,
      child: Material(
        color: surfaceColor,
        child: InkWell(
          enableFeedback: false,
          onTap: onTap,
          onLongPress: onLongPress != null
              ? () {
                  unawaited(ref.read(feedbackServiceProvider).mediumImpact());
                  onLongPress!();
                }
              : null,
          child: Container(
            padding: EdgeInsets.only(
              left: (isFolder || depth > 0)
                  ? 2
                  : (representsCollection ? 8.5 : 12),
              right: representsCollection ? 8.5 : 12,
              top: isSimpleDisplay ? 4 : 6,
              bottom: isSimpleDisplay ? 4 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Finder風 階層インデントとガイド線
                if (depth > 0)
                  SizedBox(
                    width: indentWidth,
                    height: isSimpleDisplay ? 40 : 54,
                    child: CustomPaint(
                      painter: _TreeGuidePainter(
                        depth: clampedDepth,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                // 展開矢印（フォルダかつツリーモード時）
                if (isFolder)
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: isExpanded
                          ? AppLocalizations.of(context)!.commonCollapse
                          : AppLocalizations.of(context)!.commonExpand,
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: isExpanded ? 0.25 : 0.0,
                        child: Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Icon(
                            Icons.arrow_right_rounded,
                            size: 24,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      onPressed: onToggleExpand != null
                          ? () async {
                              await ref
                                  .read(feedbackServiceProvider)
                                  .lightImpact();
                              onToggleExpand!();
                            }
                          : null,
                    ),
                  )
                else if (depth > 0)
                  const SizedBox(width: 8),
                Transform.translate(
                  offset: isFolder ? const Offset(-10, 0) : Offset.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThumbnailWithStatusOverlay(
                        context,
                        ref,
                        latestCollection,
                        isItemHidden,
                        representsCollection,
                      ),
                      if (item.sourceType == MediaSourceType.externalReference)
                        _buildExternalStatusIcon(context),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTitle(context, ref, representsCollection),
                      subtitle ??
                          _buildSubtitle(context, ref, representsCollection),
                    ],
                  ),
                ),
                trailing ?? _buildTrailing(context, ref, representsCollection),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStatusIcons(
    BuildContext context,
    MediaCollection? latestCollection,
    bool isItemHidden,
    bool representsCollection,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExternal = item.sourceType == MediaSourceType.externalReference;

    if (!isExternal) {
      return const SizedBox.shrink();
    }

    const iconSize = 11.0;

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExternal)
            Icon(Icons.link, size: iconSize, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildExternalStatusIcon(BuildContext context) =>
      _buildThumbnailStatusIcons(context, null, false, false);

  Widget _buildThumbnailWithStatusOverlay(
    BuildContext context,
    WidgetRef ref,
    MediaCollection? latestCollection,
    bool isItemHidden,
    bool representsCollection,
  ) {
    final isPinned =
        representsCollection && (latestCollection?.isPinned ?? false);
    final isFavorite = representsCollection
        ? (latestCollection?.isFavorite ?? false)
        : item.isFavorite;
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _buildThumbnail(context, ref, representsCollection),
          if (isPinned || isFavorite || isItemHidden)
            Positioned(
              top: 3,
              left: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPinned) const CatalogStatusIcon.pin(size: 17),
                  if (isPinned && (isFavorite || isItemHidden))
                    const SizedBox(width: 2),
                  if (isFavorite) const CatalogStatusIcon.favorite(size: 17),
                  if (isFavorite && isItemHidden) const SizedBox(width: 2),
                  if (isItemHidden) const CatalogStatusIcon.hidden(size: 17),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    AppLocalizations? l10n,
    bool representsCollection,
    MediaCollection? latestCollection,
    bool isFolder,
    String ext,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (representsCollection && latestCollection != null) {
      final tier = MediaTier.fromInt(latestCollection.tier);
      final isUnranked = tier == MediaTier.none;
      final tierColor = isUnranked
          ? colorScheme.onSurfaceVariant
          : tier.color(context);
      final badgeForeground = isUnranked ? colorScheme.surface : tierColor;
      return Container(
        margin: const EdgeInsets.only(right: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
        decoration: BoxDecoration(
          color: isUnranked ? tierColor : tierColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tierColor.withValues(alpha: 0.9),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            latestCollection.displayTypeIcon(color: badgeForeground, size: 10),
            const SizedBox(width: 2.5),
            Text(
              latestCollection.displayTypeLabel(context),
              style: TextStyle(
                color: badgeForeground,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    if (!representsCollection && !isFolder && ext.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(right: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Text(
          ext,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTitle(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    var originalName = p.basename(item.path);
    final collection = item.collection.value;
    String? alias;

    if (representsCollection && collection != null) {
      originalName = collection.title;
      alias = collection.alias;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final hasAlias = !isSimpleDisplay && alias != null && alias.isNotEmpty;
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) >= 21;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1行目: ファイル名
        Text(
          originalName,
          maxLines: isLargeText ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSimpleDisplay ? 13 : 14,
            fontWeight: (representsCollection || isExpanded)
                ? FontWeight.w600
                : FontWeight.w500,
            color: isExpanded ? colorScheme.primary : null,
          ),
        ),
        // エイリアス
        if (hasAlias)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              alias,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final collection = item.collection.value;
    final formattedDate = DateTimeUtils.formatCompactDate(
      context,
      representsCollection
          ? collection?.updatedAt ?? item.updatedAt
          : item.updatedAt,
    );
    if (isSimpleDisplay) {
      return Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          formattedDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      );
    }
    final isFolder = item.type == MediaType.folder;
    final ext = FileSizeUtils.getExtension(item.path);
    final hasBadge = !representsCollection && !isFolder && ext.isNotEmpty;
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) >= 21;

    String? folderSummaryText;
    String? fileSizeText;

    if (!representsCollection) {
      if (isFolder) {
        final asyncSummary = ref.watch(folderSummaryProvider(item.path));
        folderSummaryText = asyncSummary.when(
          data: (summary) {
            if (summary.totalCount > 0) {
              return l10n.libraryFolderSummaryCounts(
                summary.folderCount,
                summary.fileCount,
                summary.catalogCount,
              );
            } else {
              return l10n.libraryFolderSummaryEmpty;
            }
          },
          loading: () => l10n.libraryItemTypeFolder,
          error: (_, _) => l10n.libraryItemTypeFolder,
        );
      } else {
        fileSizeText = FileSizeUtils.formatBytes(item.size);
      }
    }

    final dateText = isLargeText ? null : formattedDate;

    // ファイル容量と更新日時を「ファイル容量   更新日時」の順で配置
    final bottomLineText = [
      if (fileSizeText != null && fileSizeText.isNotEmpty) fileSizeText,
      // 既存のコード生成ツールが解釈できる構文を維持する。
      // ignore: use_null_aware_elements
      if (dateText != null) dateText,
    ].join('   ');
    final hasBottomLine = hasBadge || bottomLineText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // バッジ + ファイル容量・更新日時
          if (hasBottomLine)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasBadge)
                  _buildBadge(
                    context,
                    l10n,
                    representsCollection,
                    collection,
                    isFolder,
                    ext,
                  ),
                if (bottomLineText.isNotEmpty)
                  Flexible(
                    child: Text(
                      bottomLineText,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          // フォルダサマリー（フォルダバッジの下）
          if (folderSummaryText != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                folderSummaryText,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    final latestCollection = representsCollection
        ? item.collection.value
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelectionMode)
          LibrarySelectionIndicator(
            isSelected: isSelected,
            onPressed: () {
              onTap?.call();
            },
          )
        else
          _buildMenuButton(
            context,
            ref,
            representsCollection,
            latestCollection,
          ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
    MediaCollection? latestCollection,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.libraryMoreActions,
      icon: const Icon(Icons.more_vert),
      iconSize: 28,
      onPressed: () {
        showAppBottomSheet(
          context,
          showCloseButton: true,
          child: representsCollection
              ? CollectionActionSheet(
                  collectionPath: item.path,
                  initialTitle:
                      latestCollection?.title ?? p.basename(item.path),
                  item: item,
                )
              : FileActionSheet(item: item),
        );
      },
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    // シークレットサムネモードの確認
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );

    final isFolder = item.type == MediaType.folder;

    return Container(
      width: isSimpleDisplay ? 40 : 50,
      height: isSimpleDisplay ? 40 : 50,
      decoration: BoxDecoration(
        color: isFolder && !representsCollection
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: useSecretMode
          ? Icon(
              _getIconData(),
              color: isFolder && !representsCollection
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: isFolder ? 28 : 22,
            )
          : _buildImageContent(context, ref, representsCollection),
    );
  }

  Widget _buildImageFile(
    BuildContext context,
    WidgetRef ref,
    String relativePath,
  ) {
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, relativePath));
    final ext = p.extension(file.path).toLowerCase();
    final isImageExt = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic',
      '.heif',
      '.tif',
      '.tiff',
    }.contains(ext);
    if (!isImageExt) {
      AppLogger.w(
        LogTag.ui,
        '[ImageDecodeTrace] media_list_tile skip non-image thumbnail itemId=${item.id} relativePath=$relativePath file=${file.path} ext=$ext',
      );
      return Icon(
        _getIconData(),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return Hero(
      tag: 'media_${item.id}_${item.path}',
      child: Image.file(
        file,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: 256,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.w(
            LogTag.ui,
            '[ImageDecodeTrace] media_list_tile Image.file decode failed itemId=${item.id} relativePath=$relativePath file=${file.path} cacheWidth=256 ext=$ext',
            error,
            stackTrace,
          );
          return Icon(
            _getIconData(),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
        },
      ),
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    if (item.thumbnailPath != null) {
      return _buildImageFile(context, ref, item.thumbnailPath!);
    }

    final collectionCover = item.collection.value?.coverImagePath;
    if (representsCollection &&
        collectionCover != null &&
        collectionCover.isNotEmpty) {
      return _buildImageFile(context, ref, collectionCover);
    }

    if (item.type == MediaType.folder && !representsCollection) {
      return _buildFolderIcon(context, ref);
    }

    if (item.sourceType == MediaSourceType.externalReference &&
        item.type == MediaType.file) {
      return _buildExternalThumbnail(context, ref);
    }

    if (item.isImage) {
      return _buildImageFile(context, ref, item.path);
    }

    return Icon(
      _getIconData(),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildExternalThumbnail(BuildContext context, WidgetRef ref) {
    final asyncBytes = ref.watch(externalThumbnailProvider(item));
    return asyncBytes.when(
      data: (bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          return Hero(
            tag: 'media_${item.id}_${item.path}',
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: 120,
              errorBuilder: (context, error, stackTrace) {
                AppLogger.e(
                  LogTag.ui,
                  '[ImageDecodeTrace] media_list_tile Image.memory decode failed itemId=${item.id} path=${item.path} bytes=${bytes.length}',
                  error,
                  stackTrace,
                );
                return Icon(
                  _getIconData(),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
              },
            ),
          );
        }
        return Icon(
          _getIconData(),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => Icon(
        _getIconData(),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFolderIcon(BuildContext context, WidgetRef ref) {
    final asyncSummary = ref.watch(folderSummaryProvider(item.path));
    final theme = Theme.of(context);
    final isPrimaryFolder = isExpanded;

    return asyncSummary.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (summary) {
        IconData iconData;
        var iconColor = theme.colorScheme.primary;

        switch (summary.contentType) {
          case FolderContentType.deepDirectory:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.folder_copy_rounded;
            iconColor = theme.colorScheme.primary;
            break;
          case FolderContentType.imageMedia:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.photo_library_outlined;
            iconColor = theme.colorScheme.primary;
            break;
          case FolderContentType.videoMedia:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.video_library_outlined;
            iconColor = theme.colorScheme.primary;
            break;
          case FolderContentType.mixedMedia:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.perm_media_outlined;
            iconColor = theme.colorScheme.primary;
            break;
          case FolderContentType.documents:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.snippet_folder_outlined;
            iconColor = theme.colorScheme.primary;
            break;
          case FolderContentType.empty:
            iconData = isPrimaryFolder
                ? Icons.folder_open_outlined
                : Icons.folder_outlined;
            iconColor = theme.colorScheme.onSurfaceVariant.withValues(
              alpha: 0.6,
            );
            break;
          case FolderContentType.standard:
            iconData = isPrimaryFolder
                ? Icons.folder_open_rounded
                : Icons.folder_rounded;
            iconColor = theme.colorScheme.primary;
            break;
        }

        return Icon(iconData, color: iconColor, size: 26);
      },
      loading: () => Icon(
        isPrimaryFolder ? Icons.folder_open_rounded : Icons.folder_rounded,
        color: theme.colorScheme.primary,
        size: 26,
      ),
      error: (_, _) => Icon(
        isPrimaryFolder ? Icons.folder_open_rounded : Icons.folder_rounded,
        color: theme.colorScheme.primary,
        size: 26,
      ),
    );
  }

  IconData _getIconData() {
    if (item.type == MediaType.folder) return Icons.folder;
    if (item.isImage) return Icons.image;
    if (item.isVideo) return Icons.movie;
    if (item.isAudio) return Icons.audiotrack;
    if (item.isDocument) return Icons.description;
    if (item.isArchive) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}

/// Finder風の階層ツリーガイド線を描画するPainter
class _TreeGuidePainter extends CustomPainter {
  final int depth;
  final Color color;

  const _TreeGuidePainter({required this.depth, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final stepWidth = size.width / depth;

    for (var i = 0; i < depth; i++) {
      final x = (i * stepWidth) + (stepWidth / 2);
      // ガイド縦線
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      // 最深レベルのみ水平ブランチ線を描画
      if (i == depth - 1) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(size.width, size.height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreeGuidePainter oldDelegate) {
    return oldDelegate.depth != depth || oldDelegate.color != color;
  }
}
