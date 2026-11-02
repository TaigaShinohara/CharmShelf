# Linux notification 8.0.2 compatibility reference

Runtime sources, pubspec, and LICENSE match the official 8.0.2 archive:

- Archive: https://pub.dev/api/archives/flutter_local_notifications_linux-8.0.2.tar.gz
- SHA-256: `3b89a4bf095fa5f8a99beeabf982c5bd506c3ad25e7b9e61da945e994dc5b615`
- Upstream: https://github.com/MaikuB/flutter_local_notifications

Upstream now accepts DBus `>=0.7.8 <0.9.0`, so the previous dependency patch
is no longer needed. The app retains a local reference and its wire-value
regression test to keep notification parent 22.3.2, platform interface 12.2,
and DBus 0.8 in one verified graph. Runtime is unmodified; generated DBus
multi-value records do not affect its direct returnValues decoding. Anonymous
authentication stays disabled by default.

Run this package's wire-value regression and upstream manager/storage tests
against the app graph when updating it. Native Linux server behavior remains
a separate verification gate.
