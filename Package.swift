// swift-tools-version:5.1
import PackageDescription

let package = Package(
  name: "Cirrus",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Cirrus",
      targets: ["Cirrus"]
    ),
    .library(
      name: "CloudKitCodable",
      targets: ["CloudKitCodable"]
    ),
  ],
  targets: [
    .target(
      name: "Cirrus",
      dependencies: [
        "CKRecordCoder",
        "CloudKitCodable",
      ]
    ),
    .target(
      name: "CKRecordCoder",
      dependencies: [
        "CloudKitCodable"
      ]
    ),
    .target(
      name: "CloudKitCodable"
    ),
    .testTarget(
      name: "CKRecordCoderTests",
      dependencies: ["CKRecordCoder"]
    ),
  ]
)
