import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/settings/settings_tile.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class ImportNotificationPermissionTile extends ConsumerStatefulWidget {
  const ImportNotificationPermissionTile({super.key});

  @override
  ConsumerState<ImportNotificationPermissionTile> createState() =>
      _ImportNotificationPermissionTileState();
}

class _ImportNotificationPermissionTileState
    extends ConsumerState<ImportNotificationPermissionTile>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPermissionStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final permissionAsync = ref.watch(notificationPermissionStatusProvider);

    return SettingsTile(
      icon: Icons.notifications_outlined,
      title: l10n.settingsImportNotification,
      value: permissionAsync.when(
        data: (status) => switch (status) {
          PermissionResult.granted => l10n.settingsImportNotificationAllowed,
          PermissionResult.denied => l10n.settingsImportNotificationNotAllowed,
          PermissionResult.permanentlyDenied || PermissionResult.restricted =>
            l10n.settingsImportNotificationRestricted,
        },
        loading: () => l10n.commonLoading,
        error: (_, _) => l10n.settingsImportNotificationNotAllowed,
      ),
      valueIcon: permissionAsync.value == PermissionResult.granted
          ? Icons.check_circle
          : null,
      onTap: permissionAsync.isLoading
          ? null
          : () => _handleTap(permissionAsync.value ?? PermissionResult.denied),
    );
  }

  Future<void> _handleTap(PermissionResult status) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final requiresSettings =
        status == PermissionResult.permanentlyDenied ||
        status == PermissionResult.restricted ||
        status == PermissionResult.granted;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.settingsImportNotificationDialogTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeaturePoint(
                icon: Icons.hourglass_top_rounded,
                title: l10n.settingsImportNotificationFeatureProgressTitle,
                description: l10n.settingsImportNotificationFeatureProgressBody,
              ),
              const SizedBox(height: 12),
              _FeaturePoint(
                icon: Icons.touch_app_outlined,
                title: l10n.settingsImportNotificationFeatureResumeTitle,
                description: l10n.settingsImportNotificationFeatureResumeBody,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.settingsImportNotificationNotePrivacy,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
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
            trailing: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                requiresSettings
                    ? l10n.settingsImportNotificationOpenSettings
                    : l10n.settingsImportNotificationEnable,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = ref.read(permissionRepositoryProvider);
    if (requiresSettings) {
      final opened = await repository.openAppSettings();
      if (!mounted) return;
      if (!opened) {
        snackBar.error(
          context: context,
          message: l10n.settingsImportNotificationSettingsFailed,
        );
      }
      ref.invalidate(notificationPermissionStatusProvider);
      return;
    }

    final result = await repository.requestNotificationPermission();
    ref.invalidate(notificationPermissionStatusProvider);
    if (!mounted) return;
    if (result == PermissionResult.permanentlyDenied ||
        result == PermissionResult.restricted) {
      // Android reports permanent denial from request(), while a status read
      // returns denied. Offer settings from this result without caching it:
      // the user may later select "Ask every time" in the system settings.
      await _handleTap(result);
      return;
    }
    if (result == PermissionResult.granted) {
      snackBar.success(
        context: context,
        message: l10n.settingsImportNotificationEnabled,
      );
    } else {
      snackBar.warning(
        context: context,
        message: l10n.settingsImportNotificationDenied,
      );
    }
  }
}

class _FeaturePoint extends StatelessWidget {
  const _FeaturePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
