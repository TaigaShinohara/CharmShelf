// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "secure_application",
  platforms: [.iOS("13.0")],
  products: [.library(name: "secure-application", targets: ["secure_application"])],
  targets: [.target(name: "secure_application")]
)
