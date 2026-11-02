import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/src/share_plus_windows.dart';
import 'package:share_plus/src/windows_version_helper.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'url_launcher_mock.dart';

void main() {
  final originalVersion = VersionHelper.instance.isWindows10RS5OrGreater;
  final originalPlatform = SharePlatform.instance;

  tearDown(() {
    VersionHelper.instance.isWindows10RS5OrGreater = originalVersion;
    SharePlatform.instance = originalPlatform;
  });

  test('share UI support begins at Windows 10 build 17763', () {
    expect(
      VersionHelper.supportsModernShare(majorVersion: 10, buildNumber: 17762),
      isFalse,
    );
    expect(
      VersionHelper.supportsModernShare(majorVersion: 10, buildNumber: 17763),
      isTrue,
    );
    expect(
      VersionHelper.supportsModernShare(majorVersion: 10, buildNumber: 22000),
      isTrue,
    );
    expect(
      VersionHelper.supportsModernShare(majorVersion: 6, buildNumber: 17763),
      isFalse,
    );
  });

  test(
    'legacy Windows registers the mailto fallback',
    () {
      VersionHelper.instance.isWindows10RS5OrGreater = false;
      SharePlusWindowsPlugin.registerWith();
      expect(SharePlatform.instance, isA<SharePlusWindowsPlugin>());
    },
  );

  test(
    'modern Windows preserves native method-channel sharing',
    () {
      VersionHelper.instance.isWindows10RS5OrGreater = true;
      final nativePlatform = MethodChannelShare();
      SharePlatform.instance = nativePlatform;
      SharePlusWindowsPlugin.registerWith();
      expect(identical(SharePlatform.instance, nativePlatform), isTrue);
    },
  );

  // Construct the fallback directly to test it on every host, including modern
  // Windows, without launching a native share UI.

  test(
    'url encoding is correct for &',
    () async {
      final mock = MockUrlLauncherPlatform();

      await SharePlusWindowsPlugin(mock).share(
        ShareParams(text: 'foo&bar', subject: 'bar&foo'),
      );

      expect(mock.url, 'mailto:?subject=bar%26foo&body=foo%26bar');
    },
  );

  // see https://github.com/dart-lang/sdk/issues/43838#issuecomment-823551891
  test(
    'url encoding is correct for spaces',
    () async {
      final mock = MockUrlLauncherPlatform();

      await SharePlusWindowsPlugin(mock).share(
        ShareParams(text: 'foo bar', subject: 'bar foo'),
      );

      expect(mock.url, 'mailto:?subject=bar%20foo&body=foo%20bar');
    },
  );

  test(
    'can share URI on Windows',
    () async {
      final mock = MockUrlLauncherPlatform();

      await SharePlusWindowsPlugin(mock).share(
        ShareParams(uri: Uri.parse('http://example.com')),
      );

      expect(mock.url, 'mailto:?body=http%3A%2F%2Fexample.com');
    },
  );

  test('mailto launch failure propagates instead of reporting a share',
      () async {
    final mock = MockUrlLauncherPlatform()..canLaunchMockValue = false;
    await expectLater(
      SharePlusWindowsPlugin(mock)
          .share(ShareParams(text: 'synthetic message')),
      throwsException,
    );
  });

  test('fallback rejects files before launching a mailto handler', () async {
    final mock = MockUrlLauncherPlatform();
    await expectLater(
      SharePlusWindowsPlugin(mock).share(
        ShareParams(files: [XFile('synthetic-file.txt')]),
      ),
      throwsA(isA<UnimplementedError>()),
    );
    expect(mock.url, isNull);
  });

  test('reads the native Windows version without opening Share UI', () {
    expect(VersionHelper.readWindowsVersionSupportsShareUI(), isTrue);
  }, skip: !Platform.isWindows);
}
