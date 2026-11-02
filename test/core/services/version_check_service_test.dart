import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('VersionPolicy.fromJson', () {
    test('有効な文字列値を保持する', () {
      final policy = VersionPolicy.fromJson({
        'minVersion': '1.2.3',
        'iosStoreUrl': 'https://apps.apple.com/app/example',
        'androidStoreUrl':
            'https://play.google.com/store/apps/details?id=example',
      });

      expect(policy.minVersion, '1.2.3');
      expect(policy.iosStoreUrl, 'https://apps.apple.com/app/example');
      expect(
        policy.androidStoreUrl,
        'https://play.google.com/store/apps/details?id=example',
      );
    });

    test('キーが欠落した場合は既定値へフォールバックする', () {
      final policy = VersionPolicy.fromJson({});

      expect(policy.minVersion, '0.0.0');
      expect(policy.iosStoreUrl, isEmpty);
      expect(policy.androidStoreUrl, isEmpty);
    });

    test('値がString以外の場合は既定値へフォールバックする', () {
      final policy = VersionPolicy.fromJson({
        'minVersion': 123,
        'iosStoreUrl': true,
        'androidStoreUrl': <String>[],
      });

      expect(policy.minVersion, '0.0.0');
      expect(policy.iosStoreUrl, isEmpty);
      expect(policy.androidStoreUrl, isEmpty);
    });
  });

  group('VersionPolicy.storeUrlForPlatform', () {
    final policy = VersionPolicy(
      minVersion: '1.2.3',
      iosStoreUrl: 'https://apps.apple.com/app/example',
      androidStoreUrl: 'https://play.google.com/store/apps/details?id=example',
    );

    void testPlatform(
      String description,
      TargetPlatform platform,
      String? expected,
    ) {
      test(description, () {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        expect(policy.storeUrlForPlatform(), expected);
      });
    }

    testPlatform('iOSではiOSストアURLを返す', TargetPlatform.iOS, policy.iosStoreUrl);
    testPlatform(
      'AndroidではAndroidストアURLを返す',
      TargetPlatform.android,
      policy.androidStoreUrl,
    );
    testPlatform('macOSではnullを返す', TargetPlatform.macOS, null);
    testPlatform('Linuxではnullを返す', TargetPlatform.linux, null);
    testPlatform('Windowsではnullを返す', TargetPlatform.windows, null);
    testPlatform('Fuchsiaではnullを返す', TargetPlatform.fuchsia, null);
  });
}
