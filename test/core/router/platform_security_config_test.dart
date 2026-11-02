import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter標準ディープリンク処理を両OSで無効化している', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      android,
      contains(
        'android:name="flutter_deeplinking_enabled" android:value="false"',
      ),
    );
    expect(
      RegExp(
        r'<key>FlutterDeepLinkingEnabled</key>\s*<false\s*/>',
      ).hasMatch(ios),
      isTrue,
    );
  });

  test('iOS Documentsのファイル共有を無効化している', () {
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    for (final key in const [
      'UIFileSharingEnabled',
      'LSSupportsOpeningDocumentsInPlace',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<false\\s*/>').hasMatch(ios),
        isTrue,
        reason: key,
      );
    }
  });
}
