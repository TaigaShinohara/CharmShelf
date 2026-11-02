import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final script = File('scripts/check_l10n_consistency.dart').absolute.path;
  final packages = File('.dart_tool/package_config.json').absolute.path;
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('l10n-consistency-test-');
    for (final locale in ['ja', 'en']) {
      final source = Directory(p.join(fixture.path, 'lib', 'l10n_src', locale));
      source.createSync(recursive: true);
      File(p.join(source.path, 'common.arb')).writeAsStringSync('{}');
    }
    Directory(p.join(fixture.path, 'lib', 'l10n')).createSync();
  });

  tearDown(() => fixture.deleteSync(recursive: true));

  void writeMerged(String locale, Map<String, String> messages) {
    File(
      p.join(fixture.path, 'lib', 'l10n', 'app_$locale.arb'),
    ).writeAsStringSync(jsonEncode(messages));
  }

  Future<ProcessResult> runCheck() => Process.run(
    'dart',
    ['--packages=$packages', script],
    workingDirectory: fixture.path,
    runInShell: Platform.isWindows,
  );

  for (final missing in [
    ['ja', 'en'],
    ['ja'],
    ['en'],
  ]) {
    test('fails when merged ARB is missing: ${missing.join(', ')}', () async {
      for (final locale in ['ja', 'en']) {
        if (!missing.contains(locale)) {
          writeMerged(locale, {'hello': 'Hello'});
        }
      }

      final result = await runCheck();

      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stderr, contains('Error: Merged ARB files not found.'));
      expect(result.stderr, contains('Run merge_l10n.dart first.'));
    });
  }

  test('succeeds when both merged ARBs have matching keys', () async {
    writeMerged('ja', {'hello': 'こんにちは'});
    writeMerged('en', {'hello': 'Hello'});

    final result = await runCheck();

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, isEmpty);
    expect(result.stdout, contains('Key consistency: OK!'));
  });

  test('still fails when merged ARB keys do not match', () async {
    writeMerged('ja', {'hello': 'こんにちは'});
    writeMerged('en', {'other': 'Other'});

    final result = await runCheck();

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('Keys only in JA (1):\n- hello'));
    expect(result.stderr, contains('Keys only in EN (1):\n- other'));
  });
}
