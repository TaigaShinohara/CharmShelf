# Isar 3.1.0+1 generator toolchain port

This fork retains Isar 3.1.0+1 runtime, native binaries, schema identifiers,
serializers and query generation. It permits the application's code generators
to share analyzer 14, build 4 and source_gen 4 on Dart 3.13. Build 5 is not
adopted because the current official Riverpod generator requires build <5.

- Original package: <https://pub.dev/packages/isar_generator/versions/3.1.0+1>
- Original archive: <https://pub.dev/api/archives/isar_generator-3.1.0%2B1.tar.gz>
  SHA-256: `76c121e1295a30423604f2f819bc255bc79f852f3bc8743a24017df6068ad133`.
- Analyzer integration reference: isar_community_generator 3.3.2,
  <https://pub.dev/packages/isar_community_generator/versions/3.3.2>.
  Archive SHA-256: `fd5a2a5df2aac2fccba82425005bf47fd2a48f34190536d0c9fd732dc7303fb3`.
- The original Apache-2.0 LICENSE is retained.

Only `lib/src/helper.dart`, `isar_analyzer.dart` and `isar_type.dart` port the
analyzer element/fragment/formal-parameter APIs and TypeChecker.typeNamed.
They retain `package:isar/isar.dart` annotations. This is a development-time
generator port, not adoption of the community runtime or a database migration.

`lib/src/code_gen/*`, `object_info.dart` and the original collection generator
are retained from 3.1.0+1. Template hashes are recorded in
`upstream_templates.sha256.json`. `generated_baseline.sha256.json` records the
seven application collections before the toolchain port, ignoring only comments,
whitespace and optional trailing commas. The baseline therefore checks schema
IDs, properties, indexes, enum maps, adapters and query operations together.

After generation run:

```sh
python3 scripts/maintenance/check_isar_codegen_compatibility.py
flutter test test/core/database/isar_codegen_compatibility_test.dart
```

The database regression uses a new temporary directory containing synthetic
records, closes and reopens it, and checks scalar/list/enum/index/link persistence.
Never point this test at a personal library. Deliberate future model changes
require a separate storage-compatibility review before updating the baseline.
