import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'dart:async';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/features/library/presentation/styles/tag_styles.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/shared/widgets/text/app_text.dart';
import 'package:private_shelf/shared/widgets/text/file_name_text.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_selection_indicator.dart';
import 'package:private_shelf/features/library/presentation/widgets/catalog_status_icon.dart';

class CatalogTile extends ConsumerWidget {
  final String path;
  final String title;
  final String? alias;
  final String? coverImagePath;
  final bool isFavorite;
  final MediaTier tier;
  final MediaType? type;
  final Future<void> Function()? onTagsLoad;
  final List<dynamic>? tags;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;
  final Widget? trailing;
  final MediaItem? item;
  final bool isSimpleDisplay;

  /// 階層ツリー内で、展開矢印を持つフォルダと先頭位置を揃える。
  final bool showTreeLeadingSpacer;

  const CatalogTile({
    super.key,
    required this.path,
    required this.title,
    this.alias,
    this.coverImagePath,
    required this.isFavorite,
    required this.tier,
    this.type,
    this.onTagsLoad,
    this.tags,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.trailing,
    this.item,
    this.isSimpleDisplay = false,
    this.showTreeLeadingSpacer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 最新のコレクション情報を監視
    final latestCollection = ref.watch(
      collectionNotifierProvider(path).select((s) => s.value),
    );
    final effectiveFavorite = latestCollection?.isFavorite ?? isFavorite;
    final effectiveTitle = latestCollection?.title ?? title;
    final effectiveAlias = latestCollection?.alias ?? alias;
    final isItemHidden =
        (item?.isHidden ?? false) || (latestCollection?.isHidden ?? false);

    final surfaceColor = isSelected
        ? colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;

    return Opacity(
      opacity: isItemHidden ? 0.6 : 1.0,
      child: Animate(
        effects: const [
          FadeEffect(duration: Duration(milliseconds: 300)),
          MoveEffect(
            begin: Offset(0, 10),
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        ],
        child: Material(
          color: surfaceColor,
          child: InkWell(
            enableFeedback: false,
            onTap: () {
              unawaited(ref.read(feedbackServiceProvider).lightImpact());
              onTap?.call();
            },
            onLongPress: () {
              unawaited(ref.read(feedbackServiceProvider).mediumImpact());
              onLongPress?.call();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: isSimpleDisplay ? 4 : 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTreeLeadingSpacer) const SizedBox(width: 22),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThumbnailWithStatusOverlay(
                        context,
                        ref,
                        latestCollection?.coverImagePath ?? coverImagePath,
                        latestCollection,
                        isItemHidden,
                        effectiveFavorite,
                      ),
                      if (latestCollection != null &&
                          latestCollection.isCatalog)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _buildBadge(context, latestCollection),
                        ),
                      if (item?.sourceType ==
                              MediaSourceType.externalReference ||
                          latestCollection?.type ==
                              CollectionType.externalFolder)
                        _buildExternalStatusIcon(context),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1行目: ファイル名（タイトル）
                        if (_isFile(latestCollection))
                          FileNameText(
                            effectiveTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        else
                          AppText(
                            effectiveTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_isFile(latestCollection))
                          _buildFileInfoAction(context, effectiveTitle),
                        // 表紙の横にはエイリアスを表示する。
                        _buildTypeAndAliasRow(context, effectiveAlias),
                        // 3行目 & 4行目: タグ / 更新日時
                        _buildBottomInfo(context, ref, latestCollection, tier),
                      ],
                    ),
                  ),
                  trailing ??
                      (isSelectionMode
                          ? LibrarySelectionIndicator(
                              isSelected: isSelected,
                              onPressed: () => onTap?.call(),
                            )
                          : IconButton(
                              tooltip: AppLocalizations.of(context)!.commonMenu,
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {
                                final latestCollection = ref
                                    .read(collectionNotifierProvider(path))
                                    .value;
                                final isCatalogCollection =
                                    latestCollection?.isCatalog == true;
                                final title =
                                    latestCollection?.title ?? effectiveTitle;
                                showAppBottomSheet(
                                  context,
                                  title: title,
                                  child:
                                      (isCatalogCollection ||
                                          type == MediaType.folder)
                                      ? CollectionActionSheet(
                                          collectionPath: path,
                                          initialTitle: title,
                                          item: item,
                                        )
                                      : (item != null
                                            ? FileActionSheet(item: item!)
                                            : const SizedBox.shrink()),
                                );
                              },
                            )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailWithStatusOverlay(
    BuildContext context,
    WidgetRef ref,
    String? coverPath,
    MediaCollection? latestCollection,
    bool isItemHidden,
    bool effectiveFavorite,
  ) {
    final isPinned = latestCollection?.isPinned ?? false;
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _buildThumbnail(context, ref, coverPath, latestCollection),
          if (isPinned || effectiveFavorite || isItemHidden)
            Positioned(
              top: 3,
              left: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPinned) const CatalogStatusIcon.pin(size: 17),
                  if (isPinned && (effectiveFavorite || isItemHidden))
                    const SizedBox(width: 2),
                  if (effectiveFavorite)
                    const CatalogStatusIcon.favorite(size: 17),
                  if (effectiveFavorite && isItemHidden)
                    const SizedBox(width: 2),
                  if (isItemHidden) const CatalogStatusIcon.hidden(size: 17),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExternalStatusIcon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Icon(
        Icons.link,
        size: 11,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTypeAndAliasRow(BuildContext context, String? effectiveAlias) {
    final hasAlias =
        !isSimpleDisplay && effectiveAlias != null && effectiveAlias.isNotEmpty;

    if (!hasAlias) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
      child: Row(
        children: [
          if (hasAlias)
            Expanded(
              child: AppText(
                effectiveAlias,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  bool _isFile(MediaCollection? collection) =>
      (type ?? item?.type) == MediaType.file ||
      collection?.type == CollectionType.file;

  ({IconData icon, String label}) _filePresentation(AppLocalizations l10n) {
    final filePath = item?.path ?? path;
    final mimeType = item?.mimeType;
    final originalPath = item?.originalPath;
    if (MediaFormatUtils.isImage(
      filePath,
      mimeType: mimeType,
      originalPath: originalPath,
    )) {
      return (icon: Icons.image, label: l10n.importFilterImages);
    }
    if (MediaFormatUtils.isVideo(
      filePath,
      mimeType: mimeType,
      originalPath: originalPath,
    )) {
      return (icon: Icons.movie, label: l10n.importFilterVideos);
    }
    if (MediaFormatUtils.isAudio(
      filePath,
      mimeType: mimeType,
      originalPath: originalPath,
    )) {
      return (icon: Icons.audiotrack, label: l10n.importFilterAudio);
    }
    if (MediaFormatUtils.isDocument(
          filePath,
          mimeType: mimeType,
          originalPath: originalPath,
        ) ||
        MediaFormatUtils.isText(
          filePath,
          mimeType: mimeType,
          originalPath: originalPath,
        )) {
      return (icon: Icons.description, label: l10n.importFilterDocs);
    }
    if (MediaFormatUtils.isArchive(filePath, originalPath: originalPath)) {
      return (icon: Icons.folder_zip, label: l10n.libraryDisplayTypeFile);
    }
    return (icon: Icons.insert_drive_file, label: l10n.libraryDisplayTypeFile);
  }

  String _fileTypeLabel(AppLocalizations l10n) {
    final presentation = _filePresentation(l10n);
    final extension = MediaFormatUtils.resolveExtension(
      item?.path ?? path,
      originalPath: item?.originalPath,
    );
    return extension.isEmpty
        ? presentation.label
        : '${presentation.label} · ${extension.substring(1).toUpperCase()}';
  }

  Widget _buildFileInfoAction(BuildContext context, String fullTitle) {
    final l10n = AppLocalizations.of(context)!;
    final label = _fileTypeLabel(l10n);
    return TextButton.icon(
      key: ValueKey('catalog-file-info-$path'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.centerLeft,
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      onPressed: isSelectionMode
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.viewerShowInfo),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(fullTitle),
                      if (p.basename(item?.path ?? path) != fullTitle) ...[
                        const SizedBox(height: 12),
                        SelectableText(p.basename(item?.path ?? path)),
                      ],
                      const SizedBox(height: 12),
                      Text(label),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.commonClose),
                  ),
                ],
              ),
            ),
      icon: const Icon(Icons.info_outline, size: 16),
      label: Text(label, semanticsLabel: '${l10n.viewerShowInfo}: $label'),
    );
  }

  Widget _buildBadge(BuildContext context, MediaCollection? latestCollection) {
    if (latestCollection == null || latestCollection.isCatalog != true) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
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
        border: Border.all(color: tierColor.withValues(alpha: 0.9), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogizeIcon(color: badgeForeground, size: 10),
          const SizedBox(width: 2.5),
          Text(
            AppLocalizations.of(context)!.libraryDisplayTypeCatalog,
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

  Widget _buildThumbnail(
    BuildContext context,
    WidgetRef ref,
    String? coverPath,
    MediaCollection? latestCollection,
  ) {
    // シークレットサムネモードの確認
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );
    final fallbackIconData = _getPlaceholderIconData(context, latestCollection);
    final fallbackIconColor = _getPlaceholderIconColor(
      context,
      latestCollection,
    );

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: useSecretMode == true
          ? Icon(
              fallbackIconData,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            )
          : (coverPath != null
                ? _buildRelativeImage(
                    ref,
                    coverPath,
                    fallbackIconData,
                    fallbackIconColor,
                  )
                : Icon(fallbackIconData, color: fallbackIconColor, size: 32)),
    );
  }

  Widget _buildRelativeImage(
    WidgetRef ref,
    String coverPath,
    IconData fallbackIconData,
    Color fallbackIconColor,
  ) {
    if (coverPath.isEmpty) {
      return Icon(fallbackIconData, color: fallbackIconColor, size: 32);
    }
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, coverPath));
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
      AppLogger.d(
        LogTag.ui,
        '[ImageDecodeTrace] catalog_tile skip non-image cover path=$path coverPath=$coverPath file=${file.path} ext=$ext',
      );
      return Icon(fallbackIconData, color: fallbackIconColor, size: 32);
    }
    if (!file.existsSync()) {
      AppLogger.d(
        LogTag.ui,
        '[ImageDecodeTrace] catalog_tile cover file not found path=$path coverPath=$coverPath file=${file.path}',
      );
      return Icon(fallbackIconData, color: fallbackIconColor, size: 32);
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: 256,
      errorBuilder: (context, error, stackTrace) {
        AppLogger.e(
          LogTag.ui,
          '[ImageDecodeTrace] catalog_tile Image.file decode failed path=$path coverPath=$coverPath file=${file.path} cacheWidth=256 ext=$ext',
          error,
          stackTrace,
        );
        return Icon(fallbackIconData, color: fallbackIconColor, size: 32);
      },
    );
  }

  IconData _getPlaceholderIconData(
    BuildContext context,
    MediaCollection? latestCollection,
  ) {
    if (_isFile(latestCollection)) {
      // The type uses the original file, never its optional image cover.
      return _filePresentation(AppLocalizations.of(context)!).icon;
    }
    if (latestCollection != null && latestCollection.isCatalog) {
      return Icons.auto_stories;
    }
    return Icons.folder_rounded;
  }

  Color _getPlaceholderIconColor(
    BuildContext context,
    MediaCollection? latestCollection,
  ) {
    if (latestCollection != null && latestCollection.isCatalog) {
      return Theme.of(context).colorScheme.primary;
    }
    if (type == MediaType.file) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildBottomInfo(
    BuildContext context,
    WidgetRef ref,
    MediaCollection? latestCollection,
    MediaTier tier,
  ) {
    if (latestCollection == null) return _buildDate(context, null);

    if (isSimpleDisplay) return _buildDate(context, latestCollection);

    final secretModeAsync = ref.watch(secretModeProvider);
    final tagsList = latestCollection.tags.toList();

    // タグがまだロードされていない場合はロードを試みる（CatalogTile内での簡略化）
    if (!latestCollection.tags.isLoaded) {
      latestCollection.tags.load().then((_) {
        // 再描画を促す（実際にはProvider経由が望ましいが、既存ロジックに合わせる）
      });
    }

    if (secretModeAsync.isLoading) {
      if (tagsList.isEmpty) return _buildDate(context, latestCollection);
      final visibleTags = tagsList.take(libraryTagPreviewLimit).toList();
      final remaining = tagsList.length - visibleTags.length;
      return _buildTagLayout(context, latestCollection, visibleTags, remaining);
    }

    final isSecretMode = secretModeAsync.value ?? false;
    final filteredTags = isSecretMode
        ? tagsList
        : tagsList.where((t) => !t.isHidden).toList();

    if (filteredTags.isEmpty) {
      return _buildDate(context, latestCollection);
    }
    final visibleTags = filteredTags.take(libraryTagPreviewLimit).toList();
    final remaining = filteredTags.length - visibleTags.length;

    return _buildTagLayout(context, latestCollection, visibleTags, remaining);
  }

  Widget _buildTagLayout(
    BuildContext context,
    MediaCollection? latestCollection,
    List<Tag> visibleTags,
    int remaining,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTagWrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            ...visibleTags.map((tag) => _buildTagChip(context, tag)),
            if (remaining > 0) _buildRemainingChip(context, remaining),
          ],
        ),
        const SizedBox(height: 2),
        _buildDate(context, latestCollection),
      ],
    );
  }

  Widget _buildTagChip(BuildContext context, Tag tag) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncFacets = ref.watch(tagFacetListViewModelProvider);
        final facets = asyncFacets.value ?? [];
        final facet = facets.firstWhere(
          (f) => f.id == tag.facetId,
          orElse: () => TagFacet()..name = 'Unknown',
        );

        final color = tag.getEffectiveColor(
          context,
          facet.id != Isar.autoIncrement ? facet : null,
        );

        return AppTag(
          label: tag.name,
          size: AppTagSize.small,
          color: color,
          isDimmed: tag.isHidden,
        );
      },
    );
  }

  Widget _buildRemainingChip(BuildContext context, int remaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: AppText(
        '+$remaining',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDate(BuildContext context, MediaCollection? latestCollection) {
    if (latestCollection == null) return const SizedBox.shrink();
    final dateStr = DateTimeUtils.formatCompactDate(
      context,
      latestCollection.updatedAt,
    );
    final isExternal =
        item?.sourceType == MediaSourceType.externalReference ||
        latestCollection.type == CollectionType.externalFolder;

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExternal) ...[
            Icon(
              Icons.link,
              color: Theme.of(context).colorScheme.primary,
              size: 12,
            ),
            const SizedBox(width: 3),
          ],
          AppText(
            dateStr,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
