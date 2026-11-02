// swift-tools-version: 5.9

import PackageDescription

// TagShelf requests notifications, camera, and photo-library permissions only.
let permissionDefines: [CSetting] = [
  .define("PERMISSION_EVENTS", to: "0"),
  .define("PERMISSION_EVENTS_FULL_ACCESS", to: "0"),
  .define("PERMISSION_REMINDERS", to: "0"),
  .define("PERMISSION_CONTACTS", to: "0"),
  .define("PERMISSION_CAMERA", to: "1"),
  .define("PERMISSION_MICROPHONE", to: "0"),
  .define("PERMISSION_SPEECH_RECOGNIZER", to: "0"),
  .define("PERMISSION_PHOTOS", to: "1"),
  .define("PERMISSION_PHOTOS_ADD_ONLY", to: "1"),
  .define("PERMISSION_LOCATION", to: "0"),
  .define("PERMISSION_LOCATION_WHENINUSE", to: "0"),
  .define("PERMISSION_LOCATION_ALWAYS", to: "0"),
  .define("PERMISSION_NOTIFICATIONS", to: "1"),
  .define("PERMISSION_MEDIA_LIBRARY", to: "0"),
  .define("PERMISSION_SENSORS", to: "0"),
  .define("PERMISSION_BLUETOOTH", to: "0"),
  .define("PERMISSION_APP_TRACKING_TRANSPARENCY", to: "0"),
  .define("PERMISSION_CRITICAL_ALERTS", to: "0"),
  .define("PERMISSION_ASSISTANT", to: "0"),
]

let package = Package(
  name: "permission_handler_apple",
  platforms: [.iOS("12.0")],
  products: [
    .library(name: "permission-handler-apple", targets: ["permission_handler_apple"]),
  ],
  targets: [
    .target(
      name: "permission_handler_apple",
      path: "Sources/permission_handler_apple",
      resources: [.process("PrivacyInfo.xcprivacy")],
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath("."),
        .headerSearchPath("strategies"),
        .headerSearchPath("util"),
        .headerSearchPath("include/permission_handler_apple"),
      ] + permissionDefines
    ),
  ]
)
