// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "downloadsfolder",
  platforms: [.iOS("12.0")],
  products: [.library(name: "downloadsfolder", targets: ["downloadsfolder"])],
  targets: [.target(name: "downloadsfolder")]
)
