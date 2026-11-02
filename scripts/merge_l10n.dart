import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final l10nDir = p.join(Directory.current.path, 'lib', 'l10n');
  final srcDir = p.join(Directory.current.path, 'lib', 'l10n_src');

  if (!await Directory(srcDir).exists()) {
    stderr.writeln('Error: src directory not found at $srcDir');
    exit(1);
  }

  final locales = await Directory(srcDir)
      .list()
      .where((entity) => entity is Directory)
      .map((entity) => p.basename(entity.path))
      .toList();

  for (final locale in locales) {
    stdout.writeln('Merging ARB files for locale: $locale');
    final localeSrcDir = p.join(srcDir, locale);
    final mergedContents = <String, dynamic>{};

    // 基本となる@@localeを設定
    mergedContents['@@locale'] = locale;

    final arbFiles = await Directory(localeSrcDir)
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.arb'))
        .toList();

    // ファイル名でソートして安定性を確保
    arbFiles.sort((a, b) => a.path.compareTo(b.path));

    for (final fileEntity in arbFiles) {
      final file = fileEntity as File;
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        json.forEach((key, value) {
          if (key == '@@locale') return; // @@localeはスキップ
          if (mergedContents.containsKey(key)) {
            stderr.writeln(
              'Error: Duplicate key "$key" found in ${p.basename(file.path)}. Aborting.',
            );
            exit(1);
          }
          if (value is String && value.trim().isEmpty) {
            stderr.writeln(
              'Warning: Empty value for key "$key" in ${p.basename(file.path)}.',
            );
          }
          mergedContents[key] = value;
        });
      } catch (e) {
        stderr.writeln('Error parsing ${file.path}: $e');
        exit(1);
      }
    }

    final outputFile = File(p.join(l10nDir, 'app_$locale.arb'));
    const encoder = JsonEncoder.withIndent('  ');
    await outputFile.writeAsString(encoder.convert(mergedContents));
    stdout.writeln('Generated: ${outputFile.path}');
  }
}
