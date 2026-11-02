import 'package:flutter_test/flutter_test.dart';

import '../../scripts/create_app.dart' as generator;

void main() {
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
