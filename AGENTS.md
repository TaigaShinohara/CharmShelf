# CharmShelf contributor instructions

- Inspect the working tree before editing and preserve unrelated changes. Keep changes within the requested scope.
- Use Flutter **3.47.9**, as pinned by `pubspec.yaml`, and its bundled Dart SDK. Run `bash scripts/setup_dev.sh` to prepare a fresh checkout. Do not assume an owner-specific SDK location, account, or secret manager.
- Before starting a build, check for existing builds and available memory/disk. Run one build at a time. Respect `android/gradle.properties` limits: 3072 MB heap and 2 workers.
- For verbose checks, use `bash scripts/quiet_check.sh COMMAND ARG...` and check its exit status and saved log.
- Edit `template_config.yaml` for app configuration, then run `dart run scripts/update_config.dart`. Do not edit generated configuration directly.
- Edit localization in `lib/l10n_src/ja/` and `lib/l10n_src/en/`, then run `dart run scripts/check_l10n_consistency.dart`, `dart run scripts/merge_l10n.dart`, and `flutter gen-l10n`. Do not edit merged or generated localization files directly.
- Generate model/provider code with `dart run build_runner build`. Do not hand-edit generated Dart files.
- Keep backup, restoration, and external-folder operations safe: do not mutate data before confirmation, surface failures, and preserve a retryable state after partial failure. Distinguish original files from app-managed records.
- Keep the internal Dart package name `private_shelf` unless a task explicitly requires a migration. The display name is CharmShelf; public build identifiers are separate from the former distribution.
- Preserve upstream licenses, copyright notices, patch documentation, and provenance hashes when changing `patches/`. Reconcile dependency changes with `docs/DEPENDENCY_OVERRIDES.md`.
- Normal Debug development requires no API keys or store credentials. Never commit credentials, local auth references, signing assets, personal data, or private logs. See `auth/README.md` for the optional distribution boundary.
- Run checks proportional to the change. Report what passed and what was not verified; host tests do not establish real-device behavior.

- If a compatible SDK has been provisioned locally at `build/toolchains/flutter-3.47.9`, prepend its `bin` to the process PATH. SDKs and local Flutter settings belong under ignored `build/`, never in Git. Do not modify global Flutter/JDK settings to repair a local build. A per-process `XDG_CONFIG_HOME` can select temporary Flutter settings on macOS/Linux when no legacy home settings file overrides it.

- On macOS/Linux, `python3 scripts/flutter_local.py build apk --debug` can use a local SDK and JDK with temporary process-only Flutter settings; it does not rewrite global settings. Normal CI and correctly configured developer machines may use Flutter directly.
