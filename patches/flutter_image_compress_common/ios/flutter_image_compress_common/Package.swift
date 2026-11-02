// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "flutter_image_compress_common",
  platforms: [.iOS("12.0")],
  products: [
    .library(
      name: "flutter-image-compress-common",
      targets: ["flutter_image_compress_common"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/Mantle/Mantle.git", exact: "2.2.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImage.git", exact: "5.21.7"),
    // Flutter exposes this package through the generated .packages directory.
    .package(path: "../../../../../../patches/SDWebImageWebPCoder"),
  ],
  targets: [
    .target(
      name: "flutter_image_compress_common",
      dependencies: [
        .product(name: "Mantle", package: "Mantle"),
        .product(name: "SDWebImage", package: "SDWebImage"),
        .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder"),
      ],
      path: "Sources/flutter_image_compress_common",
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath("include/flutter_image_compress_common"),
      ]
    ),
  ]
)
