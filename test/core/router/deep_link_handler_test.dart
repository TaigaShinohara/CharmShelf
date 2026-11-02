import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/router/deep_link_handler.dart';

void main() {
  group('DeepLinkHandler.toLocation', () {
    test('対応リンクをルーターの正規パスへ変換する', () {
      final cases = <String, String>{
        'charmshelf://library': '/',
        'charmshelf:///library': '/',
        'charmshelf://home': '/home',
        'charmshelf://settings': '/settings',
        'charmshelf://privacy': '/privacy',
        'charmshelf://info': '/info',
        'charmshelf://archive': '/archive',
        'charmshelf://trash': '/trash',
        'charmshelf://tags': '/tags',
      };

      for (final MapEntry(key: raw, value: expected) in cases.entries) {
        expect(DeepLinkHandler.toLocation(Uri.parse(raw)), expected);
      }
    });

    test('未定義・入れ子・パラメータ付きリンクを拒否する', () {
      for (final raw in [
        'https://settings',
        'charmshelf://unknown',
        'charmshelf://settings/extra',
        'charmshelf://settings?redirect=home',
        'charmshelf://settings#fragment',
        'charmshelf://viewer',
        'charmshelf:///passcode?mode=setup',
        'charmshelf://passcode',
        'charmshelf://%70asscode',
      ]) {
        expect(DeepLinkHandler.toLocation(Uri.parse(raw)), isNull, reason: raw);
      }
    });
  });

  test('タブ対象はライブラリ・ホーム・現在タブ維持を区別する', () {
    expect(DeepLinkHandler.tabTargetFor('/'), DeepLinkTabTarget.library);
    expect(DeepLinkHandler.tabTargetFor('/home'), DeepLinkTabTarget.home);
    expect(
      DeepLinkHandler.tabTargetFor('/settings'),
      DeepLinkTabTarget.preserve,
    );
    expect(
      DeepLinkHandler.tabTargetFor('/privacy'),
      DeepLinkTabTarget.preserve,
    );
  });
}
