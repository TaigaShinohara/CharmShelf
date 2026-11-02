import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'security_repository_provider.dart';
import '../../../settings/presentation/providers/privacy_settings_provider.dart';

part 'security_guard_provider.g.dart';

@Riverpod(keepAlive: true)
class SecurityGuard extends _$SecurityGuard {
  @override
  Future<bool> build() async {
    // 設定変更のたびに build が走り直してロック状態にリセットされるのを防ぐため、
    // watch ではなく read を使用する。
    // ロックの要否はアプリ起動時、または明示的な lock/unlock 呼び出しで制御する。
    final hasPasscode = await ref
        .read(securityRepositoryProvider)
        .hasPasscode();
    if (hasPasscode.isFailure) {
      // Keychain / Keystore の一時障害で保護境界を迂回させない。
      return false;
    }

    final passcodeExists = hasPasscode.dataOrNull ?? false;
    if (passcodeExists) {
      // パスコードが残っている限り、設定の破損や不完全な無効化で解除しない。
      return false;
    }

    final settings = await ref.read(privacySettingsNotifierProvider.future);
    // 設定だけが有効な不整合も安全側でロックする。
    return !settings.isAppLockEnabled;
  }

  void unlock() {
    state = const AsyncValue.data(true);
  }

  void lock() {
    state = const AsyncValue.data(false);
  }
}
