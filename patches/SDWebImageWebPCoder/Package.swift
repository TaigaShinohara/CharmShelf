// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SDWebImageWebPCoder",
  platforms: [.iOS("12.0")],
  products: [
    .library(name: "SDWebImageWebPCoder", targets: ["SDWebImageWebPCoder"]),
  ],
  dependencies: [
    .package(url: "https://github.com/SDWebImage/SDWebImage.git", exact: "5.21.7"),
    .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", exact: "1.5.0"),
  ],
  targets: [
    .target(
      name: "SDWebImageWebPCoder",
      dependencies: [
        "SDWebImage",
        .product(name: "libwebp", package: "libwebp-Xcode"),
      ],
      path: ".",
      sources: ["SDWebImageWebPCoder/Classes"],
      publicHeadersPath: "SDWebImageWebPCoder/Classes",
      cSettings: [
        .headerSearchPath("SDWebImageWebPCoder/Private"),
        .define("SD_WEBP", to: "1"),
      ]
    ),
  ]
)
