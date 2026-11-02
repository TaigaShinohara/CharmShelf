# wakelock_plus 1.8.2 compatibility fork

- Archive: https://pub.dev/api/archives/wakelock_plus-1.8.2.tar.gz
- SHA-256: `39a1d99085cf3190d41305bca05f0c0d77522f355f7f99bb648ee231192d9d68`
- Changes: https://pub.dev/packages/wakelock_plus/changelog

Rebased native implementations, Pigeon messages, web code, SDK requirements, and
pubspec onto the official archive. Upstream now officially supports DBus 0.8,
package_info_plus 10, and win32 6; the old dependency-constraint patches are gone.
Linux runtime matches upstream. Inhibit still returns one object path, Close
still has a void reply, and the request handle is cleared only after Close
succeeds. Existing DBus/failed-Close regressions are retained.

The 1.8.2 update changes only the package version, changelog, and asset declaration:
`no_sleep.js` is included only in web builds. All upstream runtime, Android and
Apple files are unchanged from 1.8.1, so the local changes below are retained.
Validate the asset's absence from native app bundles and presence in a web build.

Retained local changes:

- Android applies external KGP on AGP 9 when android.builtInKotlin=false, as the
  consuming Flutter app requests. Upstream only checks the AGP major and would
  skip the required Kotlin plugin in this configuration. JVM 17 is retained.
- Apple SwiftPM omits sibling FlutterFramework package/product dependencies so
  the generated app package owns the single Flutter link. Privacy resources and
  native implementations are otherwise upstream-identical.
- Windows retains the injected, typed EXECUTION_STATE API seam and failed-call
  state regression. Production still calls SetThreadExecutionState; the new
  upstream dependency range needs no additional constraint patch.

Source hashes distinguish upstream and retained changes. Native power management
and interactive behavior remain separate platform checks. Windows regression and
build execution remain opt-in in the existing Device-Target workflow.
