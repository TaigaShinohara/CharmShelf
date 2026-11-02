# Optional signing and distribution configuration

Normal CharmShelf development does **not** require this directory to be configured. Use `bash scripts/setup_dev.sh`, Android Debug, or the iOS simulator as described in the [setup guide](../docs/SETUP_GUIDE.md). No owner account, 1Password subscription, store API key, or distribution certificate is required for those paths.

## What the examples are for

The `*.example.json` files describe optional signing and store-API profiles for maintainers who choose to operate their own distribution. They contain placeholders rather than working credentials. They are not connected to a shared service and do not provide access to the former TagShelf distribution.

If you adapt them:

- Use your own app identifiers, signing assets, store accounts, and least-privilege credentials.
- Copy an example to `*.local.json` only when you need that profile. Local files are ignored by Git.
- Keep secrets in your own credential manager. Do not put secret values, access tokens, OTPs, or private keys into JSON examples, command arguments, logs, issues, or commits.
- The optional 1Password launchers require a separately installed, compatible shared runner under `CODEX_AUTH_HOME` or `~/.local/share/codex-auth`. That runner is not bundled or required for Debug development. A missing runner or unconfigured profile should stop the optional command; do not work around it by copying another project's credentials.

## Distribution is a separate operation

The public repository does not include an owner's signing key, provisioning profile, store registration, or permission to upload a build. The presence of Fastlane or a release helper does not establish a ready-to-use publishing pipeline. Configure and verify your own distribution separately before invoking any upload lane.

The Google Play upload guard deliberately blocks `internal`, `beta`, and `release` until the distribution configuration is explicitly reviewed. Keep that guard; successful signing or a read-only store API request does not prove upload permission.

The Android release helper expects the distributor's own signing-certificate fingerprint. iOS export options must refer to the distributor's own team, certificate, and provisioning profile. Placeholder export options are not a usable signing configuration. Do not use an existing TagShelf signature or store identity for a fork.

Signing checks, local build checks, upload permission, and actual publication are distinct results. Never publish, grant permissions, purchase services, or remove credentials merely as part of setting up a Debug build.
