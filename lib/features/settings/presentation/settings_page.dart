import '../../library/presentation/providers/data_restore_provider.dart';
import 'widgets/tiles/legacy_transfer_tile.dart';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/feedback/feedback_providers.dart';
import '../../../core/feedback/snackbar_service.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/logger/log_tag.dart';
import '../../../core/providers/package_info_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/tab_navigator.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/settings/settings_section.dart';
import '../../../shared/widgets/settings/settings_switch_tile.dart';
import '../../../shared/widgets/settings/settings_tile.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tip/presentation/tip_page.dart';
import 'services/system_diagnostics_service.dart';
import 'privacy_settings_page.dart';
import 'storage_settings_page.dart';
import 'help_page.dart';
import 'info_page.dart';
import 'tutorial_list_page.dart';
import 'providers/locale_provider.dart';
import '../../library/presentation/providers/library_view_settings_provider.dart';
import 'widgets/dialogs/language_selection_dialog.dart';
import 'widgets/dialogs/theme_selection_dialog.dart';
import 'widgets/dialogs/viewer_page_direction_dialog.dart';
import 'widgets/tiles/import_notification_permission_tile.dart';
import 'widgets/tiles/charm_transfer_tiles.dart';
import 'library_backup_page.dart';

/// 設定画面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    this.canLaunchExternalUrl,
    this.launchExternalUrl,
    this.copyExternalLegalUrl,
    this.copyDiagnosticsToClipboard,
  });

  final Future<bool> Function(Uri url)? canLaunchExternalUrl;
  final Future<bool> Function(Uri url)? launchExternalUrl;
  final Future<void> Function(
    AppSnackBarMessenger? messenger,
    AppLocalizations l10n,
    String url,
  )?
  copyExternalLegalUrl;
  final Future<void> Function(String text)? copyDiagnosticsToClipboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider);
    final build = ref.watch(buildNumberProvider);
    final themeMode = ref.watch(themeModeProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final currentLocale = ref.watch(appLocaleProvider);
    final viewerPageDirection = ref.watch(viewerPageDirectionProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(titleText: l10n.settingsTitle, inlineTitle: true),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              SettingsSection(
                title: l10n.settingsAppearance,
                icon: Icons.palette_outlined,
                children: [
                  SettingsTile(
                    icon: Icons.brightness_6_outlined,
                    title: l10n.settingsTheme,
                    value: switch (themeMode) {
                      ThemeMode.system => l10n.settingsThemeSystemValue,
                      ThemeMode.light => l10n.settingsThemeLightValue,
                      ThemeMode.dark => l10n.settingsThemeDarkValue,
                    },
                    onTap: () =>
                        showThemeSelectionDialog(context, ref, themeMode),
                  ),
                  SettingsTile(
                    icon: Icons.language_outlined,
                    title: l10n.settingsLanguage,
                    value: currentLocale == null
                        ? l10n.settingsLanguageSystem
                        : (currentLocale.languageCode == 'ja'
                              ? l10n.settingsLanguageJa
                              : l10n.settingsLanguageEn),
                    onTap: () => showLanguageSelectionDialog(context, ref),
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.settingsViewerSection,
                icon: Icons.menu_book_outlined,
                children: [
                  SettingsTile(
                    icon: Icons.swap_horiz,
                    title: l10n.settingsViewerPageDirectionShort,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          viewerPageDirection == ViewerPageDirection.rightToLeft
                              ? Icons.arrow_back
                              : Icons.arrow_forward,
                          semanticLabel:
                              viewerPageDirection ==
                                  ViewerPageDirection.rightToLeft
                              ? l10n.settingsViewerPageDirectionRightToLeft
                              : l10n.settingsViewerPageDirectionLeftToRight,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                    onTap: () => showViewerPageDirectionDialog(
                      context,
                      ref,
                      viewerPageDirection,
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.settingsFeedback,
                icon: Icons.touch_app_outlined,
                children: [
                  if (FeatureFlags.enableHaptics)
                    SettingsSwitchTile(
                      icon: Icons.vibration,
                      title: l10n.settingsHaptics,
                      value: hapticsEnabled,
                      onChanged: (v) => ref
                          .read(hapticsEnabledAsyncProvider.notifier)
                          .setValue(v),
                    ),
                  const ImportNotificationPermissionTile(),
                ],
              ),
              if (FeatureFlags.enableLocalAuth)
                SettingsSection(
                  title: l10n.settingsSecurity,
                  icon: Icons.shield_outlined,
                  children: [
                    SettingsTile(
                      icon: Icons.shield_outlined,
                      title: l10n.privacyTitle,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => TabNavigator.push(
                        context,
                        const PrivacySettingsPage(),
                      ),
                    ),
                  ],
                ),
              SettingsSection(
                title: l10n.settingsDataManagementSection,
                icon: Icons.folder_outlined,
                children: [
                  SettingsTile(
                    key: const ValueKey('settings-library-backup'),
                    icon: Icons.backup_outlined,
                    title: l10n.libraryBackupTitle,
                    subtitle: l10n.libraryBackupDescription,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        TabNavigator.push(context, const LibraryBackupPage()),
                  ),
                  if (ref.watch(dataRestoreIsAndroidProvider))
                    const LegacyTransferTile(),
                  SettingsTile(
                    key: const ValueKey('settings-storage-navigation'),
                    icon: Icons.folder_outlined,
                    title: l10n.settingsStorageManagement,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        TabNavigator.push(context, const StorageSettingsPage()),
                  ),
                  const CharmImportTile(),
                  const CharmExportTile(),
                ],
              ),
              if (FeatureFlags.enableTutorial)
                SettingsSection(
                  title: l10n.settingsTutorialSection,
                  icon: Icons.school_outlined,
                  children: [
                    SettingsTile(
                      icon: Icons.lightbulb_outline,
                      title: l10n.settingsTutorialView,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () =>
                          TabNavigator.push(context, const TutorialListPage()),
                    ),
                  ],
                ),
              SettingsSection(
                title: l10n.settingsSupport,
                icon: Icons.support_agent_outlined,
                children: [
                  if (FeatureFlags.enableSupportPurchases)
                    SettingsTile(
                      icon: Icons.favorite_outline,
                      title: l10n.settingsTip,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => TabNavigator.push(context, const TipPage()),
                    ),
                  SettingsTile(
                    icon: Icons.help_outline,
                    title: l10n.settingsHelp,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => TabNavigator.push(context, const HelpPage()),
                  ),
                  SettingsTile(
                    icon: Icons.bug_report_outlined,
                    title: l10n.settingsDiagnosticsCopy,
                    subtitle: l10n.settingsDiagnosticsCopySubtitle,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onInfoTap: () => _showDiagnosticsInfo(context, l10n),
                    onTap: () => _copyDiagnostics(context, ref),
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.settingsAboutApp,
                icon: Icons.apps_outlined,
                children: [
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: l10n.settingsVersion,
                    value: '$version ($build)',
                  ),
                  SettingsTile(
                    icon: Icons.balance_outlined,
                    title: l10n.settingsLicense,
                    subtitle: l10n.settingsLicenseSubtitle,
                    semanticLabel: l10n.settingsLicenseSemanticLabel,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: l10n.appTitle,
                      applicationVersion: '$version ($build)',
                      applicationIcon: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Image.asset(
                          'assets/images/icon/icon.png',
                          width: 48,
                          height: 48,
                        ),
                      ),
                      applicationLegalese: l10n.settingsCopyright,
                      useRootNavigator: false,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.settingsPrivacyPolicy,
                    subtitle: l10n.settingsPrivacyPolicySubtitle,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => TabNavigator.push(
                      context,
                      InfoPage(
                        title: l10n.privacyPolicyTitle,
                        content: l10n.privacyPolicyCurrentContent,
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.description_outlined,
                    title: l10n.settingsTermsOfService,
                    subtitle: l10n.settingsTermsOfServiceSubtitle,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => TabNavigator.push(
                      context,
                      InfoPage(
                        title: l10n.termsOfServiceTitle,
                        content: l10n.termsOfServiceContent,
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.public,
                    title: l10n.settingsExternalLegalPage,
                    trailing: const Icon(
                      Icons.open_in_new,
                      size: AppIconSize.sm,
                    ),
                    onTap: () => _openExternalLegalPage(context, ref),
                  ),
                ],
              ),
              AppSpacing.gapVerticalXxl,
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalLegalPage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _openLegalUrl(context, ref, AppConfig.externalLegalUrl);
  }

  Future<void> _openLegalUrl(
    BuildContext context,
    WidgetRef ref,
    String rawUrl,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      snackBar.error(context: context, message: l10n.clipboardFailed);
      return;
    }

    final canLaunch =
        await (canLaunchExternalUrl ??
            ((uri) async {
              try {
                return await canLaunchUrl(uri);
              } catch (_) {
                return false;
              }
            }))(uri);

    if (canLaunch) {
      final launched =
          await (launchExternalUrl ??
              ((uri) async {
                try {
                  return await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  return false;
                }
              }))(uri);
      if (launched) return;
    }

    if (!context.mounted) return;

    if (copyExternalLegalUrl != null) {
      final messenger = AppSnackBarMessenger.maybeOf(context);
      await copyExternalLegalUrl!(messenger, l10n, uri.toString());
    } else {
      await _copyUrlToClipboard(context, snackBar, l10n, uri.toString());
    }
  }

  Future<void> _copyUrlToClipboard(
    BuildContext context,
    SnackBarService snackBar,
    AppLocalizations l10n,
    String url,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        snackBar.info(context: context, message: l10n.clipboardCopied);
      }
    } catch (_) {
      if (context.mounted) {
        snackBar.error(context: context, message: l10n.clipboardFailed);
      }
    }
  }

  Future<void> _copyDiagnostics(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final diagnostics = await ref
          .read(systemDiagnosticsServiceProvider.notifier)
          .generateReport();
      if (copyDiagnosticsToClipboard != null) {
        await copyDiagnosticsToClipboard!(diagnostics);
      } else {
        await Clipboard.setData(ClipboardData(text: diagnostics));
      }
      if (!context.mounted) return;
      ref
          .read(snackBarServiceProvider)
          .success(context: context, message: l10n.settingsDiagnosticsCopied);
    } catch (e, st) {
      AppLogger.e(LogTag.app, '診断情報のクリップボードコピーに失敗しました', e, st);
      if (!context.mounted) return;
      ref
          .read(snackBarServiceProvider)
          .error(context: context, message: l10n.settingsDiagnosticsCopyFailed);
    }
  }
}

void _showDiagnosticsInfo(BuildContext context, AppLocalizations l10n) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.settingsDiagnosticsInfoTitle),
      content: Text(l10n.settingsDiagnosticsInfoDescription),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}
