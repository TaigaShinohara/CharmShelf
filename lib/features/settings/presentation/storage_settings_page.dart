import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/user_safe_error_message.dart';
import '../../../core/feedback/snackbar_service.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../library/domain/models/sync_progress.dart';
import '../../library/presentation/providers/folder_sync_provider.dart';
import '../../library/presentation/providers/sync_progress_provider.dart';
import '../../permission/data/repositories/permission_repository_impl.dart';
import 'widgets/sections/settings_storage_section.dart';

/// 保存場所、再スキャン、復元などのストレージ操作をまとめた画面。
class StorageSettingsPage extends ConsumerWidget {
  const StorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final folderSyncProgress = ref.watch(folderSyncNotifierProvider);
    final libraryOperationProgress = ref.watch(syncProgressNotifierProvider);
    final isSyncing =
        folderSyncProgress.status == SyncStatus.processing ||
        folderSyncProgress.status == SyncStatus.scanning ||
        libraryOperationProgress.status == SyncStatus.processing ||
        libraryOperationProgress.status == SyncStatus.scanning ||
        libraryOperationProgress.status == SyncStatus.cancelling;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(
            titleText: l10n.settingsStorageSection,
            inlineTitle: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              SettingsStorageSection(
                isSyncing: isSyncing,
                onSync: () => _handleSync(context, ref),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final result = await ref.read(folderSyncNotifierProvider.notifier).sync();
    if (!context.mounted) return;

    if (result.isSuccess) {
      final data = result.dataOrNull!;
      snackBar.success(
        context: context,
        message: l10n.settingsStorageSyncSuccess(
          data.added,
          data.updated,
          data.missing,
        ),
      );
      return;
    }

    final error = result.errorOrNull;
    if (error?.category == ErrorCategory.permission) {
      snackBar.warning(
        context: context,
        message: error == null
            ? l10n.settingsStorageSyncFailed
            : userSafeErrorMessage(error, l10n),
        action: SnackBarAction(
          label: l10n.settingsImportNotificationOpenSettings,
          onPressed: () async {
            await ref.read(permissionRepositoryProvider).openAppSettings();
          },
        ),
      );
      return;
    }

    snackBar.error(
      context: context,
      message: error == null
          ? l10n.settingsStorageSyncFailed
          : userSafeErrorMessage(error, l10n),
    );
  }
}
