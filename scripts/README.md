# Development scripts

Start with [the setup guide](../docs/SETUP_GUIDE.md). Use Flutter 3.47.9 and its bundled Dart SDK. Normal development does not use a secret manager or store credentials.

| Command | Purpose |
| --- | --- |
| `bash scripts/setup_dev.sh` | Resolve the lockfile, prepare host Isar, and generate app sources |
| `dart run scripts/update_config.dart` | Generate AppConfig from template_config.yaml; this does not create an application |
| `dart run scripts/check_l10n_consistency.dart` | Check language keys and placeholder consistency |
| `dart run scripts/merge_l10n.dart` then `flutter gen-l10n` | Generate localization from lib/l10n_src/ja and en |
| `dart run build_runner build` | Generate model and provider code |
| `python3 scripts/maintenance/export_public_notices.py --check` | Verify bundled legal text against resolved dependencies |
| `python3 scripts/maintenance/check_private_content.py --sources-only` | Check first-party source for private data without printing values |
| `python3 scripts/maintenance/check_public_snapshot.py` | Verify the indexed publication boundary and generated asset hashes |
| `python3 scripts/maintenance/check_secrets.py` | Scan indexed source and all Git history with checksum-pinned Gitleaks |
| `bash scripts/quiet_check.sh COMMAND ARG...` | Save verbose output privately and preserve the command exit code |

`check_secrets.py` downloads Gitleaks 8.30.1 on supported macOS ARM/Linux x64 hosts and verifies a pinned SHA-256 before execution. Other hosts can supply `GITLEAKS_BIN`. Its output contains rule IDs and locations, never matched values. The narrow exceptions in .gitleaks.toml cover reviewed public constants and exact source digests; they do not exclude whole vendor or test trees.

The native notices rebuild tool is for dependency maintainers; its exact source inputs are described in [native provenance](../docs/NATIVE_PROVENANCE.md). Normal contributors use the committed native notice snapshot.

## Optional legacy template generator

`dart run scripts/create_app.dart --name my_app` is an advanced template tool, not the normal CharmShelf setup. It writes a separate sibling project and refuses an existing output directory. Platform integrations in generated projects require independent review and testing; this command does not establish compatibility with the complete CharmShelf native bridges. Do not use it to repair this checkout.

## Optional distribution

Signing/export/Fastlane tools are outside the credential-free development path. The committed distribution settings are placeholders. They fail before authentication or upload until a maintainer explicitly configures their own application. See [auth/README.md](../auth/README.md). Never commit populated signing settings, keys, local reference JSON, or diagnostic logs.
