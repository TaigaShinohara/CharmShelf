# in_app_review 2.0.12 compatibility rebase

Official archive: https://pub.dev/api/archives/in_app_review-2.0.12.tar.gz

SHA-256: `364db0c160b37fe7fad9cdaa18f968473924b17368869010af902760421b6bf8`

The official 2.0.11 archive was compared with the existing fork before applying
the 2.0.12 update. Runtime and build changes from the new release are adopted.
Existing local changes are separately recorded with their reason, upstream hash
and resulting hash in `scripts/maintenance/path_override_upstream_hashes.json`.
The upstream LICENSE is retained. No app data or global SDK files are modified.

Retain the iOS podspec integration metadata and omit screenshots not vendored here.
The Android background-review NullPointerException fix is adopted.

The iOS 12 minimum makes the old iOS 10.3 condition in `requestReview` always true.
The fallback is unconditional within the existing pre-iOS-14 branch. The iOS
12–13 review API, iOS 14–15 scene API, iOS 16+ AppStore API, scene selection and
reply order are retained. This does not force a review prompt to appear.
