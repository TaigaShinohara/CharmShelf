# Security policy

## Reporting a vulnerability

Do not post exploit details, private media, signing material, or credentials in a public issue or pull request.

If the repository offers **Security → Advisories → Report a vulnerability**, use that private reporting route. If it is unavailable, use the contact listed in the [privacy policy](docs/PRIVACY_POLICY.md). Start with a brief description and a way to contact you; do not send personal files or credential values.

A useful report includes:

- The affected revision and platform
- The impact and the conditions required to reproduce it
- Reproduction steps using synthetic data
- A minimal demonstration, when it can be shared safely

We do not promise a response deadline or a fixed support period. Fixes normally target the current main branch. The existence of a release tag does not establish support for older revisions.

## Data and platform boundaries

CharmShelf manages local files and library metadata. Backups are not encrypted and can include hidden, archived, and trashed items. App lock and hiding items do not encrypt those files or protect them from every OS-level access path. Review the [privacy policy](docs/PRIVACY_POLICY.md) before sharing backups or diagnostics.

Security-sensitive changes should preserve cancellation and retry behavior, avoid modifying data before confirmation, and test failure paths. Use placeholders and synthetic fixtures in reports and tests. Keep upstream license notices when updating bundled libraries.
