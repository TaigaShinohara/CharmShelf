import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/gen_l10n/app_localizations_ja.dart';

void main() {
  final l10n = AppLocalizationsJa();

  group('userSafeErrorMessage', () {
    test('AppErrorは技術メッセージではなくカテゴリ別の文言を返す', () {
      final error = AppError.file(
        '/private/path/secret.jpg could not be opened',
      );

      final message = userSafeErrorMessage(error, l10n);

      expect(message, l10n.errorFile);
      expect(message, isNot(contains('/private/path')));
    });

    test('未知例外は例外文字列を表示せず一般メッセージを返す', () {
      final error = Exception('token=secret-value');

      final message = userSafeErrorMessage(error, l10n);

      expect(message, l10n.errorUnknown);
      expect(message, isNot(contains('secret-value')));
    });

    test('nullも安全な一般メッセージへフォールバックする', () {
      expect(userSafeErrorMessage(null, l10n), l10n.errorUnknown);
    });
  });
}
