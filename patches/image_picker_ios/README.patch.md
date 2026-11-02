# image_picker_ios 0.8.13+13 non-frozen enum compatibility

- Official metadata: <https://pub.dev/api/packages/image_picker_ios/versions/0.8.13%2B13>
- Archive: <https://pub.dev/api/archives/image_picker_ios-0.8.13%2B13.tar.gz>
- Archive SHA-256: `57255225702ace8c81b8d92c1de6a04b60ee9befa6dab242b10a7612116886fd`.
- Previous Objective-C reference: <https://pub.dev/api/archives/image_picker_ios-0.8.13%2B12.tar.gz>
  SHA-256: `592e5cfed81d73c2784bcaa04db9d06b19371faf036f2afa7f650452025db180`.

The official Dart sources, iOS Swift/Objective-C implementation, resources,
pubspec, podspec, SwiftPM manifest and license are retained. The SwiftPM package
keeps both `image_picker_ios` and `image_picker_ios_objc` targets, its existing
dependency edge and iOS 15 minimum. No example, generated cache or independent
library lock is vendored.

The only implementation change is `@unknown default: return .rear` in
`ImagePickerPlugin.swift`'s `cameraDevice(for:)` switch. The imported Objective-C
`FLTSourceCamera` enum is non-frozen in Swift. This handles its unknown future
values explicitly instead of leaving a Swift exhaustiveness warning.

The previous +12 Objective-C `cameraDeviceForSource:` has two switch cases:
front maps to Front and rear maps to Rear. It has **no** default or trailing
return for unknown values. Consequently this patch preserves the two supported
camera choices; the rear fallback for an unknown future value is newly defined,
not claimed to be the previous implementation's behavior. The public Dart camera
API currently exposes only front and rear. Camera availability, permission
requests, PHPicker, Flutter channels and public API are unchanged.

`scripts/maintenance/path_override_upstream_hashes.json` records all Dart and
`ios/image_picker_ios` files against the official archive, with the sole source
patch's upstream and resulting hashes separated. Validate provenance and the
SwiftPM two-target graph, then build the iOS app without codesigning and check
that this switch's non-frozen-enum warning is absent. Existing synthetic native
picker QA can cover gallery/cancellation integration; it does not verify a real
camera. Physical-device camera behavior remains a separate verification.
