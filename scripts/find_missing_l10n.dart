import 'dart:io';
import 'dart:convert';

void main() async {
  final l10nFile = File('lib/l10n/app_ja.arb');
  if (!l10nFile.existsSync()) {
    stderr.writeln('Error: app_ja.arb not found. Run merge_l10n.dart first.');
    return;
  }

  final l10nJson =
      json.decode(l10nFile.readAsStringSync()) as Map<String, dynamic>;
  final existingKeys = l10nJson.keys.where((k) => !k.startsWith('@')).toSet();

  // l10n.keyName( または l10n.keyName の形式をマッチ
  final l10nPattern = RegExp(r'l10n\.([a-zA-Z0-9_]+)');
  final usedKeys = <String>{};

  final libDir = Directory('lib');
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.contains('.freezed.dart') &&
        !entity.path.contains('.g.dart') &&
        !entity.path.contains('gen_l10n/')) {
      final content = await entity.readAsString();
      final matches = l10nPattern.allMatches(content);
      for (final match in matches) {
        final key = match.group(1)!;
        // 基本的なキーワードやメソッドを除外
        if (key == 'of' || key == 'supportedLocales' || key == 'delegate') {
          continue;
        }
        usedKeys.add(key);
      }
    }
  }

  final missingKeys = usedKeys.difference(existingKeys);

  if (missingKeys.isEmpty) {
    stdout.writeln('No missing localization keys found!');
  } else {
    stdout.writeln('Total used keys: ${usedKeys.length}');
    stdout.writeln('Total existing keys: ${existingKeys.length}');
    stdout.writeln('Missing keys count: ${missingKeys.length}');
    stdout.writeln('\nMissing keys:');
    for (final key in missingKeys.toList()..sort()) {
      stdout.writeln('- $key');
    }
    exit(1);
  }
}
