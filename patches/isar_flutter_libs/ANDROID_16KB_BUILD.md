# Android 16KB page-size build provenance

## 2026-11-01 isolated database compatibility verification

Flutter 3.47.9 was used to build one Profile-only, numbered `performanceqa`
APK containing the preserved baseline arm64 library and the remapped candidate.
The baseline was present only in a disposable QA copy, never in production inputs.
Both native payloads were hashed after APK packaging and matched their expected
SHA-256 values. The tested committed source was `16ad7dc4` (before this result note).

On a dedicated Android 15 / 16KB arm64 emulator, three distinct cold processes
successfully completed `seed-old`, `read-write-new`, and `verify-new`. The first
created and reopened the database with the baseline; the second read, updated and
reopened it with the candidate; the third verified the candidate's persisted
updates. All seven application schemas and their synthetic records/links were
checked. The baseline snapshot and synthetic original file remained unchanged.
The host driver verified stage order, process separation, unchanged APK/native
hashes, and continuity of the previous database hash. No app clear, uninstall,
real user library, or production package was used.

This verifies arm64 runtime database compatibility; the other three ABIs retain
the static ABI/version/alignment/path checks below. It is not an actual-device
or store-distribution validation. The emulator was stopped after the test and
the disposable fixture/evidence was retained locally.

The Android `libisar.so` files in this package are rebuilt from the unchanged
Isar 3.1.0+1 and libmdbx database source. Linker settings retain 16KB page
alignment; compiler path remapping removes private build-machine paths.
The source version and exported C ABI remain the version used by the Dart
package. A runtime database-reopen check is required after packaging a rebuild.

## Pinned inputs

- Isar tag: `3.1.0+1`
- Isar commit: `6643d064abf22606b6c6a741ea873e4781115ef4`
- Isar source archive SHA-256:
  `e77776fd6a67e9516c8beae292bdc6010dd0c554cd8735d8bf8163ed2f96896c`
- libmdbx tag: `v0.12.4`
- libmdbx commit: `53177e483c18adf5109aed7a5895915e9798ee24`
- Rust toolchain: `1.88.0-aarch64-apple-darwin`
- Android NDK: `28.2.13676358`
- Android API level used by the C compiler: `21`
- Captured Cargo lock: `scripts/maintenance/isar_android.Cargo.lock`
- Cargo lock SHA-256:
  `83bfd3abef120b8d5e264e70fbbe96a89455d14bac738324dd50be88a05e900c`

The 2026-11-01 privacy rebuild uses
`scripts/maintenance/rebuild_isar_android.py`. It verifies the archive, checkout
and lock checksums before compilation, remaps the isolated build directory and
private home prefix in Rust source locations, and passes `-ffile-prefix-map`
and `-fdebug-prefix-map` for C sources. The NDK is exposed through a neutral
temporary-directory symlink. No runtime database source is patched.

Every Android target retains both linker arguments:

```toml
"-C", "link-arg=-Wl,--hash-style=both",
"-C", "link-arg=-Wl,-z,max-page-size=16384"
```

Builds set `ISAR_VERSION=3.1.0+1`, use Cargo `--locked`, and use the matching
NDK Clang linker for each Rust target:

| Android ABI | Rust target | NDK compiler |
|---|---|---|
| arm64-v8a | aarch64-linux-android | aarch64-linux-android21-clang |
| armeabi-v7a | armv7-linux-androideabi | armv7a-linux-androideabi21-clang |
| x86 | i686-linux-android | i686-linux-android21-clang |
| x86_64 | x86_64-linux-android | x86_64-linux-android21-clang |

The old build's Cargo lock was not retained, and the upstream Isar commit does
not contain one. The captured lock fixes all nine exact crate versions still
recoverable from the previous binaries: byteorder 1.5.0, crossbeam-channel
0.5.16, intmap 2.0.0, itoa 1.0.18, once_cell 1.21.4, serde_core 1.0.229,
serde_json 1.0.151, threadpool 1.8.1 and unicode-segmentation 1.13.3. Versions
of the remaining transitive crates cannot be proven identical to the old build.
The source/ABI/alignment checks do not replace runtime database compatibility
validation. Future rebuilds use the captured checksummed lock without updating
dependencies.

