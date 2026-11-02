import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// アプリケーションおよび同梱リソースのカスタムライセンスを登録するサービス
class LicenseService {
  LicenseService._();

  static bool _registered = false;

  /// アプリ起動時に一度だけカスタムライセンスを [LicenseRegistry] に登録する
  static void registerCustomLicenses() {
    if (_registered) {
      return;
    }
    _registered = true;

    try {
      LicenseRegistry.addLicense(() async* {
        final entries = jsonDecode(
          await rootBundle.loadString(
            'assets/licenses/third_party_notices.json',
          ),
        ) as List<dynamic>;
        for (final entry in entries.cast<Map<String, dynamic>>()) {
          yield LicenseEntryWithLineBreaks(<String>[
            entry['package'] as String,
          ], entry['text'] as String);
        }
        yield const LicenseEntryWithLineBreaks(
          <String>[AppConfig.appName],
          '''
MIT License

Copyright (c) 2026 Private Shelf Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''',
        );
      });
      AppLogger.d(LogTag.app, 'カスタムライセンスを登録しました');
    } catch (e, st) {
      AppLogger.w(LogTag.app, 'カスタムライセンス登録に失敗しました', e, st);
    }
  }
}
