# audio_service 0.18.19 compatibility rebase

Official archive: https://pub.dev/api/archives/audio_service-0.18.19.tar.gz

SHA-256: `95f3267f3449eb5cf71c8fcf1d556f57af1e898e2dc5815fb168d1843653edb7`

The official 0.18.18 archive was compared with the existing fork before applying
the 0.18.19 update. Runtime and build changes from the new release are adopted.
Existing local changes are separately recorded with their reason, upstream hash
and resulting hash in `scripts/maintenance/path_override_upstream_hashes.json`.
The upstream LICENSE is retained. No app data or global SDK files are modified.

Retain the modern iOS artwork initializer; adopt upstream AGP9/Kotlin build support.
