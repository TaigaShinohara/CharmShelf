# android_file_picker 2.1.1 notification-cancellation compatibility

- Archive: https://pub.dev/api/archives/android_file_picker-2.1.1.tar.gz
- SHA-256: `e94229cc41c4bb5fb6a2254146340a8b650664c99b5c93b9001f66c3375d0060`
- Changes: https://pub.dev/packages/android_file_picker/changelog

The parent `file_picker` stays hosted at 13.3.0. Only this federated Android
implementation is overridden. Its official Dart API, SAF options, input copying,
MIME handling, and grant settings are retained. The workspace resolution marker
is removed from the local pubspec.

The old TagShelf picker fork implemented `cancelPendingRequest` on the existing
`miguelruivo.flutter.plugins.filepicker` channel. The app's return notification
still calls it. Official 2.1.1 lacks the handler, so this fork restores it and
protects the next request from late results:

- Every launched open/save request receives a distinct 16-bit request code.
  A cancelled code remains reserved until its late ActivityResult is consumed;
  it cannot be reused for a replacement request. A durable cancellation tombstone
  also excludes it after process death until the stale result is consumed.
  Exhaustion reports an error.
- Only the active code may start file processing. Results owned by another
  plugin do not fail this plugin's pending request. Duplicate ActivityResults
  cannot start a second IO operation.
- IO completion captures its request generation. Cancelled or superseded work
  cannot complete or clear a newer method call. Pending state is cleared before
  publishing success/error, including reentrant callbacks. Invalid terminal
  results report a single error rather than retaining a permanently busy state.
- `LostDataStore` persists the request code with the existing options and only
  restores a matching result. Legacy saved requests retain the old fixed-code
  fallback. Recovery in progress prevents a new request from replacing its
  options. The existing retrieveLostData contract is retained.
- Restoration also carries a process-wide token. Cancellation from a recreated
  delegate invalidates the old delegate's IO and releases a waiting retrieval
  with null before another pick proceeds. Success/error publication rechecks
  that token under the same store lock as its preference updates, so an old
  completion cannot clear newer request metadata or publish a cancelled result.
- Cancellation also handles a saved request before its lost-result restoration
  begins. Pending removal and the cancelled-code tombstone share one synchronous
  commit, so a subsequent process restart cannot resurrect it after a successful
  commit. A failed commit is reported to the cancellation caller after local
  pending/generation cleanup and activity close, even when the failure already
  changed SharedPreferences memory. Disk durability is not claimed on failure.
- Cancellation completes the existing method call with null and closes only
  its own activity request. It does not revoke grants, delete originals, or
  change the user's requested SAF access/grant flags. Stale success results are
  discarded before touching a provider. Processing already authorized before
  cancellation may have created an app-owned cache copy; no source file is
  deleted or overwritten by the open-file path.

`PickerCancellationTest` uses Robolectric activities, synthetic callback results,
and virtual provider/grant state. Its twelve cases cover cancel/new/late results,
stale IO success/error, foreign activity results, reentrant and duplicate
completion, save cancellation, lost-result identity, retained grant state, cancel-before-lost-restore after process death, and
cancellation persistence failures both before and after their memory update.
They also cover cancellation during old-delegate restoration after activity
recreation, reentrant retrieval/replacement, obsolete-token publication, and
restoration cancellation when persistence fails.
It never launches a picker UI or accesses a real document provider/user file.

Run `:android_file_picker:testDebugUnitTest` from `android/` once the root build
slot is available. Source review and these synthetic tests do not establish
interactive Android picker/notification behavior. Provenance distinguishes
official hashes, reviewed runtime/config changes, and the added test source in
`scripts/maintenance/path_override_upstream_hashes.json`.
