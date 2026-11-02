import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';

void main() {
  group('PasscodeRoute & 画面復帰フロー テスト', () {
    test('通常起動の認証判定中はパスコード画面へ遷移しない', () {
      final keepSplash = shouldKeepStartupSplashVisible(
        securityGuardState: const AsyncLoading(),
        matchedLocation: '/',
      );

      expect(keepSplash, isTrue);
    });

    test('判定完了後は起動スプラッシュを保持しない', () {
      final keepSplash = shouldKeepStartupSplashVisible(
        securityGuardState: const AsyncData(false),
        matchedLocation: '/',
      );

      expect(keepSplash, isFalse);
    });

    test('認証判定の失敗時は通常起動のエラー画面に留める', () {
      final keepSplash = shouldKeepStartupSplashVisible(
        securityGuardState: AsyncError<bool>(
          StateError('read failed'),
          StackTrace.empty,
        ),
        matchedLocation: '/',
      );

      expect(keepSplash, isTrue);
    });

    test('認証判定中のディープリンクは起動スプラッシュに留めない', () {
      final keepSplash = shouldKeepStartupSplashVisible(
        securityGuardState: const AsyncLoading(),
        matchedLocation: '/settings',
      );

      expect(keepSplash, isFalse);
    });

    test('PasscodeRouteがfromパラメータを正しく保持する', () {
      const route = PasscodeRoute(from: '/viewer/42');

      expect(route.from, '/viewer/42');
    });

    test('公開URLには解除以外のセキュリティ状態を直列化しない', () {
      const route = PasscodeRoute();

      expect(route.from, isNull);
      expect(route.$extra, isNull);
    });

    test('内部設定フローもURL上は通常のpasscodeルートになる', () {
      const route = PasscodeRoute(
        $extra: PasscodeRouteArgs(mode: PasscodeMode.setup),
      );

      expect(route.from, isNull);
      expect(route.$extra?.mode, PasscodeMode.setup);
    });

    test('解除後の復帰先はアプリ内パスだけを許可する', () {
      expect(
        safePasscodeReturnLocation('/viewer/42?source=recent'),
        '/viewer/42?source=recent',
      );
      expect(safePasscodeReturnLocation('/passcode?mode=setup'), isNull);
      expect(safePasscodeReturnLocation('https://example.com'), isNull);
      expect(safePasscodeReturnLocation('//example.com/path'), isNull);
      expect(safePasscodeReturnLocation('settings'), isNull);
    });
  });
}
