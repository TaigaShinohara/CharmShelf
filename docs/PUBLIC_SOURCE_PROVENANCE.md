# Public source provenance

CharmShelf starts from the owner-authorized TagShelf source snapshot `a3a7fc7f331fdd6c17753188d11fd3e23a7ae628` (2026-11-02). Private Git history, personal planning and distribution records, editor state, credentials and old verification artifacts are not included. The original project copyright remains in LICENSE; third-party notices and patch provenance remain under their original licenses.

The Dart package remains `private_shelf` and native bridge namespaces remain compatible. The Android application ID is `com.tsmusic.privateshelf.opensource`; the Apple bundle identifier is `org.charmshelf.opensource`. Shared legacy folder checks target `Documents/CharmShelf`, not the original application's folder. This fork does not automatically migrate TagShelf installations. Explicit backup import remains available and the existing backup format identifier is preserved.

Public sample media and launcher graphics are generated from original geometry and synthesized waveforms by `tool/public_assets/generate_assets.py`; no original AI music or unknown sound is included. Existing first-party functional SVGs and procedural UI sounds remain MIT-licensed. Store purchases and store review prompts are disabled by default; enabling store purchases requires configuring your own application and products and the explicit build define `CHARMSHELF_STORE_PURCHASES=true`.
