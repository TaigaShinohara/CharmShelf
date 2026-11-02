import 'dart:io';
import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/tutorial_providers.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/services/clipboard_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/application/use_cases/archive_media_item_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/toggle_hidden_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/rename_item_dialog.dart';
import 'package:private_shelf/features/library/presentation/screens/move_destination_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_selector_widget.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/settings/presentation/privacy_settings_page.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/archived_collections_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/tutorial/tutorial_catalog.dart';
import 'package:private_shelf/shared/widgets/tutorial/tutorial_overlay.dart';

/// アクションシートからの各種操作（名前変更・移動・削除・共有など）を実行するコントローラー
class LibraryActionSheetController {
  final WidgetRef ref;

  const LibraryActionSheetController(this.ref);

  Future<void> openCollectionContents(
    BuildContext context,
    MediaCollection collection,
  ) async {
    Navigator.pop(context);
    final mode = collection.isExternal ? AppMode.external : AppMode.internal;
    await ref.read(appModeAsyncProvider.notifier).setMode(mode);
    ref
        .read(mediaFilterNotifierProvider(mode).notifier)
        .updateParentPath(collection.path);
    ref.read(currentTabIndexProvider.notifier).goToLibrary();
  }

  /// 複数選択モードへの切り替え
  void selectItem(BuildContext context, MediaItem item) {
    final mode = ref.read(appModeProvider);
    if (mode == AppMode.external) {
      final vm = ref.read(externalLibraryViewModelProvider.notifier);
      if (!vm.isSelectionMode) {
        vm.toggleSelectionMode();
      }
      if (!vm.selectedIds.contains(item.id)) {
        vm.toggleSelection(item.id);
      }
    } else {
      final selectionState = ref.read(librarySelectionNotifierProvider);
      final selectionNotifier = ref.read(
        librarySelectionNotifierProvider.notifier,
      );
      if (!selectionState.isSelectionMode) {
        selectionNotifier.toggleSelectionMode();
      }
      if (!selectionState.selectedIds.contains(item.id)) {
        selectionNotifier.toggleSelection(item.id);
      }
    }
    Navigator.pop(context);
  }

