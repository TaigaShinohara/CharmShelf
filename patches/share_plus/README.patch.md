# share_plus 13.3.1 compatibility fork

- Archive: https://pub.dev/api/archives/share_plus-13.3.1.tar.gz
- SHA-256: `db40767f130189d53f3ae8a6393c217ff4a492da1baff718a9873679c0c00224`
- Changes: https://pub.dev/packages/share_plus/changelog

Rebased native implementations, Dart APIs, Android Kotlin DSL, platform-interface
requirements, and dependencies onto the official archive. Upstream already
supports win32 6, so the previous dependency-constraint override is removed.

The remaining changes are Apple SwiftPM's single Flutter link (omit the sibling
FlutterFramework package/product) and Windows version detection. Version detection
uses win32's real RtlGetVersion/NTSTATUS API, scopes its allocation in an Arena,
and keeps the existing fallback on a failed read. It retains the synthetic
version-boundary, modern method-channel versus legacy mailto, and URL-encoding
regressions. Other runtime files and Apple privacy declarations match 13.3.1.
