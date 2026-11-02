# Contributing to CharmShelf

Japanese and English contributions are welcome.

## Before making a change

For a substantial feature or dependency replacement, open an issue describing the problem and the intended behavior first. Bug reports should include the app revision, platform, reproduction steps, and expected result. Use synthetic examples and remove personal file names, media, paths, and logs. Report vulnerabilities through [SECURITY.md](SECURITY.md).

## Local development

Follow the [setup guide](docs/SETUP_GUIDE.md). Flutter **3.47.9** is required. A fresh Debug checkout uses no owner account, API key, 1Password setup, or store signing credential.

```sh
bash scripts/setup_dev.sh
flutter analyze
flutter test --exclude-tags golden
```

The standard command matches CI and excludes environment-dependent golden image comparisons. For UI changes, also run `flutter test --tags golden` on the intended rendering environment and review the image differences.

Keep changes focused. Add a regression test when it verifies meaningful behavior, especially around file operations, backup/restore, cancellation, permissions, or data migrations. State which platforms and real devices you checked; do not imply that a host test verifies all native platforms.

## Generated files and dependencies

- Change app configuration in `template_config.yaml`, then run `dart run scripts/update_config.dart`.
- Change translations in both `lib/l10n_src/ja/` and `lib/l10n_src/en/`, then merge and generate them as described in the setup guide.
- Run `dart run build_runner build` after model or provider changes. Do not hand-edit generated files.
- Keep `pubspec.lock` changes intentional. For local dependency patches, preserve upstream licenses and provenance records and update `docs/DEPENDENCY_OVERRIDES.md`.
- Keep the Dart package name `private_shelf`; changing public branding does not require renaming every internal identifier.

## Pull requests

Explain the problem, the resulting behavior, and how the change was checked. Include screenshots only when they help review a UI change and contain synthetic data. Note untested platforms or remaining limitations. Do not include generated build output, credentials, local signing profiles, personal media, or unrelated changes.

By submitting a contribution, you agree to license your contribution under the project's [MIT license](LICENSE), while preserving applicable third-party licenses. Follow the [code of conduct](CODE_OF_CONDUCT.md).
