import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/features/home/presentation/providers/archived_collections_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/application/use_cases/archive_media_item_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/catalog_tile.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final archivedAsync = ref.watch(archivedCollectionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(titleText: l10n.archiveTitle, inlineTitle: true),
          archivedAsync.when(
            data: (collections) {
              if (collections.isEmpty) {
                return SliverEmptyStateWidget(
                  icon: Icons.archive_outlined,
                  title: l10n.homeArchivedEmpty,
                  action: FilledButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.libraryTitle),
                    onPressed: () {
                      ref.read(currentTabIndexProvider.notifier).goToLibrary();
                      Navigator.of(context).maybePop();
                    },
                  ),
                );
              }

              return SliverPadding(
                padding: AppSpacing.edgeInsetsSm,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final collection = collections[index];
                    return CatalogTile(
                      path: collection.path,
                      title: collection.title,
                      alias: collection.alias,
                      isFavorite: collection.isFavorite,
                      tier: collection.mediaTier,
                      isSimpleDisplay: ref.watch(globalSimpleDisplayProvider),
                      trailing: IconButton(
                        icon: const Icon(Icons.unarchive_outlined),
                        tooltip: l10n.commonUnarchive,
                        onPressed: () =>
                            _handleUnarchive(context, ref, collection),
                      ),
                      onTap: () {
                        showAppBottomSheet<void>(
                          context,
                          child: CollectionActionSheet(
                            collectionPath: collection.path,
                            initialTitle: collection.title,
                            showSelectAction: false,
                          ),
                        );
                      },
                    );
                  }, childCount: collections.length),
                ),
              );
            },
            error: (error, stack) {
              AppLogger.e(LogTag.ui, 'アーカイブ一覧の表示に失敗', error, stack);
              final appError = error is AppError
                  ? error
                  : AppError.ui(
                      l10n.commonErrorOccurred,
                      original: error,
                      stackTrace: stack,
                      context: 'ArchiveScreen.build',
                    );
              return SliverErrorStateWidget(
                error: appError,
                onRetry: () => ref.invalidate(archivedCollectionsProvider),
              );
            },
            loading: () => const SliverLoadingWidget(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnarchive(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.commonUnarchive,
      message: l10n.libraryUnarchiveConfirmMessage(collection.title),
      confirmLabel: l10n.commonUnarchive,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final useCase = await ref.read(archiveMediaItemUseCaseProvider.future);
      final result = await useCase.call(
        collection: collection,
        isArchived: false,
      );

      if (!context.mounted) return;

      if (result.isSuccess) {
        ref.invalidate(archivedCollectionsProvider);
        ref.invalidate(collectionNotifierProvider(collection.path));
        snackBar.success(
          context: context,
          message: l10n.commonUnarchiveSuccess,
        );
      } else {
        final error = result.errorOrNull;
        snackBar.error(
          context: context,
          message: error == null
              ? l10n.commonErrorOccurred
              : userSafeErrorMessage(error, l10n),
        );
      }
    } catch (e, st) {
      AppLogger.e(LogTag.ui, 'アーカイブ解除処理に失敗', e, st);
      if (context.mounted) {
        snackBar.error(context: context, message: l10n.commonErrorOccurred);
      }
    }
  }
}