## Rebuild procedure

Check running builds, free memory and disk first. Reserve at least 5GB of free
disk, run only one build at a time, and use at most two Cargo jobs. The Rust
toolchain and Android targets must already be installed; the script does not
install or change global toolchains or credential configuration.

Download the Isar archive from the fixed GitHub commit and prepare a clean
libmdbx Git checkout whose HEAD and `v0.12.4` tag both point to the pinned
libmdbx commit above. Keep these inputs outside the build workspace. Set
`TAGSHELF_ISAR_INPUTS`, `TAGSHELF_ISAR_BUILD` and `TAGSHELF_ANDROID_NDK` to the
chosen input directory, a neutral directory below `/private/tmp`, and the
installed pinned NDK respectively. Then run:

```sh
python3 scripts/maintenance/rebuild_isar_android.py \
  --isar-archive "$TAGSHELF_ISAR_INPUTS/isar-source.tar.gz" \
  --libmdbx-dir "$TAGSHELF_ISAR_INPUTS/libmdbx-source" \
  --ndk "$TAGSHELF_ANDROID_NDK" --work-dir "$TAGSHELF_ISAR_BUILD" \
  --fetch-only

bash scripts/quiet_check.sh python3 scripts/maintenance/rebuild_isar_android.py \
  --isar-archive "$TAGSHELF_ISAR_INPUTS/isar-source.tar.gz" \
  --libmdbx-dir "$TAGSHELF_ISAR_INPUTS/libmdbx-source" \
  --ndk "$TAGSHELF_ANDROID_NDK" --work-dir "$TAGSHELF_ISAR_BUILD" \
  --install
```

The fetch step only fills the isolated public Cargo cache. Compilation uses
`--locked --offline`; a process-local Git wrapper supplies the verified local
libmdbx checkout to the upstream build script. Cargo credentials and global
configuration are not copied. All four candidates must pass validation before
installation. Original binaries remain under the build workspace's `originals`
directory, and per-target redacted logs and `validation.json` are retained there.
Omit `--install` to leave validated candidates staged without modifying this
package.

## Verified outputs

| Android ABI | SHA-256 |
|---|---|
| arm64-v8a | `fc8ba57331c06ae596a842f9b8ca80b257668f9029ebcd21d81b20b4c3f5b522` |
| armeabi-v7a | `54acaa19df2815bfd1643efb26902a0092b6c705d29e1e71ad1277211612ffd5` |
| x86 | `587bbbf77357a5fdc8836a0a519e57fd594f6731a8dffaffbe3f592914ef0523` |
| x86_64 | `e6fdd23b9f4167cb88efbaedbc6ab7c9e2b452788de3b69b70e5d8958cfdaa98` |

For all four outputs:

- every ELF `PT_LOAD` segment has `p_align=0x4000`;
- both SysV `HASH` and `GNU_HASH` tables are retained;
- the embedded Isar version is `3.1.0+1`;
- the exported dynamic-symbol name/type set exactly matches the original
  pre-rebuild 3.1.0+1 binary for the same ABI (92 symbols);
- no private macOS/Linux/Windows home-directory path remains in any binary.

The previous baseline release APK and AAB were inspected after packaging. Every bundled
native library (including Flutter and plugin libraries, not only Isar) had
`PT_LOAD` alignment of at least `0x4000`, and the APK passed
`zipalign -c -P 16 -v 4`.

Historical baseline runtime verification used the Android 15 Google APIs 16KB ARM64 system image.
The guest reported `getconf PAGE_SIZE=16384`; the release APK reached the
onboarding UI, created `default.isar`, and an in-place debug update reopened
that database without a native-loader, Isar-version, or database error.
These historical runtime results do not validate the new 2026-11-01 binaries;
repeat the APK/AAB checks and existing-database reopen check after packaging.

Run the repository gate after any dependency or binary update:

```sh
dart run scripts/maintenance/check_android_elf_alignment.dart
```
