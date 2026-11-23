import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/create_app.dart' as generator;

void main() {
  test('明示的に有効にしたときだけURLスキームを生成する', () {
    final root = Directory.systemTemp.createTempSync('charmshelf-link-config-');
    addTearDown(() => root.deleteSync(recursive: true));
    final config = File('${root.path}/template_config.yaml');

    for (final enabled in [false, true]) {
      config.writeAsStringSync(
        'features:\n  deep_link:\n    enabled: $enabled\n    scheme: custom\n',
      );
      expect(
        generator.readEnabledDeepLinkScheme(root),
        enabled ? 'custom' : null,
      );
    }
  });

  test('Info.plistの追記はネストしたdictではなくルートdictへ入る', () {
    const plist = '''
<plist>
<dict>
  <key>CFBundleURLTypes</key>
  <array>
    <dict><key>Nested</key><true/></dict>
  </array>
</dict>
</plist>
''';

    final patched = generator.insertBeforeRootPlistDictEnd(
      plist,
      '<key>SecurityFlag</key><false/>\n',
    );

    expect(
      patched,
      contains('</array>\n<key>SecurityFlag</key><false/>\n</dict>'),
    );
    expect(patched, isNot(contains('<true/><key>SecurityFlag</key>')));
  });
}
