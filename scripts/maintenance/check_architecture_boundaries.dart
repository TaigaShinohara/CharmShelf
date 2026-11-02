import 'dart:io';

final _importPattern = RegExp(
  r'''^import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

Future<void> main() async {
  final violations = <String>[];
  final features = Directory('lib/features');

  await for (final entity in features.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.freezed.dart')) {
      continue;
    }

    final normalizedPath = entity.path.replaceAll('\\', '/');
    final source = await entity.readAsString();
    for (final match in _importPattern.allMatches(source)) {
      final imported = match.group(1)!;

      if (normalizedPath.contains('/data/') &&
          (imported.contains('/presentation/') ||
              imported.contains('/application/'))) {
        violations.add('$normalizedPath: Data -> $imported');
      }

      if (normalizedPath.contains('/application/') &&
          imported.contains('/presentation/')) {
        violations.add('$normalizedPath: Application -> $imported');
      }

      if (normalizedPath.contains('/domain/') &&
          (imported.contains('/data/') ||
              imported.contains('/application/') ||
              imported.contains('/presentation/') ||
              imported == 'package:flutter/material.dart' ||
              imported == 'package:flutter/widgets.dart' ||
              imported == 'package:flutter_riverpod/flutter_riverpod.dart' ||
              imported ==
                  'package:riverpod_annotation/riverpod_annotation.dart')) {
        violations.add('$normalizedPath: Domain -> $imported');
      }
    }
  }

  final legacyUseCases = Directory('lib/features/library/domain/use_cases');
  final hasLegacyUseCases =
      await legacyUseCases.exists() &&
      !(await legacyUseCases
          .list(followLinks: false)
          .where((entity) => entity is File && entity.path.endsWith('.dart'))
          .isEmpty);
  if (hasLegacyUseCases) {
    violations.add(
      'lib/features/library/domain/use_cases: application use cases must not be placed in Domain',
    );
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Architecture boundary violations:');
    for (final violation in violations) {
      stderr.writeln('- $violation');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Architecture boundaries: OK');
}
