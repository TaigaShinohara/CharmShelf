import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/text/app_text.dart';
import 'package:private_shelf/shared/widgets/cards/app_card.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// 最近見たアイテム専用のメディアカード
/// タグや日付を表示せず、シンプルに構成する
class RecentMediaCard extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final double height;

  const RecentMediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.width = 140,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final latestCollection = ref
        .watch(collectionNotifierProvider(item.path))
        .value;
    final representsCollection =
        latestCollection != null && latestCollection.isCatalog;

    final title = representsCollection
        ? latestCollection.title
        : p.basename(item.path);

    return Semantics(
      key: ValueKey('recent-media-card-${item.id}'),
      container: true,
      button: onTap != null,
      hint: onTap == null ? null : l10n.commonDoubleTapToActivate,
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
        child: Animate(
          effects: const [
            FadeEffect(duration: Duration(milliseconds: 300)),
            ScaleEffect(
              begin: Offset(0.95, 0.95),
              end: Offset(1.0, 1.0),
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          ],
          child: Builder(
            builder: (context) {
              final tierInt = latestCollection?.tier ?? 0;
              final tier = MediaTier.fromInt(tierInt);
              final tierColor = tier.color(context);

              final isItemHidden =
                  item.isHidden || (latestCollection?.isHidden ?? false);
              return Opacity(
                opacity: isItemHidden ? 0.6 : 1.0,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppCardElevation.bordered,
                  border: BorderSide(color: tierColor, width: 2.0),
                  borderRadius: 24.0,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.0),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildThumbnail(
                                      context,
                                      ref,
                                      representsCollection,
                                    ),
                                    // 状態アイコン (右上)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isItemHidden)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: theme.appColors.overlay
                                                    .withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimary
                                                      .withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme
                                                        .appColors
                                                        .shadow
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.visibility_off,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                size: 14,
                                              ),
                                            ),
                                          if (item.isFavorite ||
                                              latestCollection?.isFavorite ==
                                                  true)
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: theme.appColors.overlay
                                                    .withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimary
                                                      .withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme
                                                        .appColors
                                                        .shadow
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.favorite,
                                                color: theme.colorScheme.error,
                                                size: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // タイトルエリア
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  top: 8.0,
                                  bottom: 8.0,
                                  right: 32.0,
                                ),
                                child: AppText(
                                  title,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // メニューボタン
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: l10n.libraryMoreActions,
                              icon: const Icon(Icons.more_vert),
                              iconSize: 20,
                              padding: const EdgeInsets.all(14),
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              color: theme.colorScheme.onSurfaceVariant,
                              onPressed: () {
                                ref.read(feedbackServiceProvider).lightImpact();
                                final menuTitle =
                                    latestCollection?.alias?.isNotEmpty == true
                                    ? latestCollection!.alias!
                                    : latestCollection?.title ??
                                          p.basename(item.path);
                                showAppBottomSheet(
                                  context,
                                  showCloseButton: true,
                                  child: representsCollection
                                      ? CollectionActionSheet(
                                          collectionPath: item.path,
                                          initialTitle: menuTitle,
                                          item: item,
                                        )
                                      : FileActionSheet(item: item),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
    if (useSecretMode) {
      return _buildPlaceholder(context);
    }

    if (representsCollection) {
      final collectionAsync = ref.watch(collectionNotifierProvider(item.path));
      return collectionAsync.when(
        data: (collection) {
          final coverPath = collection?.coverImagePath;
          if (coverPath != null) {
            return _buildImageFile(context, ref, coverPath);
          }
          return _buildImageContent(context, ref);
        },
        loading: () =>
            Skeletonizer(enabled: true, child: _buildPlaceholder(context)),
        error: (_, _) => _buildPlaceholder(context),
      );
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
      return _buildImageFile(context, ref, item.path);
    }
    return _buildPlaceholder(context);
  }

  Widget _buildExternalThumbnail(BuildContext context, WidgetRef ref) {
    final asyncBytes = ref.watch(externalThumbnailProvider(item));
    return asyncBytes.when(
      data: (bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 200,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.e(
                LogTag.ui,
                '[ImageDecodeTrace] recent_media_card Image.memory decode failed itemId=${item.id} path=${item.path} bytes=${bytes.length}',
                error,
                stackTrace,
              );
              return _buildPlaceholder(context);
            },
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
      AppLogger.d(
        LogTag.ui,
        '[ImageDecodeTrace] recent_media_card skip non-image thumbnail itemId=${item.id} relativePath=$relativePath file=${file.path} ext=$ext',
      );
      return _buildPlaceholder(context);
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: 256,
      errorBuilder: (context, error, stackTrace) {
        AppLogger.w(
          LogTag.ui,
          '[ImageDecodeTrace] recent_media_card Image.file decode failed itemId=${item.id} relativePath=$relativePath file=${file.path} cacheWidth=256 ext=$ext',
          error,
          stackTrace,
        );
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    var iconData = Icons.insert_drive_file;
    if (item.type == MediaType.folder) {
      iconData = Icons.folder;
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          iconData,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),
    );
  }
}
