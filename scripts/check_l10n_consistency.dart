import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  const srcDir = 'lib/l10n_src';
  final jaSrcDir = p.join(srcDir, 'ja');
  final enSrcDir = p.join(srcDir, 'en');

  // 1. ファイル構成のチェック
  stdout.writeln('--- Checking file consistency ---');
  final jaFiles = await _getArbFiles(jaSrcDir);
  final enFiles = await _getArbFiles(enSrcDir);

  final onlyInJaFiles = jaFiles.difference(enFiles);
  final onlyInEnFiles = enFiles.difference(jaFiles);

  var hasError = false;

  if (onlyInJaFiles.isNotEmpty) {
    stderr.writeln('Error: Files found only in JA:');
    for (final f in onlyInJaFiles) {
      stderr.writeln('  - $f (Missing in EN)');
    }
    hasError = true;
  }

  if (onlyInEnFiles.isNotEmpty) {
    stderr.writeln('Error: Files found only in EN:');
    for (final f in onlyInEnFiles) {
      stderr.writeln('  - $f (Missing in JA)');
    }
    hasError = true;
  }

  if (!hasError) {
    stdout.writeln('File consistency: OK!');
  }

  // 2. マージ済みファイルのキー整合性チェック
  stdout.writeln('\n--- Checking key consistency (Merged files) ---');
  final jaFile = File('lib/l10n/app_ja.arb');
  final enFile = File('lib/l10n/app_en.arb');

  if (!jaFile.existsSync() || !enFile.existsSync()) {
    stderr.writeln(
      'Error: Merged ARB files not found. Run merge_l10n.dart first.',
    );
    exitCode = 1;
    return;
  }

  final jaJson = jsonDecode(jaFile.readAsStringSync()) as Map<String, dynamic>;
  final enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  final jaKeys = jaJson.keys
      .where((k) => !k.startsWith('@') && k != '@@locale')
      .toSet();
  final enKeys = enJson.keys
      .where((k) => !k.startsWith('@') && k != '@@locale')
      .toSet();

  final onlyInJa = jaKeys.difference(enKeys);
  final onlyInEn = enKeys.difference(jaKeys);

  if (onlyInJa.isEmpty && onlyInEn.isEmpty) {
    stdout.writeln('Key consistency: OK! All keys match between ja and en.');
  } else {
    hasError = true;
    if (onlyInJa.isNotEmpty) {
      stderr.writeln('\nKeys only in JA (${onlyInJa.length}):');
      for (final key in onlyInJa.toList()..sort()) {
        stderr.writeln('- $key');
      }
    }
    if (onlyInEn.isNotEmpty) {
      stderr.writeln('\nKeys only in EN (${onlyInEn.length}):');
      for (final key in onlyInEn.toList()..sort()) {
        stderr.writeln('- $key');
      }
    }
  }

  // 3. プレースホルダーとメタデータの整合性チェック
  stdout.writeln('\n--- Checking placeholder metadata ---');
  hasError = _checkMetadata(jaJson, 'JA') || hasError;
  hasError = _checkMetadata(enJson, 'EN') || hasError;

  if (hasError) {
    exit(1);
  }
}

bool _checkMetadata(Map<String, dynamic> json, String label) {
  var hasError = false;
  final keys = json.keys.where((k) => !k.startsWith('@') && k != '@@locale');
  for (final key in keys) {
    final value = json[key];
    if (value is! String) continue;

    // プレースホルダー {xxx} を抽出
    final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    final matches = placeholderRegex.allMatches(value);

    // pluralなどの複雑な構文は一旦除外（単純なプレースホルダーのみチェック）
    if (value.contains(', plural,') || value.contains(', select,')) {
      // plural/selectの場合はメタデータ必須
      if (!json.containsKey('@$key')) {
        hasError = true;
        stderr.writeln(
          'Error [$label]: Complex message "$key" is missing metadata (@$key).',
        );
      }
      continue;
    }

    if (matches.isNotEmpty) {
      if (!json.containsKey('@$key')) {
        hasError = true;
        stderr.writeln(
          'Error [$label]: Message "$key" has placeholders but missing metadata (@$key).',
        );
        continue;
      }

      final metadata = json['@$key'] as Map<String, dynamic>?;
      final placeholders = metadata?['placeholders'] as Map<String, dynamic>?;

      for (final match in matches) {
        final pName = match.group(1);
        if (placeholders == null || !placeholders.containsKey(pName)) {
          hasError = true;
          stderr.writeln(
            'Error [$label]: Placeholder "{$pName}" in "$key" is not defined in @$key.',
          );
        }
      }
    }
  }
  return hasError;
}

Future<Set<String>> _getArbFiles(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) return {};
  return dir
      .listSync()
      .where((e) => e is File && e.path.endsWith('.arb'))
      .map((e) => p.basename(e.path))
      .toSet();
}
