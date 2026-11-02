import 'package:flutter_test/flutter_test.dart';

import 'package:private_shelf/gen_l10n/app_localizations_ja.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/app_error_extension.dart';

void main() {
  group('AppErrorExtension', () {
    test(
      'localizedMessage returns correct Japanese message for network error',
      () {
        final l10n = AppLocalizationsJa();
        final error = AppError.network('Network failed');
        expect(error.localizedMessage(l10n), '通信に失敗しました。接続状況をご確認ください');
      },
    );

    test(
      'localizedMessage returns correct Japanese message for database error',
      () {
        final l10n = AppLocalizationsJa();
        final error = AppError.database('DB failed');
        expect(error.localizedMessage(l10n), 'データの保存や読み込みに失敗しました');
      },
    );

    test(
      'localizedMessage returns correct Japanese message for auth error',
      () {
        final l10n = AppLocalizationsJa();
        final error = AppError.auth('Auth failed');
        expect(error.localizedMessage(l10n), '認証に失敗しました');
      },
    );
  });
}
