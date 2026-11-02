// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "open_file_ios",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "open-file-ios", targets: ["open_file_ios"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "open_file_ios",
      dependencies: [],
      cSettings: [
        .headerSearchPath("include/open_file_ios")
      ]
    )
  ]
)
