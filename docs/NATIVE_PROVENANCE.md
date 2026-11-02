# Native dependency provenance

This public source snapshot retains the upstream notices and the existing `Copyright (c) 2026 Private Shelf Project` notice. The public repository contains no private repository history. First-party code is MIT; native dependencies keep the licenses listed in the public notice bundle.

## Isar and libmdbx

The retained native database libraries come from the project's Isar 3.1.0+1 build. The runtime database source is unchanged; Android linker alignment and compiler path remapping were adjusted for 16KB page sizes and neutral build paths.

- Isar commit: `6643d064abf22606b6c6a741ea873e4781115ef4` (3.1.0+1).
- Isar source archive SHA-256: `e77776fd6a67e9516c8beae292bdc6010dd0c554cd8735d8bf8163ed2f96896c`.
- libmdbx commit: `53177e483c18adf5109aed7a5895915e9798ee24` (v0.12.4).
- Rust toolchain used for the Android build: 1.88.0; Android NDK: 28.2.13676358; Android API level: 21.
- Captured build lock: `scripts/maintenance/isar_android.Cargo.lock`.
- Lock SHA-256: `83bfd3abef120b8d5e264e70fbbe96a89455d14bac738324dd50be88a05e900c`.

Isar's root license is Apache-2.0. libmdbx is separately covered by OpenLDAP Public License 2.8; its full `LICENSE` and `COPYRIGHT` are included in the native notice snapshot. Isar's Apache license does not replace libmdbx's license.

The captured lock contains 97 workspace/registry packages, including 94 registry crates and the local isar, isar-core, and mdbx-sys crates. This is a conservative inventory of the retained build graph, including build-only and platform-specific packages. It is not a claim that every lock entry is linked into every binary. Original `.crate` archive checksums are verified against the captured Cargo lock; each copied license and package manifest is then compared against that original archive while exporting the native notices.

Some upstream crates omit a standalone license file. jni-sys-macros, ndk-context, winapi target crates, and malloc_buf are supplemented from the upstream license files retained under `assets/licenses/native_inputs`; their exact source URLs are recorded there. The old block, objc-foundation, and objc_id packages declare MIT and Steven Sheldon as author in the distributed Cargo manifest but ship no standalone license file. Their manifest attribution and standard MIT terms are included with an explicit note, without inventing a copyright year or claiming an upstream license file was found.

The native notices preserve upstream copyright statements and license choices. First-party notices do not replace upstream terms, and an updated lock requires a fresh notice review.

## Unchanged upstream Linux and Windows binaries

The Linux `libisar.so` and Windows `isar.dll` retain source-location strings from the upstream build environment. They were compared byte-for-byte with both the local public package cache and the original [isar_flutter_libs 3.1.0+1 pub.dev archive](https://pub.dev/api/archives/isar_flutter_libs-3.1.0%2B1.tar.gz). The complete archive hash was independently verified against pub.dev's version metadata.

- Official archive SHA-256: `bc6768cc4b9c61aabff77152e7f33b4b17d2fc93134f7af1c3dd51500fe8d5e8`.
- Linux binary SHA-256: `7dc70df7a2fbf63cd552eca36708b6deeb68cbd2aa270c1e201215e0bfc38ef1`.
- Windows binary SHA-256: `5e67863f188c5f9681a37f84f2eb942eaf702509d3f994c0344d5049ebc9e48f`.

Both files exactly match the official upstream distribution, and checks for the local snapshot builder's home/workspace markers were negative. The upstream location strings are retained unchanged; the files were neither stripped nor rebuilt for this public snapshot. Their exact strings are intentionally omitted from this document. The structured comparison evidence is [native_binary_provenance.json](../assets/licenses/native_binary_provenance.json). Linux/Windows runtime behavior remains unverified.

## PDFium

The public application uses pdfrx/pdfium_dart rather than Syncfusion. The resolved pdfium_dart 0.4.1 hook downloads the non-V8 PDFium binary release `chromium/8125` from bblanchon/pdfium-binaries. Its hook extracts the native library alone, so the public app independently retains the binary distribution's full `LICENSE` and all 21 files in its `licenses/` directory.

- [Android notice source archive](https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/8125/pdfium-android-arm64.tgz).
- Android archive SHA-256: `0495e57163429937caaee1bdd9b07924a7098dbd51d1b97645d124e349f097b4`.
- [Matching Darwin XCFramework release](https://github.com/espresso3389/pdfium-xcframework/releases/tag/v158.0.8125.0-20261029-150241).
- Darwin archive SHA-256: `4e83df9e096b98963070a91e1c8fe7252d5c3a80d505e8acfda3f18ac904230d`.

The Darwin archive does not include standalone notices. Its package declares the same chromium/8125 source revision, so the corresponding upstream PDFium notice set accompanies the Darwin binary too. This notice set includes PDFium's bundled ICU, FreeType, OpenJPEG, JPEG, PNG, zlib, color-management and other third-party components, each retaining its own terms. The original FreeType notice uses a legacy encoding; its decoded text and original byte checksum/encoding are retained in the input snapshot.

If the PDFium release changes, extract the complete notice set from that exact binary release, retain its archive hash, update `assets/licenses/native_inputs/pdfium-android.json`, and regenerate the notices. Rechecking the Dart wrapper's MIT license alone is insufficient for a native binary update.

## iOS native plugins and SwiftPM

`assets/licenses/ios_native_licenses.json` is reconstructed from the current resolved iOS native plugin graph, plus the retained Mantle, SDWebImage, SDWebImageWebPCoder, and libwebp notices used by image compression. Removed Syncfusion entries are excluded. `scripts/maintenance/export_ios_licenses.py` can additionally compare the native notices against resolved SwiftPM checkouts when an iOS build is available.

## Reproduction

The committed notice files are ordinary public build inputs; building the app does not need private credentials or the original native build directory.

To re-export native notices with Python 3.11 or later after preparing the exact source commits, captured Cargo lock, and Cargo registry cache, run:

```sh
python3 scripts/maintenance/export_native_notices.py \
  --isar-source /path/to/pinned-isar-source \
  --cargo-cache /path/to/isolated-cargo-home \
  --libmdbx-source /path/to/pinned-libmdbx-source
```

The command is offline and does not start a build. Add `--check` to compare against the retained snapshot. The paths above are placeholders, not machine-specific settings. Source/checksum metadata is retained in `assets/licenses/native_notices.json`; local paths and logs are not exported.

After `flutter pub get`, aggregate the current Dart, retained vendored source, SwiftPM, and native texts:

```sh
python3 scripts/maintenance/export_public_notices.py
python3 scripts/maintenance/export_public_notices.py --check
```

The aggregate is `assets/licenses/third_party_notices.json`; `THIRD_PARTY_NOTICES.md` is its component/source index. Keep both the full texts and applicable source-level license files when redistributing. Native runtime compatibility, signing, real-device behavior, and license provenance are distinct verification steps.
