// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "isar_flutter_libs",
  platforms: [.iOS("12.0")],
  products: [
    .library(name: "isar-flutter-libs", targets: ["isar_flutter_libs"]),
  ],
  targets: [
    .binaryTarget(name: "isar", path: "isar.xcframework"),
    .target(
      name: "isar_flutter_libs",
      dependencies: ["isar"],
      path: "Sources/isar_flutter_libs",
      publicHeadersPath: "."
    ),
  ]
)
