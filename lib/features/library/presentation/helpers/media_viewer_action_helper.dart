import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/dialogs/media_thumbnail_preview_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/file_action_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

/// メディアビューア画面のアクション・ダイアログ操作をカプセル化するヘルパー
class MediaViewerActionHelper {
  const MediaViewerActionHelper._();

  /// カタログ/コレクション判定
  static MediaCollection? resolveWorkCollectionForItem(
    MediaItem item, {
    MediaCollection? linkedCollection,
    MediaCollection? directCollection,
  }) {
    final linked = linkedCollection ?? item.collection.value;
    if (_isCatalogCollection(linked, item.path)) {
      return linked;
    }
    if (_isCatalogCollection(directCollection, item.path)) {
      return directCollection;
    }
    return null;
  }

  static bool _isCatalogCollection(
    MediaCollection? collection,
    String itemPath,
  ) {
    return collection != null &&
        collection.path == itemPath &&
        collection.isCatalog;
  }

  /// アクションシート（コレクションまたは個別ファイル）を表示
  static void showViewerActions(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) {
    final hasParentPath =
        item.parentPath != null && item.parentPath!.isNotEmpty;
    final linkedCollection = item.collection.value;
    final directCollection = ref
        .read(collectionNotifierProvider(item.path))
        .asData
        ?.value;
    final latestCollection = resolveWorkCollectionForItem(
      item,
      linkedCollection: linkedCollection,
      directCollection: directCollection,
    );

    final collectionPath = latestCollection?.path;
    showAppBottomSheet(
      context,
      showCloseButton: true,
      child: collectionPath != null
          ? CollectionActionSheet(
              collectionPath: collectionPath,
              initialTitle: latestCollection?.title ?? p.basename(item.path),
              item: item,
              showSelectAction: false,
            )
          : FileActionSheet(
              item: item,
              showSelectAction: false,
              onSetAsFolderCover: hasParentPath
                  ? () async => setAsFolderCover(context, ref, item)
                  : null,
            ),
    );
  }

  /// フォルダカバーに設定
  static Future<void> setAsFolderCover(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    try {
      await ref
          .read(mediaViewerViewModelProvider.notifier)
          .setAsFolderCover(item);
      if (context.mounted) {
        snackBar.success(
          context: context,
          message: l10n.viewerSetAsFolderCoverSuccess,
        );
      }
    } catch (e) {
      if (context.mounted) {
        snackBar.error(
          context: context,
          message: userSafeErrorMessage(e, l10n),
        );
      }
    }
  }

  /// 動画サムネイル設定ダイアログの表示
  static Future<void> showThumbnailOptions(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    if (!item.isVideo) return;
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);

    final playerNotifier = ref.read(playerNotifierProvider.notifier);
    final playerState = ref.read(playerNotifierProvider);
    final vpc = playerState.chewieController?.videoPlayerController;
    if (vpc == null) {
      snackBar.error(
        context: context,
        message: l10n.viewerError(l10n.commonNotAvailable),
      );
      return;
    }

    await playerNotifier.pause();

    final positionMs = vpc.value.position.inMilliseconds;

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          MediaThumbnailPreviewDialog(item: item, positionMs: positionMs),
    );

    if (confirmed == true && context.mounted) {
      snackBar.success(context: context, message: l10n.viewerThumbnailUpdated);
    }
  }
}
