import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/local_thumbnail_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/utils/file_size_utils.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_summary_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'compact_tag_preview.dart';
import 'library_selection_indicator.dart';
import 'catalog_status_icon.dart';

class MediaItemCard extends ConsumerWidget {
  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaItemCard({
    super.key,
    required this.item,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveCollection = item.collection.value;
    final representsCollection =
        effectiveCollection != null &&
        effectiveCollection.path == item.path &&
        effectiveCollection.isCatalog;

    final isItemHidden =
        item.isHidden || (representsCollection && effectiveCollection.isHidden);

    final l10n = AppLocalizations.of(context)!;
    final isFolder = item.type == MediaType.folder;
    final updatedAt = representsCollection
        ? effectiveCollection.updatedAt
        : item.updatedAt;
    final itemName = p.basename(item.path);
    final hasCollection =
        effectiveCollection != null && effectiveCollection.path == item.path;
    final hasCollectionAlias =
        hasCollection && effectiveCollection.alias?.isNotEmpty == true;
    // カタログヘッダーと同じく、エイリアスを主表示にして、元の名前は
    // 補助表示に回す。通常のフォルダ／ファイルはパスの末尾を表示する。
    final displayTitle = hasCollection
        ? (hasCollectionAlias
              ? effectiveCollection.alias!
              : effectiveCollection.title)
        : itemName;
    final semanticsTitle = displayTitle;
    final cardBorderSide = BorderSide(
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: isFolder ? 0.45 : 0.25),
      width: 1.0,
    );

    return Semantics(
      key: ValueKey('media-item-card-${item.id}'),
      container: true,
      button: onTap != null,
      selected: isSelectionMode ? isSelected : null,
      hint: onTap == null
          ? null
          : isSelectionMode
          ? l10n.commonDoubleTapToSelect(semanticsTitle)
          : l10n.commonDoubleTapToActivate,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                unawaited(ref.read(feedbackServiceProvider).lightImpact());
                onTap!();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                unawaited(ref.read(feedbackServiceProvider).mediumImpact());
                onLongPress!();
              },
        child: Opacity(
          opacity: isItemHidden ? 0.6 : 1.0,
          child: RepaintBoundary(
            child: Card(
              margin: AppSpacing.edgeInsetsXs,
              clipBehavior: Clip.antiAlias,
              elevation: representsCollection ? 1 : 0,
              color: isSelected
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : representsCollection
                  ? Theme.of(context).colorScheme.surface
                  : (isFolder
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : Theme.of(context).colorScheme.surface),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusLg,
                side: cardBorderSide,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0, // 1.2から1.0（正方形）に戻す
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildThumbnail(context, ref, representsCollection),
                            // カタログ以外のフォルダ／ファイルも、カタログと同じ
                            // サムネイル左上に種別バッジを表示する。
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBadge(
                                    context,
                                    l10n,
                                    representsCollection,
                                    effectiveCollection,
                                    isFolder,
                                  ),
                                  if (representsCollection)
                                    _buildCollectionStatusIcons(
                                      context,
                                      effectiveCollection,
                                      isItemHidden,
                                    ),
                                ],
                              ),
                            ),
                            // タイトルグラデーションとテキスト (下部)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final isSimple = ref.watch(
                            globalSimpleDisplayProvider,
                          );
                          if (isSimple) {
                            return _buildUpdatedAtRow(context, updatedAt);
                          }
                          return _buildStatusIconRow(
                            context,
                            isItemHidden,
                            representsCollection,
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final isSimple = ref.watch(
                            globalSimpleDisplayProvider,
                          );

                          if (isSimple) return const SizedBox.shrink();

                          if (!representsCollection) {
                            // カタログ以外のアイテム（通常フォルダ / 通常ファイル）の下部情報
                            final formattedDate =
                                DateTimeUtils.formatCompactDate(
                                  context,
                                  item.updatedAt,
                                );
                            final bottomDateText = isFolder
                                ? formattedDate
                                : '${FileSizeUtils.formatBytes(item.size)}   $formattedDate';

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                6.0,
                                4.0,
                                2.0,
                                2.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (isFolder)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        right: 48,
                                      ),
                                      child: _buildItemInfoText(
                                        context,
                                        ref,
                                        l10n,
                                        isFolder,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bottomDateText,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.6),
                                              fontSize: 9,
                                            ),
                                            textAlign: TextAlign.start,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 48),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // カタログ（Collection）の下部情報
                          final tags = effectiveCollection.tags.isLoaded
                              ? effectiveCollection.tags.toList()
                              : const <Tag>[];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // エイリアスがある場合は、元のカタログ名を補助表示する。
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  4.0,
                                  4.0,
                                  4.0,
                                  0.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasCollectionAlias)
                                      Text(
                                        effectiveCollection.title,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (hasCollectionAlias && tags.isNotEmpty)
                                      const SizedBox(height: 3),
                                    if (tags.isNotEmpty)
                                      // 右下のメニューボタン（48px）が重なる
                                      // 領域をタグが使わないようにする。
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 48,
                                        ),
                                        child: _buildTags(context, tags),
                                      ),
                                  ],
                                ),
                              ),
                              // 4行目: 固定底面エリア（更新日時 ＋ メニューボタン）
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  4.0,
                                  0,
                                  2.0,
                                  2.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateTimeUtils.formatCompactDate(
                                          context,
                                          effectiveCollection.updatedAt,
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                          fontSize: 9,
                                        ),
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          key: ValueKey('selected-overlay-${item.id}'),
                          color: Colors.grey.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  if (isSelectionMode)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: LibrarySelectionIndicator(
                        isSelected: isSelected,
                        onPressed: onTap ?? () {},
                      ),
                    )
                  else if (representsCollection)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _buildMenuButton(
                        context,
                        ref,
                        representsCollection,
                        effectiveCollection,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatedAtRow(BuildContext context, DateTime updatedAt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Text(
        DateTimeUtils.formatCompactDate(context, updatedAt),
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 9,
        ),
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCollectionStatusIcons(
    BuildContext context,
    MediaCollection? collection,
    bool isItemHidden,
  ) {
    final isPinned = collection?.isPinned ?? false;
    final isFavorite = collection?.isFavorite ?? item.isFavorite;
    if (!isPinned && !isFavorite && !isItemHidden) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPinned) const CatalogStatusIcon.pin(),
          if (isPinned && isFavorite) const SizedBox(width: 3),
          if (isFavorite) const CatalogStatusIcon.favorite(),
          if (isFavorite && isItemHidden) const SizedBox(width: 3),
          if (isItemHidden) const CatalogStatusIcon.hidden(),
        ],
      ),
    );
  }

  Widget _buildStatusIconRow(
    BuildContext context,
    bool isItemHidden,
    bool representsCollection,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExternal = item.sourceType == MediaSourceType.externalReference;
    final showHidden = isItemHidden && !representsCollection;

    if (!isExternal && !showHidden) {
      return const SizedBox.shrink();
    }

    const slotWidth = 21.0;
    const iconSize = 12.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6.0, 3.0, 6.0, 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: slotWidth,
            height: iconSize,
            child: isExternal
                ? Icon(Icons.link, color: colorScheme.primary, size: iconSize)
                : null,
          ),
          SizedBox(
            width: slotWidth,
            height: iconSize,
            child: showHidden ? const CatalogStatusIcon.hidden() : null,
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
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (representsCollection && latestCollection != null) {
      // カタログの登録状態バッジ
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
          border: Border.all(color: tierColor, width: 0.5),
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

    if (isFolder) {
      // 通常フォルダバッジ
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: colorScheme.secondary.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder,
              color: colorScheme.onSecondaryContainer,
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              l10n?.libraryItemTypeFolder ?? 'Folder',
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // 通常ファイルバッジ (拡張子)
    final ext = FileSizeUtils.getExtension(item.path);
    final extLabel = ext.isNotEmpty
        ? ext
        : (l10n?.libraryItemTypeFile ?? 'File');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        extLabel,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTags(BuildContext context, List<Tag> tags) {
    return CompactTagPreview(
      tags: tags,
      maxVisibleTags: libraryTagPreviewLimit,
      compactRemainingCount: true,
      onTagTap: null,
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
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: const EdgeInsets.all(12),
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      onPressed: () {
        ref.read(feedbackServiceProvider).lightImpact();
        _showActionSheet(context, representsCollection, latestCollection);
      },
    );
  }

  void _showActionSheet(
    BuildContext context,
    bool representsCollection,
    MediaCollection? latestCollection,
  ) {
    showAppBottomSheet(
      context,
      showCloseButton: true,
      child: representsCollection
          ? CollectionActionSheet(
              collectionPath: item.path,
              initialTitle: latestCollection?.title ?? p.basename(item.path),
              item: item,
            )
          : FileActionSheet(item: item),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    WidgetRef ref,
    bool representsCollection,
  ) {
    final collection = item.collection.value;
    // シークレットサムネモードの確認
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );
    if (useSecretMode) {
      return _buildPlaceholder(
        context,
        representsCollection: representsCollection,
      );
    }

    // カタログの場合はコレクションのカバー画像を確認
    if (representsCollection) {
      final coverPath = collection?.coverImagePath;
      if (coverPath != null) {
        return _buildImageFile(
          context,
          ref,
          coverPath,
          representsCollection: true,
        );
      }
      // コレクションのカバー画像が設定されていない場合は、ファイル自体の内容（サムネイル等）を表示
      return _buildImageContent(context, ref);
    }

    return _buildImageContent(context, ref);
  }

  Widget _buildImageContent(BuildContext context, WidgetRef ref) {
    if (item.thumbnailPath != null) {
      return _buildImageFile(context, ref, item.thumbnailPath!);
    }

    if (item.sourceType == MediaSourceType.externalReference &&
        item.type == MediaType.file) {
      return _buildExternalThumbnail(context, ref);
    }

    if (item.isImage) {
      return _buildLocalThumbnail(context, ref);
    }

    return _buildPlaceholder(context);
  }

  Widget _buildLocalThumbnail(BuildContext context, WidgetRef ref) {
    final asyncThumb = ref.watch(localThumbnailProvider(item));
    final thumbPath = asyncThumb.value;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      return _buildImageFile(context, ref, thumbPath);
    }
    return _buildImageFile(context, ref, item.path);
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
              filterQuality: FilterQuality.none,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: 280,
              errorBuilder: (context, error, stackTrace) {
                AppLogger.e(
                  LogTag.ui,
                  '[ImageDecodeTrace] media_item_card Image.memory decode failed itemId=${item.id} path=${item.path} thumb=${item.thumbnailPath ?? ''} bytes=${bytes.length}',
                  error,
                  stackTrace,
                );
                return _buildPlaceholder(context);
              },
            ),
          );
        }
        return _buildPlaceholder(context);
      },
      loading: () =>
          Skeletonizer(enabled: true, child: _buildPlaceholder(context)),
      error: (error, stackTrace) => _buildPlaceholder(context),
    );
  }

  Widget _buildImageFile(
    BuildContext context,
    WidgetRef ref,
    String relativePath, {
    bool representsCollection = false,
  }) {
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
        '[ImageDecodeTrace] media_item_card skip non-image thumbnail itemId=${item.id} relativePath=$relativePath file=${file.path} ext=$ext',
      );
      return _buildPlaceholder(
        context,
        representsCollection: representsCollection,
      );
    }
    return Hero(
      tag: 'media_${item.id}_${item.path}',
      child: Image.file(
        file,
        filterQuality: FilterQuality.none,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: 256,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.w(
            LogTag.ui,
            '[ImageDecodeTrace] media_item_card Image.file decode failed itemId=${item.id} relativePath=$relativePath file=${file.path} cacheWidth=256 ext=$ext',
            error,
            stackTrace,
          );
          return _buildPlaceholder(
            context,
            representsCollection: representsCollection,
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    bool representsCollection = false,
  }) {
    var iconData = Icons.insert_drive_file;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var iconColor = colorScheme.onSurfaceVariant;
    var bgColor = colorScheme.surfaceContainerHighest;
    double iconSize = 36;

    if (representsCollection) {
      iconColor = colorScheme.primary;
      bgColor = colorScheme.surfaceContainerHigh;
      iconSize = 40;
    } else if (item.type == MediaType.folder) {
      return Consumer(
        builder: (context, ref, child) {
          final asyncSummary = ref.watch(folderSummaryProvider(item.path));
          return asyncSummary.when(
            data: (summary) {
              var fIcon = Icons.folder_rounded;
              var fColor = colorScheme.primary.withValues(alpha: 0.9);
              var fBg = colorScheme.primaryContainer.withValues(alpha: 0.35);

              switch (summary.contentType) {
                case FolderContentType.deepDirectory:
                  fIcon = Icons.folder_copy_rounded;
                  fColor = colorScheme.primary;
                  fBg = colorScheme.primaryContainer.withValues(alpha: 0.45);
                  break;
                case FolderContentType.imageMedia:
                  fIcon = Icons.photo_library_outlined;
                  fColor = colorScheme.primary;
                  fBg = colorScheme.primaryContainer.withValues(alpha: 0.35);
                  break;
                case FolderContentType.videoMedia:
                  fIcon = Icons.video_library_outlined;
                  fColor = colorScheme.primary;
                  fBg = colorScheme.primaryContainer.withValues(alpha: 0.35);
                  break;
                case FolderContentType.mixedMedia:
                  fIcon = Icons.perm_media_outlined;
                  fColor = colorScheme.primary;
                  fBg = colorScheme.primaryContainer.withValues(alpha: 0.35);
                  break;
                case FolderContentType.documents:
                  fIcon = Icons.snippet_folder_outlined;
                  fColor = colorScheme.primary;
                  fBg = colorScheme.primaryContainer.withValues(alpha: 0.35);
                  break;
                case FolderContentType.empty:
                  fIcon = Icons.folder_outlined;
                  fColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
                  fBg = colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  );
                  break;
                case FolderContentType.standard:
                  fIcon = Icons.folder_rounded;
                  break;
              }

              return Container(
                color: fBg,
                child: Center(child: Icon(fIcon, color: fColor, size: 48)),
              );
            },
            loading: () => Container(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Center(
                child: Icon(
                  Icons.folder_rounded,
                  color: colorScheme.primary.withValues(alpha: 0.85),
                  size: 48,
                ),
              ),
            ),
            error: (_, _) => Container(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Center(
                child: Icon(
                  Icons.folder_rounded,
                  color: colorScheme.primary.withValues(alpha: 0.85),
                  size: 48,
                ),
              ),
            ),
          );
        },
      );
    } else if (item.isImage) {
      iconData = Icons.image;
    } else if (item.isVideo) {
      iconData = Icons.movie;
    } else if (item.isAudio) {
      iconData = Icons.audiotrack;
    } else if (item.isDocument) {
      iconData = Icons.description;
    } else if (item.isArchive) {
      iconData = Icons.folder_zip;
    }

    return Container(
      color: bgColor,
      child: Center(
        child: representsCollection
            ? CatalogizeIcon(color: iconColor, size: iconSize)
            : Icon(iconData, color: iconColor, size: iconSize),
      ),
    );
  }

  Widget _buildItemInfoText(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
    bool isFolder,
  ) {
    if (!isFolder) {
      return Text(
        FileSizeUtils.formatBytes(item.size),
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final asyncSummary = ref.watch(folderSummaryProvider(item.path));
    return asyncSummary.when(
      data: (summary) {
        String label;
        if (summary.totalCount > 0) {
          label =
              l10n?.libraryFolderSummaryCounts(
                summary.folderCount,
                summary.fileCount,
                summary.catalogCount,
              ) ??
              'Folders ${summary.folderCount}, Files ${summary.fileCount}, '
                  'Catalogs ${summary.catalogCount}';
        } else {
          label = l10n?.libraryFolderSummaryEmpty ?? 'Empty';
        }

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        );
      },
      loading: () => Text(
        l10n?.libraryItemTypeFolder ?? 'Folder',
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      error: (_, _) => Text(
        l10n?.libraryItemTypeFolder ?? 'Folder',
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
