import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/models/collection_display_type_ext.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_summary_provider.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

class CollectionHeader extends ConsumerWidget {
  final MediaCollection collection;

  const CollectionHeader({super.key, required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final latestCollection =
        ref.watch(
          collectionNotifierProvider(
            collection.path,
          ).select((s) => s.value),
        ) ??
        collection;

    final tierColor = latestCollection.mediaTier.color(context);
    final hasTier = latestCollection.mediaTier != MediaTier.none;
    final isCatalog = latestCollection.isCatalog;

    final displayName = latestCollection.alias?.isNotEmpty == true
        ? latestCollection.alias!
        : latestCollection.title;
    final subName = latestCollection.alias?.isNotEmpty == true
        ? latestCollection.title
        : null;
    final displayTypeLabel = latestCollection.displayTypeLabel(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: isCatalog
            ? colorScheme.primaryContainer.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCatalog
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTier)
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: tierColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(11),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildThumbnail(
                          context,
                          ref,
                          latestCollection,
                          isCatalog,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      displayTypeLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9.5,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayName,
                                softWrap: true,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                              if (subName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    subName,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.normal,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.libraryMoreActions,
                          icon: const Icon(Icons.more_vert, size: 20),
                          onPressed: () =>
                              _showActionSheet(context, ref, latestCollection),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    WidgetRef ref,
    MediaCollection latestCollection,
    bool isCatalog,
  ) {
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );
    final width = isCatalog ? 42.0 : 42.0;
    final height = isCatalog ? 52.0 : 42.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isCatalog
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isCatalog ? 7 : 6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: useSecretMode
                ? _buildPlaceholderIcon(context, latestCollection, isCatalog)
                : _buildImageContent(context, ref, latestCollection, isCatalog),
          ),
          // アイコンバッジ群 (左上)
          Positioned(
            top: 2,
            left: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (latestCollection.type == CollectionType.externalFolder)
                  Container(
                    margin: const EdgeInsets.only(right: 2),
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 7,
                    ),
                  ),
                if (latestCollection.isCatalog)
                  Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const CatalogizeIcon(color: Colors.white, size: 10),
                  ),
              ],
            ),
          ),
          // お気に入り/ピン留めアイコン
          Stack(
            children: [
              if (latestCollection.isFavorite)
                Positioned(
                  bottom: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).colorScheme.error,
                      size: 8,
                    ),
                  ),
                ),
              if (latestCollection.isPinned)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.scrim.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.push_pin,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    WidgetRef ref,
    MediaCollection latestCollection,
    bool isCatalog,
  ) {
    final coverPath = latestCollection.coverImagePath;
    final summary = ref
        .watch(folderSummaryProvider(latestCollection.path))
        .value;
    final fallbackPath = summary?.firstThumbnailPath ?? summary?.firstImagePath;

    final resolvedPath = (coverPath != null && coverPath.isNotEmpty)
        ? coverPath
        : fallbackPath;

    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      final docsPath = ref.watch(appDocumentsPathSyncProvider);
      File? targetFile;

      if (p.isAbsolute(resolvedPath)) {
        final directFile = File(resolvedPath);
        if (directFile.existsSync()) {
          targetFile = directFile;
        }
      } else {
        final directFile = File(resolvedPath);
        if (directFile.existsSync()) {
          targetFile = directFile;
        } else {
          final joinedFile = File(p.join(docsPath, resolvedPath));
          if (joinedFile.existsSync()) {
            targetFile = joinedFile;
          }
        }
      }

      if (targetFile != null && targetFile.existsSync()) {
        final ext = p.extension(targetFile.path).toLowerCase();
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
          '.avif',
        }.contains(ext);

        if (isImageExt) {
          return Image.file(
            targetFile,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 256,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.w(
                LogTag.ui,
                '[ImageDecodeTrace] collection_header image decode failed path=${targetFile?.path}',
                error,
                stackTrace,
              );
              return _buildPlaceholderIcon(
                context,
                latestCollection,
                isCatalog,
              );
            },
          );
        }
      }
    }

    return _buildPlaceholderIcon(context, latestCollection, isCatalog);
  }

  Widget _buildPlaceholderIcon(
    BuildContext context,
    MediaCollection latestCollection,
    bool isCatalog,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isCatalog
        ? colorScheme.primary
        : (latestCollection.type == CollectionType.file
              ? colorScheme.secondary
              : colorScheme.onSurfaceVariant);

    return Icon(
      _getCollectionIcon(latestCollection),
      color: iconColor,
      size: 20,
    );
  }

  IconData _getCollectionIcon(MediaCollection latestCollection) {
    switch (latestCollection.type) {
      case CollectionType.folder:
        if (latestCollection.isCatalog) {
          return Icons.auto_stories;
        }
        return Icons.folder;
      case CollectionType.file:
        return Icons.auto_awesome_motion;
      case CollectionType.externalFolder:
        if (latestCollection.isCatalog) {
          return Icons.auto_stories;
        }
        return Icons.folder;
    }
  }

  void _showActionSheet(
    BuildContext context,
    WidgetRef ref,
    MediaCollection targetCollection,
  ) async {
    await ref.read(feedbackServiceProvider).lightImpact();
    if (!context.mounted) return;

    final repository = await ref.read(mediaRepositoryProvider.future);
    final itemResult = await repository.getByPath(targetCollection.path);
    if (!context.mounted) return;

    showAppBottomSheet(
      context,
      showCloseButton: true,
      child: CollectionActionSheet(
        collectionPath: targetCollection.path,
        initialTitle: targetCollection.alias?.isNotEmpty == true
            ? targetCollection.alias!
            : targetCollection.title,
        item: itemResult.dataOrNull,
        showOpenContentsAction: false,
      ),
    );
  }
}
