import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/security/presentation/widgets/passcode_keypad.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';

class PasscodeScreen extends ConsumerStatefulWidget {
  const PasscodeScreen({
    super.key,
    required this.mode,
    this.title,
    this.onSuccess,
    this.allowBiometrics = true,
  });

  final PasscodeMode mode;
  final String? title;
  final VoidCallback? onSuccess;
  final bool allowBiometrics;

  @override
  ConsumerState<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends ConsumerState<PasscodeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passcodeNotifierProvider(widget.mode));
    final notifier = ref.read(passcodeNotifierProvider(widget.mode).notifier);
    final settings = ref.watch(privacySettingsNotifierProvider).value;
    final l10n = AppLocalizations.of(context)!;
    final isLockedOut = (state.lockoutRemainingSeconds ?? 0) > 0;
    final remainingAttempts =
        PasscodeNotifier.maxAttempts - state.failedAttempts;
    final instructionText = state.isTransitioning
        ? l10n.privacyPasscodeConfirmTransition
        : _getInstructionText(context, state.mode);
    final errorText = _getErrorText(l10n, state.errorType);

    // 成功時およびエラー発生時の触覚/音フィードバック
    ref.listen(passcodeNotifierProvider(widget.mode), (previous, next) {
      if (next.isSuccess && !(previous?.isSuccess ?? false)) {
        unawaited(ref.read(feedbackServiceProvider).success());
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.pop(context, true);
        }
      } else if (next.errorType != null &&
          previous?.errorType != next.errorType) {
        unawaited(ref.read(feedbackServiceProvider).error());
      }
    });

    // 生体認証の自動実行（解除モードかつ設定有効時）
    if (widget.allowBiometrics &&
        widget.mode == PasscodeMode.unlock &&
        settings?.isBiometricEnabled == true &&
        state.isSecurityStateReady &&
        state.passcode.isEmpty &&
        !state.isProcessing &&
        !state.isSuccess &&
        !isLockedOut &&
        !state.hasAutoBiometricAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        notifier.markAutoBiometricAttempted();
        await notifier.authenticateWithBiometrics(
          localizedReason: l10n.privacyAuthenticateReason,
        );
      });
    }

    return Scaffold(
      appBar: PremiumAppBar(
        titleText: widget.title ?? _getDefaultTitle(context, state.mode),
        leading: Navigator.canPop(context) ? const CloseButton() : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                  maxWidth: 480,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(instructionText),
                          child: AppText(
                            instructionText,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // パスコードの丸いインジケーター
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final inputLength = state.mode == PasscodeMode.confirm
                              ? state.confirmPasscode.length
                              : state.passcode.length;
                          final isFilled = index < inputLength;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (isLockedOut)
                        AppText(
                          l10n.privacyPasscodeLockedOut(
                            state.lockoutRemainingSeconds ?? 0,
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else if (errorText != null)
                        AppText(
                          errorText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else if ((state.mode == PasscodeMode.unlock ||
                              state.mode == PasscodeMode.verifyOld) &&
                          state.failedAttempts > 0)
                        AppText(
                          l10n.privacyPasscodeAttemptsRemaining(
                            remainingAttempts < 0 ? 0 : remainingAttempts,
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 24),
                      PasscodeKeypad(
                        onDigitPress: notifier.addDigit,
                        onDeletePress: notifier.deleteDigit,
                        enabled:
                            state.isSecurityStateReady &&
                            !state.isProcessing &&
                            !state.isTransitioning &&
                            !isLockedOut,
                        showBiometrics:
                            widget.allowBiometrics &&
                            widget.mode == PasscodeMode.unlock &&
                            settings != null &&
                            settings.isBiometricEnabled,
                        onBiometricsPress: () async {
                          await notifier.authenticateWithBiometrics(
                            localizedReason: l10n.privacyAuthenticateReason,
                          );
                        },
                      ),
                      if (state.mode == PasscodeMode.setup ||
                          state.mode == PasscodeMode.confirm) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppFormattedText(
                                  l10n.privacyPasscodeRecoveryDescription,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getDefaultTitle(BuildContext context, PasscodeMode mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case PasscodeMode.setup:
      case PasscodeMode.confirm:
        return l10n.privacyPasscodeSetup;
      case PasscodeMode.unlock:
        return l10n.privacyAppLock;
      case PasscodeMode.verifyOld:
        return l10n.privacyPasscodeVerifyOld;
    }
  }

  String _getInstructionText(BuildContext context, PasscodeMode mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case PasscodeMode.setup:
        return l10n.privacyPasscodeSetupInstruction;
      case PasscodeMode.confirm:
        return l10n.privacyPasscodeConfirmInstruction;
      case PasscodeMode.unlock:
        return l10n.privacyPasscodeUnlockInstruction;
      case PasscodeMode.verifyOld:
        return l10n.privacyPasscodeVerifyOldInstruction;
    }
  }

  String? _getErrorText(AppLocalizations l10n, PasscodeError? errorType) {
    switch (errorType) {
      case PasscodeError.mismatch:
        return l10n.privacyPasscodeMismatch;
      case PasscodeError.incorrect:
        return l10n.privacyPasscodeIncorrect;
      case PasscodeError.verifyFailed:
        return l10n.privacyPasscodeVerifyFailed;
      case PasscodeError.storageFailed:
        return l10n.privacyPasscodeStorageFailed;
      case PasscodeError.oldIncorrect:
        return l10n.privacyPasscodeOldIncorrect;
      case PasscodeError.biometricsFailed:
        return l10n.privacyBiometricFailed;
      case null:
        return null;
    }
  }
}
