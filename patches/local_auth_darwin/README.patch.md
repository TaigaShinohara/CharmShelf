# local_auth_darwin 2.0.5 compatibility rebase

Official archive: https://pub.dev/api/archives/local_auth_darwin-2.0.5.tar.gz

SHA-256: `45a9db01b57082bc9d6115cb25eb8fc0b72f43e5f330819bdd8352ecdae87589`

The official 2.0.2 archive was compared with the existing fork before applying
the 2.0.5 update. Runtime and build changes from the new release are adopted.
Existing local changes are separately recorded with their reason, upstream hash
and resulting hash in `scripts/maintenance/path_override_upstream_hashes.json`.
The upstream LICENSE is retained. No app data or global SDK files are modified.

Retain explicit MainActor isolation and qualify Dart Pigeon message types.
Authentication policy, error mapping, sticky-auth retry, channel names, wire format,
minimum OS versions and Keychain settings are unchanged.

## Swift concurrency boundary

The plugin, context factory protocol and local Pigeon API/setup share the main
actor. Pigeon uses Flutter's default main-thread message queue. The two annotations
in `messages.g.swift` are an intentional local generated-code patch: retain them
when regenerating/rebasing the vendored package, then rerun the checks below.

Only the external Objective-C `FlutterPlugin` and iOS scene delegate conformances
use Swift 6's checked `@preconcurrency` conformance. Older compilers use the normal
conformance in the conditional branch. Registration, API methods and lifecycle
entry points explicitly check `MainActor.preconditionIsolated()` in both language
modes. Do not change these entries to a background task queue without revisiting
this contract. Internal calls remain statically actor checked.

The LocalAuthentication background callback captures a main-actor `@Sendable`
handler, then invokes it on the main dispatch queue. Non-Sendable options and
completion stay inside that actor-isolated handler. The plugin's former
`@unchecked Sendable` conformance is removed. Immediate failures and capability
queries remain synchronous.

## Compatibility checks

From the repository root, using the fixed Flutter 3.47.8 SDK:

```sh
bash scripts/quiet_check.sh python3 scripts/maintenance/check_local_auth_swift_compatibility.py --flutter-sdk build/toolchains/flutter-3.47.8 --mode compile-ios --swift-version 5
bash scripts/quiet_check.sh python3 scripts/maintenance/check_local_auth_swift_compatibility.py --flutter-sdk build/toolchains/flutter-3.47.8 --mode compile-ios --swift-version 6
bash scripts/quiet_check.sh python3 scripts/maintenance/check_local_auth_swift_compatibility.py --flutter-sdk build/toolchains/flutter-3.47.8 --mode test-macos --swift-version 5
bash scripts/quiet_check.sh python3 scripts/maintenance/check_local_auth_swift_compatibility.py --flutter-sdk build/toolchains/flutter-3.47.8 --mode test-macos --swift-version 6
bash scripts/quiet_check.sh python3 scripts/maintenance/check_path_override_upstream.py
```

Run sequentially. The helper checks resources and active builds, copies the exact
sources with SHA guards, uses real cached Flutter frameworks, and enables complete
concurrency checking with warnings as errors. iOS emits real object code at the
iOS 13 minimum; type checking alone does not catch all region-isolation errors.
macOS runs the upstream and added stub tests without opening an authentication UI.
The temporary harness does not change the production package or SDK.

See [the 2026-10-22 compatibility record](../../docs/LOCAL_AUTH_SWIFT_COMPATIBILITY_20261022.md)
for toolchain versions, results and the limits of these checks.
