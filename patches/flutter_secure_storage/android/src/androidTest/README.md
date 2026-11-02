# Synthetic legacy upgrade instrumentation

`LegacyStorageMigrationInstrumentedTest` exercises the actual migration entry point,
real AndroidKeyStore keys, and the v11 initialization/read/write code without
reflection or injected ciphers. Its fixtures cover:

- ESP AES256-SIV/AES256-GCM keysets encrypted by a real AndroidKeyStore master key.
- The legacy RSA-PKCS1/AES-CBC format without algorithm markers.
- The v9 RSA-PKCS1/AES-GCM format with its original wrapped-key preference typo.
- Automatic ESP migration through the v11 initialization gate.
- Fresh default non-biometric storage, writes, new storage objects, and reruns.
- Repeated failed initialization with corrupt legacy ciphertext, preserving the
  original encrypted data, wrapped key, RSA key, and retry journal.
- A missing ESP master key, preserving ciphertext without generating a replacement.

Each migrated store is read by a fresh `FlutterSecureStorage` object, is written by
v11, and is reopened again. This is an object reopen within the instrumentation
process; it does not simulate process death or a historical app binary update.
Transaction interruption/commit-failure paths are covered separately by
`LegacyMigrationTransactionTest`.

## Isolation and execution

The Android library's self-targeting APK uses application ID and test namespace
`com.it_nomads.fluttersecurestorage.migrationtest`. Before any mutation the tests
require this package for both instrumentation and target contexts, the target UID
to match the current process, emulator hardware `ranchu`/`goldfish`, and the explicit
argument `tagshelfSyntheticStorageMigration=true`. Cleanup touches only five known
preference files and three known synthetic aliases inside that APK's UID. The
TagShelf application package is never opened.

Use Flutter 3.47.8 and the repository Android toolchain. Check running builds and
resources first and keep the repository Gradle memory/worker limits. Do not run
concurrent builds. The build-only task, from `android/`, is:

```sh
./gradlew :flutter_secure_storage:assembleDebugAndroidTest
```

Before installation, inspect the generated APK's application ID and instrumentation
target package and confirm that both are the test package above. Select a dedicated
emulator by its explicit `emulator-...` serial for every adb command. Install and
instrument only this APK, never the TagShelf APK or a physical device:

```sh
adb -s EMULATOR_SERIAL install -r PATH_TO_TEST_APK
adb -s EMULATOR_SERIAL shell am instrument -w -r \
  -e class com.it_nomads.fluttersecurestorage.LegacyStorageMigrationInstrumentedTest \
  -e tagshelfSyntheticStorageMigration true \
  com.it_nomads.fluttersecurestorage.migrationtest/androidx.test.runner.AndroidJUnitRunner
```

The equivalent Gradle execution task is
`:flutter_secure_storage:connectedDebugAndroidTest`, with runner arguments
`class=com.it_nomads.fluttersecurestorage.LegacyStorageMigrationInstrumentedTest`
and `tagshelfSyntheticStorageMigration=true`. Do not use an unfiltered connected
task while physical devices are attached: its APK installation precedes runtime
test guards. The explicit-serial adb path above makes the device target reviewable.

Runner `1.7.0` and ext JUnit `1.3.0` are stable releases from the
[AndroidX Test release notes](https://developer.android.com/jetpack/androidx/releases/test).
The runner setup and task syntax follow the official
[instrumented test guide](https://developer.android.com/training/testing/instrumented-tests)
and [command-line test guide](https://developer.android.com/studio/test/command-line).
