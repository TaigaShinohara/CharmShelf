import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_application/secure_application.dart';

import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/security/presentation/screens/passcode_screen.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsNotifierProvider).value;
    if (settings != null && !settings.isAppLockEnabled) {
      // 万が一 SecureGate によって LockScreen がビルドされても、
      // アプリロックが無効な場合はパスコード画面を表示せず即座にアンロックを行う
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          SecureApplicationProvider.of(context)?.unlock();
        }
      });
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    // パスコード画面をロック解除モードで表示
    // SecureGate paints over the previous screen but leaves its semantics alive.
    // Remove those nodes while locked so assistive services cannot read them.
    return BlockSemantics(
      child: PasscodeScreen(
        mode: PasscodeMode.unlock,
        title: l10n.privacyLockedTitle,
        onSuccess: () {
          ref.read(feedbackServiceProvider).lightImpact();
          // 1. ウィジェットレベルのロック（SecureGate）を解除
          // authSuccess(unlock: true) を呼ぶことで locked 状態が解除される
          SecureApplicationProvider.of(context)?.authSuccess(unlock: true);

          // 2. 次のフレームでルーティングレベルのロック（GoRouter）も解除
          // 順序によるデッドロックを防ぐため、1の構築完了後に実行する
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(securityGuardProvider.notifier).unlock();
            }
          });
        },
      ),
    );
  }
}
