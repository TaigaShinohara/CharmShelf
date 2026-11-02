# device_info_plus 13.3.0 compatibility fork

- Archive: https://pub.dev/api/archives/device_info_plus-13.3.0.tar.gz
- SHA-256: `ade1c36f8355d6284c98e4a47992ea263887ed3d1acb281e37635dd45f04c4aa`
- Changes: https://pub.dev/packages/device_info_plus/changelog

Rebased runtime, public Dart API, Apple model identifiers, Android Kotlin DSL,
and SDK requirements onto the official archive. Upstream 13 already adopts
win32 6 and win32_registry 3, so the old dependency-constraint patches are gone.
Android's built-in-Kotlin opt-out check is upstream's 13.3 fix and supports this
app's explicit external KGP configuration.

Retained local changes:

- Apple SwiftPM manifests omit the sibling `FlutterFramework` dependency and
  product; the app's generated Flutter package owns the single Flutter link.
- Apple privacy manifests retain the existing DiskSpace reason `E174.1`.
  The iOS implementation still calls `attributesOfFileSystemForPath`; importing
  the archive's empty accessed-API declaration would drop the existing coverage.
- iOS free-memory bytes use a 64-bit intermediate until conversion to the existing
  integer MiB result. This removes the narrowing warning and prevents wrapping at
  4 GiB, while retaining the Mach query, units, result type and failure sentinel.
- Windows uses the actual win32 RtlGetVersion/NTSTATUS API, scoped typed string
  allocations, checked Win32Result values, and a registry reader that closes both
  keys on success and failure. These cleanup/error-handling changes are not in
  13.3.0. The added registry helper has its own reason and hash, not a fabricated
  upstream hash.

`test/windows_compatibility_test.dart` retains synthetic registry/cleanup cases
and an opt-in native Windows metadata smoke. Source hashes distinguish official,
patched, and added files in `scripts/maintenance/path_override_upstream_hashes.json`.
