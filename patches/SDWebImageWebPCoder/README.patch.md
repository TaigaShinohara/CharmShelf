# SDWebImageWebPCoder 0.15.0 compatibility patch

Official archive: https://codeload.github.com/SDWebImage/SDWebImageWebPCoder/tar.gz/refs/tags/0.15.0

Archive SHA-256: `b8689b3874bde692ec45d4dcc7ab551dbabb646dc507206f966c16b3da4754de`

The existing local SwiftPM manifest retains tools 5.9, iOS 12, exact SDWebImage
5.21.7/libwebp 1.5.0 and its source/header integration. The existing podspec patch
retains inherited header search paths. Platform minima and dependencies are not
changed by this warning fix. Unused upstream examples, asset placeholders and the
legacy module Info.plist are not part of this existing SwiftPM checkout.

When the deployment minimum guarantees ICCData (iOS/tvOS 10, macOS 10.12,
watchOS 3, Catalyst or visionOS), compile the already-used modern branch directly.
The original runtime availability and ICCProfile fallback remain for the podspec's
older OS minima. ICC bytes are still copied before releasing the WebP iterator;
non-RGB profiles are released and fall back to retained device RGB as before.
Create-rule ownership, null fallback and RGB filtering are unchanged.

The warning is not disabled and deprecated names are not replaced by raw symbols.
Actual source object compilation at the SwiftPM minimum iOS 12 and app iOS 15,
and a full fresh Runner build, are recorded in
[the compatibility report](../../docs/IOS_DEPENDENCY_WARNINGS_20261022.md).
Legacy podspec platform builds and real image rendering are separate checks.
