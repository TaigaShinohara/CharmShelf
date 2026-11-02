import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/snackbar_service.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/logger/log_tag.dart';
import '../../../core/router/app_router.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/accessibility/semantic_wrapper.dart';
import '../../../shared/widgets/settings/settings_section.dart';
import '../../../shared/widgets/settings/settings_switch_tile.dart';
import '../../../shared/widgets/settings/settings_tile.dart';
import '../../../shared/widgets/widgets.dart';
import '../../security/presentation/providers/security_repository_provider.dart';
import '../../security/presentation/providers/passcode_provider.dart';
import '../../security/presentation/utils/security_action_guard.dart';
import '../domain/models/privacy_settings.dart';
import 'providers/privacy_settings_provider.dart';

class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final privacySettingsAsync = ref.watch(privacySettingsNotifierProvider);
    final settings =
        privacySettingsAsync.value ?? const PrivacySettings();
    final hasPasscode = ref.watch(hasPasscodeProvider).value ?? false;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final snackBar = ref.read(snackBarServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(titleText: l10n.privacyTitle, inlineTitle: true),
          SliverList(
            delegate: SliverChildListDelegate([
              SettingsSection(
                title: l10n.settingsSecurity,
                icon: Icons.lock_outline,
                children: [
                  // アプリロック
                  SettingsSwitchTile(
                    icon: Icons.lock,
                    title: l10n.privacyAppLock,
                    value: settings.isAppLockEnabled,
                    onInfoTap: () => _showAppLockInfo(context, l10n),
                    onChanged: (v) async {
                      if (v) {
                        final understood = await showConfirmDialog(
                          context,
                          title: l10n.privacyPasscodeRecoveryTitle,
                          message: l10n.privacyPasscodeRecoveryDescription,
                          confirmLabel: l10n.privacyPasscodeSetupAction,
                          cancelLabel: l10n.commonCancel,
                        );
                        if (!understood || !context.mounted) return;
                        // ONにする場合 -> パスコード設定へ
                        final success = await PasscodeRoute(
                          $extra: PasscodeRouteArgs(
                            mode: PasscodeMode.setup,
                            onSuccess: () {
                              GoRouter.of(context).pop(true);
                            },
                          ),
                        ).push<bool>(context);
                        if (success == true) {
                          final saved = await ref
                              .read(privacySettingsNotifierProvider.notifier)
                              .enableAppLock();
                          if (!saved) {
                            await ref
                                .read(securityRepositoryProvider)
                                .deletePasscode();
                          }
                          if (context.mounted && saved) {
                            snackBar.success(
                              context: context,
                              message: l10n.privacyPasscodeSetSuccess,
                            );
                          } else if (context.mounted) {
                            snackBar.error(
                              context: context,
                              message: l10n.commonErrorOccurred,
                            );
                          }
                        }
                      } else {
                        // OFFにする場合 -> パスコード入力で確認
                        final success = await PasscodeRoute(
                          $extra: PasscodeRouteArgs(
                            mode: PasscodeMode.unlock,
                            title: l10n.privacyAuthenticateToUnlock,
                            allowBiometrics: false,
                            onSuccess: () {
                              GoRouter.of(context).pop(true);
                            },
                          ),
                        ).push<bool>(context);
                        if (success == true) {
                          final disabled = await ref
                              .read(privacySettingsNotifierProvider.notifier)
                              .disableAppLock();
                          if (context.mounted) {
                            if (disabled) {
                              snackBar.success(
                                context: context,
                                message: l10n.privacyBiometricDisabledSuccess,
                              );
                            } else {
                              snackBar.error(
                                context: context,
                                message: l10n.commonErrorOccurred,
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                  if (settings.isAppLockEnabled) ...[
                    SettingsTile(
                      icon: Icons.password,
                      title: l10n.privacyPasscodeChange,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () async {
                        final success = await PasscodeRoute(
                          $extra: PasscodeRouteArgs(
                            mode: PasscodeMode.verifyOld,
                            allowBiometrics: false,
                            onSuccess: () {
                              GoRouter.of(context).pop(true);
                            },
                          ),
                        ).push<bool>(context);
                        if (success == true && context.mounted) {
                          snackBar.success(
                            context: context,
                            message: l10n.privacyPasscodeChangedSuccess,
                          );
                        }
                      },
                    ),
                    SettingsTile(
                      icon: Icons.timer_outlined,
                      title: l10n.privacyReLock,
                      value: _getAutoLockTimeoutLabel(
                        l10n,
                        settings.autoLockTimeout,
                      ),
                      onTap: () => _showAutoLockTimeoutPicker(
                        context,
                        ref,
                        settings.autoLockTimeout,
                      ),
                    ),
                  ],

                  // 生体認証
                  if (!(settings.isAppLockEnabled && hasPasscode))
                    SettingsTile(
                      icon: Icons.fingerprint,
                      title: l10n.privacyBiometrics,
                      subtitle: l10n.privacyPasscodeRequiredForBiometric,
                      onInfoTap: () => _showBiometricsInfo(context, l10n),
                      trailing: IgnorePointer(
                        child: Switch(
                          value: settings.isBiometricEnabled,
                          onChanged: null,
                        ),
                      ),
                      onTap: () {
                        snackBar.warning(
                          context: context,
                          message: l10n.privacyPasscodeRequiredForBiometric,
                        );
                      },
                    )
                  else
                    SettingsSwitchTile(
                      icon: Icons.fingerprint,
                      title: l10n.privacyBiometrics,
                      subtitle: l10n.privacyBiometricsSubtitle,
                      value: settings.isBiometricEnabled,
                      enabled: true,
                      onInfoTap: () => _showBiometricsInfo(context, l10n),
                      onChanged: (v) async {
                        AppLogger.d(LogTag.auth, '生体認証スイッチ切り替え: $v');

                        // 生体情報を削除・ロックされた端末でも無効化できるよう、
                        // OFF は生体認証ではなくアプリ固有PINで本人確認する。
                        if (!v) {
                          final confirmed = await PasscodeRoute(
                            $extra: PasscodeRouteArgs(
                              mode: PasscodeMode.unlock,
                              title: l10n.privacyAuthenticateToUnlock,
                              allowBiometrics: false,
                              onSuccess: () => GoRouter.of(context).pop(true),
                            ),
                          ).push<bool>(context);
                          if (confirmed != true) return;

                          final settingSaved = await ref
                              .read(privacySettingsNotifierProvider.notifier)
                              .toggleBiometric(false);
                          if (context.mounted && settingSaved) {
                            snackBar.success(
                              context: context,
                              message: l10n.privacyBiometricDisabledSuccess,
                            );
                          } else if (context.mounted) {
                            snackBar.error(
                              context: context,
                              message: l10n.commonErrorOccurred,
                            );
                          }
                          return;
                        }

                        // ONにする場合だけ、登録済み生体情報を確認する。
                        final canCheckResult = await ref
                            .read(securityRepositoryProvider)
                            .canCheckBiometrics();
                        final canCheck = canCheckResult.when(
                          success: (v) => v,
                          failure: (e) {
                            AppLogger.e(LogTag.auth, '生体認証対応確認失敗', e);
                            return false;
                          },
                        );

                        if (!canCheck) {
                          AppLogger.w(LogTag.auth, 'デバイスが生体認証非対応');
                          if (context.mounted) {
                            snackBar.warning(
                              context: context,
                              message: l10n.privacyBiometricUnavailable,
                            );
                          }
                          return;
                        }

                        final hasPasscodeResult = await ref
                            .read(securityRepositoryProvider)
                            .hasPasscode();
                        final exists = hasPasscodeResult.when(
                          success: (v) => v,
                          failure: (e) {
                            AppLogger.e(LogTag.auth, 'パスコード設定確認失敗', e);
                            return false;
                          },
                        );

                        if (!exists) {
                          AppLogger.w(LogTag.auth, 'パスコード未設定のため中断');
                          if (context.mounted) {
                            snackBar.warning(
                              context: context,
                              message: l10n.privacyPasscodeRequiredForBiometric,
                            );
                          }
                          return;
                        }

                        // 実際に生体認証を実行して、登録を確認する。
                        AppLogger.d(LogTag.auth, '生体認証ダイアログ呼び出し');
                        final authResult = await ref
                            .read(securityRepositoryProvider)
                            .authenticateWithBiometrics(
                              localizedReason: l10n.privacyAuthenticateReason,
                            );

                        final success = authResult.when(
                          success: (v) {
                            AppLogger.d(LogTag.auth, '生体認証結果: $v');
                            return v;
                          },
                          failure: (e) {
                            AppLogger.e(LogTag.auth, '生体認証実行エラー', e);
                            if (context.mounted) {
                              snackBar.error(
                                context: context,
                                message: l10n.privacyBiometricFailed,
                              );
                            }
                            return false;
                          },
                        );

                        if (!success) {
                          AppLogger.i(LogTag.auth, '生体認証未成功（キャンセル等）のため中断');
                          return;
                        }

                        // 設定を更新
                        AppLogger.i(LogTag.auth, '生体認証設定を更新: $v');
                        final settingSaved = await ref
                            .read(privacySettingsNotifierProvider.notifier)
                            .toggleBiometric(v);

                        if (context.mounted && settingSaved) {
                          snackBar.success(
                            context: context,
                            message: v
                                ? l10n.privacyBiometricEnabledSuccess
                                : l10n.privacyBiometricDisabledSuccess,
                          );
                        } else if (context.mounted) {
                          snackBar.error(
                            context: context,
                            message: l10n.commonErrorOccurred,
                          );
                        }
                      },
                    ),
                ],
              ),
              SettingsSection(
                title: l10n.privacyDisplayProtectionSection,
                icon: Icons.visibility_off_outlined,
                children: [
                  // マルチタスク隠し
                  SettingsSwitchTile(
                    icon: Icons.visibility_off,
                    title: l10n.privacyHideContentInMultitasking,
                    value: settings.hideContentInMultitasking,
                    onInfoTap: () => _showMultitaskingInfo(
                      context,
                      l10n,
                      isAndroid: isAndroid,
                    ),
                    onChanged: (v) async {
                      final success = await ref
                          .read(privacySettingsNotifierProvider.notifier)
                          .toggleHideContentInMultitasking(v);
                      if (!success && context.mounted) {
                        snackBar.error(
                          context: context,
                          message: l10n.commonErrorOccurred,
                        );
                      }
                    },
                  ),
                  // シークレットサムネモード
                  SettingsSwitchTile(
                    icon: Icons.hide_image,
                    title: l10n.privacySecretThumbnailMode,
                    value: settings.useSecretThumbnailMode,
                    onInfoTap: () => _showSecretThumbnailInfo(context, l10n),
                    onChanged: (v) => ref
                        .read(privacySettingsNotifierProvider.notifier)
                        .toggleSecretThumbnailMode(v),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  void _showAppLockInfo(BuildContext context, AppLocalizations l10n) {
    _showFeatureInfoDialog(
      context: context,
      icon: Icons.lock_outline,
      title: l10n.privacyAppLockInfoDialogTitle,
      intro: l10n.privacyAppLockInfoIntro,
      featureIcon: Icons.password,
      featureTitle: l10n.privacyAppLockInfoFeatureTitle,
      featureBody: l10n.privacyAppLockInfoFeatureBody,
      note: l10n.privacyAppLockInfoNote,
      isWarning: true,
    );
  }

  void _showBiometricsInfo(BuildContext context, AppLocalizations l10n) {
    _showFeatureInfoDialog(
      context: context,
      icon: Icons.fingerprint,
      title: l10n.privacyBiometricsInfoDialogTitle,
      intro: l10n.privacyBiometricsInfoIntro,
      featureIcon: Icons.touch_app_outlined,
      featureTitle: l10n.privacyBiometricsInfoFeatureTitle,
      featureBody: l10n.privacyBiometricsInfoFeatureBody,
      note: l10n.privacyBiometricsInfoNote,
      isWarning: false,
    );
  }

  void _showMultitaskingInfo(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isAndroid,
  }) {
    _showFeatureInfoDialog(
      context: context,
      icon: Icons.visibility_off_outlined,
      title: l10n.privacyMultitaskingInfoDialogTitle,
      intro: l10n.privacyMultitaskingInfoIntro,
      featureIcon: Icons.screenshot_outlined,
      featureTitle: isAndroid
          ? l10n.privacyMultitaskingInfoFeatureAndroidTitle
          : l10n.privacyMultitaskingInfoFeatureIosTitle,
      featureBody: isAndroid
          ? l10n.privacyMultitaskingInfoFeatureAndroidBody
          : l10n.privacyMultitaskingInfoFeatureIosBody,
      note: l10n.privacyMultitaskingInfoNote,
      isWarning: false,
    );
  }

  void _showSecretThumbnailInfo(BuildContext context, AppLocalizations l10n) {
    _showFeatureInfoDialog(
      context: context,
      icon: Icons.hide_image_outlined,
      title: l10n.privacySecretThumbnailInfoDialogTitle,
      intro: l10n.privacySecretThumbnailInfoIntro,
      featureIcon: Icons.remove_red_eye_outlined,
      featureTitle: l10n.privacySecretThumbnailInfoFeatureTitle,
      featureBody: l10n.privacySecretThumbnailInfoFeatureBody,
      note: l10n.privacySecretThumbnailInfoNote,
      isWarning: false,
    );
  }

  void _showFeatureInfoDialog({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String intro,
    required IconData featureIcon,
    required String featureTitle,
    required String featureBody,
    String? note,
    bool isWarning = false,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
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
              Text(
                intro,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
              _FeaturePoint(
                icon: featureIcon,
                title: featureTitle,
                description: featureBody,
              ),
              if (note != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? theme.colorScheme.errorContainer.withValues(
                            alpha: 0.5,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: isWarning
                        ? Border.all(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isWarning ? Icons.error_outline : Icons.info_outline,
                        size: 22,
                        color: isWarning
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isWarning
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isWarning
                                ? FontWeight.bold
                                : FontWeight.normal,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  String _getAutoLockTimeoutLabel(
    AppLocalizations l10n,
    AutoLockTimeout timeout,
  ) {
    switch (timeout) {
      case AutoLockTimeout.immediately:
        return l10n.privacyReLockImmediately;
      case AutoLockTimeout.oneMinute:
        return l10n.privacyReLock1Min;
      case AutoLockTimeout.fiveMinutes:
        return l10n.privacyReLock5Min;
      case AutoLockTimeout.tenMinutes:
        return l10n.privacyReLock10Min;
      case AutoLockTimeout.thirtyMinutes:
        return l10n.privacyReLock30Min;
      case AutoLockTimeout.never:
        return l10n.privacyReLockNever;
    }
  }

  Future<void> _showAutoLockTimeoutPicker(
    BuildContext context,
    WidgetRef ref,
    AutoLockTimeout current,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.privacyReLock),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AutoLockTimeout.values.map((timeout) {
              final isSelected = timeout == current;
              final label = _getAutoLockTimeoutLabel(l10n, timeout);
              return _DialogOptionTile(
                title: label,
                selected: isSelected,
                onTap: () async {
                  final weakensProtection = timeout.index > current.index;
                  if (weakensProtection &&
                      !await SecurityActionGuard.requireAuth(
                        dialogContext,
                        ref,
                        title: l10n.privacyReLock,
                      )) {
                    return;
                  }
                  await ref
                      .read(privacySettingsNotifierProvider.notifier)
                      .setAutoLockTimeout(timeout);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogOptionTile extends StatelessWidget {
  const _DialogOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SemanticWrapper(
      isButton: true,
      label: title,
      value: selected ? l10n.commonSelectedLabel(title) : null,
      hint: selected ? null : l10n.commonDoubleTapToSelect(title),
      onTap: onTap,
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
        onTap: onTap,
      ),
    );
  }
}
