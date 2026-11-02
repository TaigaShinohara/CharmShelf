import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/shared/widgets/icon/catalogize_icon.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/text/app_text.dart';
import 'package:private_shelf/shared/widgets/cards/app_card.dart';
import '../../presentation/providers/collection_provider.dart';
import '../../../settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import '../providers/collection_cover_thumbnail_provider.dart';

class CollectionCard extends ConsumerWidget {
  final MediaCollection collection;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;

  const CollectionCard({
    super.key,
    required this.collection,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // コレクション情報を監視して最新状態を取得
    final latestCollection = ref
        .watch(collectionNotifierProvider(collection.path))
        .value;
    final effectiveCollection = latestCollection ?? collection;

    // 表示用のデータを確定
    final isFavorite = effectiveCollection.isFavorite;
    final originalName = effectiveCollection.title;
    final alias = effectiveCollection.alias;
    final tier = effectiveCollection.mediaTier;
    final displayName = alias?.isNotEmpty == true ? alias! : originalName;

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCoverImage(context, ref, effectiveCollection),
                    // 状態アイコン (右上)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (collection.isHidden == true)
                            Container(
                              margin: const EdgeInsets.only(right: 3),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: theme.appColors.overlay.withValues(
                                  alpha: 0.5,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.appColors.shadow.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.visibility_off,
                                color: theme.colorScheme.onPrimary,
                                size: 11,
                              ),
                            ),
                          if (isFavorite)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: theme.appColors.overlay.withValues(
                                  alpha: 0.5,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.appColors.shadow.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: theme.colorScheme.error,
                                size: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // コンテンツ (下部テキスト領域)
              Padding(
                padding: const EdgeInsets.only(
                  left: 6.0,
                  top: 4.0,
                  bottom: 4.0,
                  right: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      originalName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (alias != null && alias.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: AppText(
                          alias,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // カード全体のタップ領域
          Positioned.fill(
            child: Semantics(
              key: ValueKey('collection-card-primary-${collection.path}'),
              label: displayName,
              button: onTap != null,
              hint: onTap == null
                  ? null
                  : AppLocalizations.of(context)!.commonDoubleTapToActivate,
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, onLongPress: onLongPress),
              ),
            ),
          ),
          // メニューボタン
          Positioned(
            bottom: -2,
            right: -2,
            child: IconButton(
              tooltip: AppLocalizations.of(context)!.libraryMoreActions,
              icon: const Icon(Icons.more_vert),
              iconSize: 20,
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () {
                ref.read(feedbackServiceProvider).lightImpact();
                final menuTitle = alias?.isNotEmpty == true
                    ? alias!
                    : originalName;
                showAppBottomSheet(
                  context,
                  showCloseButton: true,
                  child: collection.favoriteItem != null
                      ? FileActionSheet(item: collection.favoriteItem!)
                      : CollectionActionSheet(
                          collectionPath: collection.path,
                          initialTitle: menuTitle,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (width != null || height != null) {
      cardContent = SizedBox(width: width, height: height, child: cardContent);
    }

    return Opacity(
      opacity: (collection.isHidden == true) ? 0.6 : 1.0,
      child: AppCard(
        padding: EdgeInsets.zero,
        elevation: AppCardElevation.bordered,
        border: BorderSide(color: tier.color(context), width: 1.5),
        borderRadius: 16.0,
        child: cardContent,
      ),
    );
  }

  Widget _getCollectionIcon(BuildContext context, MediaCollection coll) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    switch (coll.type) {
      case CollectionType.folder:
        return CatalogizeIcon(size: 28, color: color);
      case CollectionType.file:
        return Icon(Icons.auto_awesome_motion, color: color, size: 28);
      case CollectionType.externalFolder:
        return Icon(Icons.snippet_folder, color: color, size: 28);
    }
  }

  Widget _buildCoverImage(
    BuildContext context,
    WidgetRef ref,
    MediaCollection effectiveCollection,
  ) {
    // シークレットサムネモードの確認
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );
    if (useSecretMode) {
      return _buildPlaceholder(context, effectiveCollection, showIcon: false);
    }

    // カバー画像（coverImagePath またはフォールバックサムネイル）を解決
    final coverAsync = ref.watch(
      collectionCoverThumbnailProvider(effectiveCollection),
    );

    return coverAsync.when(
      data: (coverData) {
        if (coverData == null) {
          return _buildPlaceholder(context, effectiveCollection);
        }
        if (coverData is FileCoverData) {
          String? docsPath;
          try {
            docsPath = ref.watch(appDocumentsPathSyncProvider);
          } catch (_) {
            docsPath = null;
          }
          if (docsPath == null) {
            return _buildPlaceholder(context, effectiveCollection);
          }
          final file = File(p.join(docsPath, coverData.relativePath));
          return Image.file(
            file,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 256,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.w(
                LogTag.ui,
                '[ImageDecodeTrace] collection_card Image.file decode failed: path=${file.path}',
                error,
                stackTrace,
              );
              return _buildPlaceholder(context, effectiveCollection);
            },
          );
        }
        if (coverData is MemoryCoverData) {
          return Image.memory(
            coverData.bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 256,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.w(
                LogTag.ui,
                '[ImageDecodeTrace] collection_card Image.memory decode failed',
                error,
                stackTrace,
              );
              return _buildPlaceholder(context, effectiveCollection);
            },
          );
        }
        return _buildPlaceholder(context, effectiveCollection);
      },
      loading: () =>
          _buildPlaceholder(context, effectiveCollection, showIcon: false),
      error: (_, _) => _buildPlaceholder(context, effectiveCollection),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    MediaCollection coll, {
    bool showIcon = true,
  }) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: showIcon ? Center(child: _getCollectionIcon(context, coll)) : null,
    );
  }
}
