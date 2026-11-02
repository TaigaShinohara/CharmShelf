import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';

/// 機密データや画面へのアクセス時にパスコード・生体認証を要求するユーティリティ
class SecurityActionGuard {
  SecurityActionGuard._();

  /// アプリロックが有効かつパスコードが設定されている場合、認証画面を表示して認証を要求する
  ///
  /// - ロックが無効またはパスコード未設定の場合は即座に `true` を返します。
  /// - 認証に成功した場合は `true`、キャンセルまたは失敗した場合は `false` を返します。
  static Future<bool> requireAuth(
    BuildContext context,
    WidgetRef ref, {
    String? title,
  }) async {
    try {
      final settings = await ref.read(privacySettingsNotifierProvider.future);
      if (!settings.isAppLockEnabled) {
        return true;
      }

      final hasPasscodeResult = await ref
          .read(securityRepositoryProvider)
          .hasPasscode();
      if (hasPasscodeResult.isFailure) {
        AppLogger.e(
          LogTag.auth,
          'パスコード設定状態を確認できないため機密操作を拒否',
          hasPasscodeResult.errorOrNull,
        );
        return false;
      }
      final hasPasscode = hasPasscodeResult.dataOrNull ?? false;
      if (!hasPasscode) {
        return true;
      }

      if (!context.mounted) return false;

      final result = await PasscodeRoute(
        $extra: PasscodeRouteArgs(
          mode: PasscodeMode.unlock,
          title: title,
          onSuccess: () {
            GoRouter.of(context).pop(true);
          },
        ),
      ).push<bool>(context);

      return result == true;
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュリティ認証ガード判定でエラー発生', e, st);
      // エラー時は安全側に倒し、ロック有効とみなして認証画面を試みるか、falseを返す
      return false;
    }
  }
}