  /// 共有処理
  Future<void> shareItem(
    BuildContext context,
    MediaItem item, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      if (item.sourceType == MediaSourceType.localCopy) {
        final docsDir = await getPrivateStorageDirectory();
        final sharePath = p.join(docsDir.path, item.path);
        final files = [XFile(sharePath)];
        await SharePlus.instance.share(
          ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
        );
      } else {
        final files = [XFile(item.path)];
        await SharePlus.instance.share(
          ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
        );
      }
    } catch (e, st) {
      AppLogger.e(LogTag.ui, '共有処理に失敗しました: path=${item.path}', e, st);
    }
  }

  /// カタログ/コレクションの共有処理
  Future<void> shareCollection(
    BuildContext context,
    String collectionPath,
    MediaItem? item, {
    Rect? sharePositionOrigin,
  }) async {
    var itemId = item?.id;
    if (itemId == null) {
      final repo = await ref.read(mediaRepositoryProvider.future);
      final itemResult = await repo.getByPath(collectionPath);
      itemId = itemResult.dataOrNull?.id;
    }

    if (itemId != null) {
      final notifier = ref.read(libraryViewModelProvider.notifier);
      await notifier.shareItems([
        itemId,
      ], sharePositionOrigin: sharePositionOrigin);
    }
  }

  /// パスコピー
  Future<void> copyPath(BuildContext context, String path) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await ref.read(clipboardServiceProvider).copyText(path);
    if (context.mounted) {
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess ? l10n.clipboardCopied : l10n.clipboardFailed,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// フォルダ/カタログの表紙に設定
  Future<void> setAsFolderCover(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(libraryViewModelProvider.notifier).setAsFolderCover(item);
      if (context.mounted) {
        final parentCatalogAsync = ref.read(
          parentCatalogProvider(parentPath: item.parentPath),
        );
        final parentCatalog = parentCatalogAsync.value;
        final isCatalogCover = parentCatalog != null && parentCatalog.isCatalog;
        final message = isCatalogCover
            ? l10n.librarySetAsCatalogCoverSuccess
            : l10n.viewerSetAsFolderCoverSuccess;

        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 名前の変更ダイアログ
  Future<void> showRenameDialog(
    BuildContext context,
    MediaItem item, {
    String? currentCollectionPath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final vm = ref.read(libraryViewModelProvider.notifier);
    final items = ref.read(libraryViewModelProvider).value ?? [];

    final targetPath = currentCollectionPath ?? item.path;
    final isFolder = item.type == MediaType.folder;
    final currentParent = item.parentPath;
    final siblingNames = items
        .where((i) => i.parentPath == currentParent && i.id != item.id)
        .map((i) => p.basename(i.path));

    final result = await showRenameItemDialog(
      context,
      initialName: p.basename(targetPath),
      isFolder: isFolder,
      existingNames: siblingNames,
    );

    if (result == null || !context.mounted) return;
    final newName = result.trim();
    final oldName = p.basename(targetPath);
    if (newName.isEmpty || newName == oldName) return;

    try {
      await vm.renameItem(item, newName);
      if (context.mounted) {
        Navigator.pop(context); // シートを閉じる
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 移動ダイアログ
  Future<void> showMoveDialog(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final vm = ref.read(libraryViewModelProvider.notifier);

    final targetPath = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => MoveDestinationScreen(
          movingItemPaths: {item.path},
          currentParentPath: item.parentPath,
        ),
      ),
    );

    if (targetPath != null && context.mounted) {
      final normalizedNew = targetPath.isEmpty ? '' : p.normalize(targetPath);
      final normalizedOld =
          (item.parentPath == null || item.parentPath!.isEmpty)
          ? ''
          : p.normalize(item.parentPath!);

      if (normalizedNew == normalizedOld) return;

      final originalParent = item.parentPath;
      final originalId = item.id;

      try {
        await vm.moveItem(item, targetPath.isEmpty ? null : targetPath);
        if (context.mounted) {
          Navigator.pop(context); // シートを閉じる
          final messenger = AppSnackBarMessenger.of(context);
          final currentMode = ref.read(appModeProvider);
          ref
              .read(mediaFilterNotifierProvider(currentMode).notifier)
              .updateParentPath(targetPath);

          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.settingsFileMoveSuccess),
              action: SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  try {
                    final currentItems =
                        ref.read(libraryViewModelProvider).value ?? [];
                    final itemToRollback = currentItems.firstWhere(
                      (i) => i.id == originalId,
                      orElse: () => item,
                    );
                    await vm.moveItem(itemToRollback, originalParent);
                  } catch (e, st) {
                    AppLogger.e(LogTag.ui, '移動の取り消し(Undo)に失敗', e, st);
                  }
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(e, l10n)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// 複製処理
  Future<void> handleDuplicate(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(libraryViewModelProvider.notifier);

    final newParentPath = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => MoveDestinationScreen(
          movingItemPaths: {item.path},
          currentParentPath: item.parentPath,
          isCopy: true,
        ),
      ),
    );

    if (newParentPath != null && context.mounted) {
      try {
        await notifier.duplicateItem(item, targetParentPath: newParentPath);
        if (context.mounted) {
          Navigator.pop(context); // シートを閉じる
          final currentMode = ref.read(appModeProvider);
          ref
              .read(mediaFilterNotifierProvider(currentMode).notifier)
              .updateParentPath(newParentPath);
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.settingsFileActionDuplicateSuccess),
              action: SnackBarAction(
                label: l10n.settingsFileActionShow,
                onPressed: () {
                  AppSnackBarMessenger.of(context).hideCurrentSnackBar();
                  final mode = ref.read(appModeProvider);
                  ref
                      .read(mediaFilterNotifierProvider(mode).notifier)
                      .updateParentPath(newParentPath);
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(e, l10n)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// ダウンロード処理
  Future<void> downloadItem(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showDownloadConfirmDialog(context, l10n);
    if (!confirmed || !context.mounted) return;

    final notifier = ref.read(libraryViewModelProvider.notifier);
    try {
      await notifier.downloadItems([item.id]);
      if (context.mounted) {
        final destination = _getDownloadDestinationText(l10n);
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.libraryDownloadSuccessWithDestination(destination),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _shouldShowTutorial(String tutorialId) async {
    try {
      return !await ref
          .read(tutorialStateProvider.notifier)
          .isCompleted(tutorialId);
    } catch (error, stack) {
      // The action has already succeeded. Skip the guide without marking it read.
      AppLogger.e(LogTag.ui, 'チュートリアルの既読状態を読み込めませんでした', error, stack);
      return false;
    }
  }

  /// 非表示のトグル
  Future<void> toggleHidden(
    BuildContext context, {
    MediaItem? item,
    MediaCollection? collection,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isHidden = item != null
        ? !item.isHidden
        : !(collection?.isHidden ?? false);

    if (isHidden) {
      final proceed = await _confirmHideWithoutAppLock(context, l10n);
      if (!proceed || !context.mounted) return;
    }

    try {
      final useCase = await ref.read(toggleHiddenUseCaseProvider.future);
      final result = await useCase.call(
        item: item,
        collection: collection,
        isHidden: isHidden,
      );

      if (result is Success && context.mounted) {
        if (collection != null) {
          ref.invalidate(collectionNotifierProvider(collection.path));
        } else if (item != null && item.parentPath != null) {
          ref.invalidate(collectionNotifierProvider(item.parentPath!));
        }

        final showTutorial =
            isHidden && await _shouldShowTutorial('first_hide');

        if (context.mounted && isHidden && showTutorial) {
          final securityRepo = ref.read(securityRepositoryProvider);
          final hasPasscodeResult = await securityRepo.hasPasscode();
          final hasPasscode = hasPasscodeResult.dataOrNull ?? false;

          if (context.mounted) {
            await TutorialOverlay.show(
              context,
              ref: ref,
              tutorialId: TutorialIds.firstHide,
              steps: hideTutorialSteps(l10n, hasPasscode: hasPasscode),
            );
          }
        }

        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isHidden
                    ? l10n.settingsFileActionHideSuccess
                    : l10n.settingsFileActionShowSuccess,
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );

          // 非表示にした対象は現在の一覧から消えるため、操作元の
          // アクションシートも閉じる。非表示解除時は続けて操作できるよう残す。
          if (isHidden) {
            Navigator.of(context).pop();
          }
        }
      } else if (result is Failure && context.mounted) {
        final error = (result as Failure).error;
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(error, l10n)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 非表示は一覧から外すだけなので、アプリロックが無いときは先に確認する。
  Future<bool> _confirmHideWithoutAppLock(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    var lockEnabled = false;
    try {
      final settings = await ref.read(privacySettingsNotifierProvider.future);
      lockEnabled = settings.isAppLockEnabled;
    } catch (error, stack) {
      AppLogger.w(LogTag.ui, '非表示前のアプリロック確認に失敗したため、確認を表示します', error, stack);
    }
    if (lockEnabled || !context.mounted) return lockEnabled;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.libraryHideNeedsLockTitle),
        content: Text(l10n.libraryHideNeedsLockMessage),
        actions: [
          DialogActionRow(
            leading: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('hide'),
              child: Text(l10n.libraryHideNeedsLockContinue),
            ),
            trailing: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('lock'),
              child: Text(l10n.libraryHideNeedsLockSet),
            ),
          ),
        ],
      ),
    );
    if (choice == 'lock' && context.mounted) {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(builder: (_) => const PrivacySettingsPage()),
      );
    }
    return choice == 'hide';
  }

  /// アーカイブのトグル
  Future<void> toggleArchive(
    BuildContext context, {
    MediaItem? item,
    MediaCollection? collection,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isArchived = item != null
        ? !item.isArchived
        : !(collection?.isArchived ?? false);

    try {
      final useCase = await ref.read(archiveMediaItemUseCaseProvider.future);
      final result = await useCase.call(
        item: item,
        collection: collection,
        isArchived: isArchived,
      );

      if (result is Success && context.mounted) {
        ref.invalidate(archivedCollectionsProvider);
        if (collection != null) {
          ref.invalidate(collectionNotifierProvider(collection.path));
        } else if (item != null && item.parentPath != null) {
          ref.invalidate(collectionNotifierProvider(item.parentPath!));
        }

        final showTutorial =
            isArchived && await _shouldShowTutorial('first_archive');

        if (context.mounted && isArchived && showTutorial) {
          final securityRepo = ref.read(securityRepositoryProvider);
          final hasPasscodeResult = await securityRepo.hasPasscode();
          final hasPasscode = hasPasscodeResult.dataOrNull ?? false;

          if (context.mounted) {
            await TutorialOverlay.show(
              context,
              ref: ref,
              tutorialId: TutorialIds.firstArchive,
              steps: archiveTutorialSteps(l10n, hasPasscode: hasPasscode),
            );
          }
        }

        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArchived
                    ? l10n.settingsFileActionArchiveSuccess
                    : l10n.settingsFileActionUnarchiveSuccess,
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );

          // アーカイブした対象は通常の一覧から消えるため、操作元の
          // アクションシートも閉じる。アーカイブ解除時は残す。
          if (isArchived) {
            Navigator.of(context).pop();
          }
        }
      } else if (result is Failure && context.mounted) {
        final error = (result as Failure).error;
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(error, l10n)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// お気に入りのトグル
  Future<void> toggleFavorite(
    BuildContext context,
    String collectionPath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(collectionNotifierProvider(collectionPath).notifier)
          .toggleFavorite();
      if (context.mounted) {
        final isNowFavorite =
            ref
                .read(collectionNotifierProvider(collectionPath))
                .value
                ?.isFavorite ??
            false;
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNowFavorite
                  ? l10n.settingsCollectionFavorite
                  : l10n.settingsCollectionUnfavorite,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// カタログ化されていないファイル／フォルダのお気に入りをトグルする。
  Future<void> toggleItemFavorite(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final repository = await ref.read(mediaRepositoryProvider.future);
      final current = (await repository.getById(item.id)).dataOrNull ?? item;
      current.isFavorite = !current.isFavorite;
      current.updatedAt = DateTime.now();
      final result = await repository.save(current);
      if (result.isFailure) throw result.errorOrNull!;

      ref.invalidate(mediaItemProvider(current.id));
      ref.invalidate(libraryViewModelProvider);
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              current.isFavorite
                  ? l10n.settingsCollectionFavorite
                  : l10n.settingsCollectionUnfavorite,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userSafeErrorMessage(e, l10n))));
      }
    }
  }

  /// ピン留めのトグル
  Future<void> togglePin(BuildContext context, String collectionPath) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final wasPinned =
          ref
              .read(collectionNotifierProvider(collectionPath))
              .value
              ?.isPinned ??
          false;
      await ref
          .read(collectionNotifierProvider(collectionPath).notifier)
          .togglePin();
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasPinned ? l10n.libraryUnpinSuccess : l10n.libraryPinSuccess,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// カタログ化の実行
  Future<void> catalogify(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showCatalogifyConfirmDialog(context, l10n, item);
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(collectionNotifierProvider(item.path).notifier)
          .catalogify();
      if (context.mounted) {
        Navigator.pop(context);
        showAppBottomSheet(
          context,
          showCloseButton: true,
          child: CollectionActionSheet(
            collectionPath: item.path,
            initialTitle: p.basename(item.path),
            item: item,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userSafeErrorMessage(e, l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// カタログ解除 / 参照解除
  Future<void> decatalogify(
    BuildContext context,
    MediaCollection collection,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isExternal = collection.type == CollectionType.externalFolder;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isExternal
              ? l10n.settingsFileRemoveReferenceTitle
              : l10n.settingsCollectionDecatalogifyConfirmTitle,
        ),
        content: Text(
          isExternal
              ? l10n.settingsFileRemoveReferenceMessage
              : l10n.settingsCollectionDecatalogifyConfirmMessage,
        ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                isExternal
                    ? l10n.settingsFileActionRemoveReference
                    : l10n.settingsCollectionDecatalogify,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = AppSnackBarMessenger.of(context);
      try {
        var permissionCleanupPending = false;
        if (isExternal) {
          final outcome = await ref
              .read(externalFolderListProvider.notifier)
              .removeFolder(collection);
          permissionCleanupPending = outcome.permissionCleanupPending;
          final filter = ref.read(
            mediaFilterNotifierProvider(AppMode.external),
          );
          if (filter.parentPath == collection.path) {
            ref
                .read(mediaFilterNotifierProvider(AppMode.external).notifier)
                .updateParentPath(null);
          }
          ref.invalidate(externalLibraryViewModelProvider);
          ref.invalidate(libraryViewModelProvider);
        } else {
          await ref
              .read(collectionNotifierProvider(collection.path).notifier)
              .decatalogify();
        }
        if (context.mounted) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                isExternal
                    ? permissionCleanupPending
                          ? l10n.settingsFileRemoveReferenceCleanupPending
                          : l10n.settingsFileRemoveReferenceSuccess
                    : l10n.settingsCollectionDecatalogifySuccess,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e, st) {
        AppLogger.e(
          LogTag.provider,
          'カタログ解除に失敗しました: path=${collection.path}',
          e,
          st,
        );
        if (context.mounted) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(e, l10n)),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// 削除処理
  Future<void> deleteItem(BuildContext context, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final isExternal = item.sourceType == MediaSourceType.externalReference;

    final collection = ref
        .read(collectionNotifierProvider(item.path))
        .value;
    final isCatalog = collection != null && collection.isCatalog;

    final itemName = p.basename(item.path);
    final targetText = isCatalog
        ? l10n.libraryTrashDeleteTargetCatalog(itemName)
        : item.type == MediaType.folder
        ? l10n.libraryTrashDeleteTargetFolder(itemName)
        : l10n.libraryTrashDeleteTargetFile(itemName);
    final targetType = isCatalog
        ? l10n.libraryBrowseCatalogs
        : item.type == MediaType.folder
        ? l10n.commonFolder
        : l10n.commonFile;
    final Widget targetIcon = isCatalog
        ? const CatalogizeIcon.outlined(size: 24)
        : item.type == MediaType.folder
        ? const Icon(Icons.folder_outlined)
        : const Icon(Icons.insert_drive_file_outlined);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: Text(
          isExternal
              ? l10n.settingsFileRemoveReferenceTitle
              : l10n.settingsFileDeleteConfirmTitle,
        ),
        content: isExternal
            ? Text('${l10n.settingsFileRemoveReferenceMessage}\n\n$targetText')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const ValueKey('trash-dialog-target'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          targetIcon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    dialogContext,
                                  ).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  targetType,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          dialogContext,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.settingsFileDeleteConfirmMessage,
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                isExternal
                    ? l10n.settingsFileActionRemoveReference
                    : l10n.settingsFileDeleteConfirmTitle,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final notifier = ref.read(libraryViewModelProvider.notifier);
        await notifier.deleteItem(item);
        if (context.mounted) {
          final messenger = AppSnackBarMessenger.of(context);
          Navigator.pop(context); // シートを閉じる
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.settingsFileDeleteSuccess),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: l10n.libraryTrashRestore,
                onPressed: () async {
                  try {
                    await notifier.restoreDeletedItem(item.id);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l10n.libraryTrashRestoreSuccess),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e, st) {
                    AppLogger.e(
                      LogTag.provider,
                      '削除アイテムの復元に失敗しました: itemId=${item.id}',
                      e,
                      st,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l10n.commonErrorOccurred),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
      } catch (e, st) {
        AppLogger.e(
          LogTag.provider,
          'アイテムの削除に失敗しました: itemId=${item.id}, path=${item.path}',
          e,
          st,
        );
        if (context.mounted) {
          Navigator.pop(context);
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(e, l10n)),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// タグ編集ダイアログ
  Future<void> showTagDialog(
    BuildContext context,
    MediaCollection collection,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final itemRef = MediaItem();
    itemRef.collection.value = collection;

    final saveInProgress = ValueNotifier(false);
    await showAppBottomSheet(
      context,
      title: l10n.settingsCollectionTag,
      dismissBlocked: saveInProgress,
      useSingleChildScrollView: false,
      child: TagSelectorWidget(item: itemRef, saveInProgress: saveInProgress),
    ).whenComplete(saveInProgress.dispose);
  }

  /// Tier設定ダイアログ
  Future<void> showTierDialog(
    BuildContext context,
    String collectionPath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppBottomSheet<MediaTier>(
      context,
      title: l10n.settingsCollectionTier,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: MediaTier.values
            .map(
              (tier) => ListTile(
                leading: Icon(
                  LibraryActionIcons.rank,
                  color: tier.color(context),
                ),
                title: Text(tier.localizedLabel(context)),
                onTap: () => Navigator.pop(context, tier),
              ),
            )
            .toList(),
      ),
    );

    if (result != null && context.mounted) {
      try {
        await ref
            .read(collectionNotifierProvider(collectionPath).notifier)
            .updateTier(result);
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.settingsCollectionTier}: ${result.localizedLabel(context)}',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(e, l10n)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // --- ヘルパーダイアログ ---

  String _getDownloadDestinationText(AppLocalizations l10n) {
    if (Platform.isIOS) {
      return l10n.libraryDownloadDestinationIOS;
    } else if (Platform.isAndroid) {
      return l10n.libraryDownloadDestinationAndroid;
    } else {
      return l10n.libraryDownloadDestinationGeneric;
    }
  }

  Future<bool> _showDownloadConfirmDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final destination = _getDownloadDestinationText(l10n);
    final theme = Theme.of(context);

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceBetween,
            title: Text(l10n.libraryDownloadConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.libraryDownloadConfirmMessage),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.libraryDownloadDestinationLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              destination,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.libraryDownload),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showCatalogifyConfirmDialog(
    BuildContext context,
    AppLocalizations l10n,
    MediaItem item,
  ) async {
    final targetLabel = item.type == MediaType.folder
        ? l10n.commonFolder
        : l10n.commonFile;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.settingsCollectionCatalogifyConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsCollectionCatalogifyConfirmMessageWithTarget(
                    targetLabel,
                  ),
                ),
              ],
            ),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const CatalogizeIcon.outlined(size: 18),
                  label: Text(l10n.settingsCollectionCatalogify),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
