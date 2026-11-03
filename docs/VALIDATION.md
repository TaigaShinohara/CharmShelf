# Public snapshot validation

Validated on 2026-11-02 with Flutter 3.47.9 / Dart 3.13.7 on macOS. The checks describe this source snapshot; they do not establish physical-device behavior or store-distribution readiness.

| Check | Result |
| --- | --- |
| Credential-free setup and code generation | Passed with a fresh public workspace and locally provisioned SDK |
| Flutter static analysis | Passed, no issues |
| Full Flutter suite, including golden comparisons | 1,965 passed |
| Python script regression suites | 23 + 70 passed |
| Audit patterns and architecture boundaries | Passed |
| Dependency patch / Isar code-generation provenance | Passed |
| Dependency license reproduction | 382 entries, including native/PDFium/libmdbx notices; removed PDF SDK absent |
| First-party source privacy and Gitleaks | Passed; staged source and complete Git history checked with values redacted |
| Public asset provenance | 101 generated assets checked against the committed SHA-256 manifest |
| Android Debug APK | Built without maintainer signing credentials; label CharmShelf, application ID com.tsmusic.privateshelf.opensource |
| Android native packaging | 19 ELF libraries inspected; 64-bit libraries meet 16KB alignment; required native plugins present |
| iOS Simulator Debug | Built without distribution signing; label CharmShelf, bundle ID org.charmshelf.opensource |
| Android/iOS bundled media and notices | New generated media and the public notice bundle included; removed proprietary SDK and unknown WAV absent |

The Android APK check distinguishes 64-bit 16KB requirements from legacy ARMv7's 4KB alignment, as described in the [Android page-size guidance](https://developer.android.com/guide/practices/page-sizes). This is a static packaging check, not a 16KB-device execution test.

The iOS dependency server timed out during initial SwiftPM resolution. The official PDFium XCFramework archive was separately downloaded and matched the checksum declared by its upstream package, then reused in the project-local cache. No package source, pinned checksum, signing identity, or global setting was changed to make the build pass.

A local stale Intel JDK setting was bypassed using temporary process settings with an installed ARM JDK 17. An additional 3 regression tests verify automatic fallback from an unusable inherited JDK while preserving an explicit valid choice and the parent environment. The optional `scripts/flutter_local.py` provides this isolated workflow without changing global Flutter settings.

The README previews use actual widgets with synthetic data. They are not physical-device screenshots. Golden baselines were regenerated for the public branding and then passed in the complete test run. Old failed-comparison artifacts are excluded.

## Scope still requiring manual or platform-specific validation

The post-publication PDF smoke test, its limits, and the ordered remaining
checks are described in [PDF_VALIDATION.md](PDF_VALIDATION.md).

- Physical Android/iOS devices, PDF zoom/selection/password-protected files, background audio, permissions and OS-specific file pickers.
- Store purchases, official release signing, store submission, and signed binary distribution. Public builds keep purchases and store-review prompts disabled by default.
- Linux, Windows, macOS and Web runtime behavior. The source files and upstream libraries are retained with provenance; their presence does not establish full support.
- Clean-checkout CI is defined in [ci.yml](../.github/workflows/ci.yml). Its live result should be checked on GitHub for the revision being used.

Source and media licenses, source privacy checks, native-library provenance, compilation, and real-device behavior are separate verification steps. Preserve the limits above when reporting validation for later revisions.
