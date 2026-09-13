// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "Kit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AWSchema", targets: ["AWSchema"]),
        .library(name: "AWKit", targets: ["AWKit"]),
        .library(name: "AWPreview", targets: ["AWPreview"])
    ],
    targets: [
        .target(name: "AWSchema"),
        .target(name: "AWKit", dependencies: ["AWSchema"]),
        .target(name: "AWPreview", dependencies: ["AWKit", "AWSchema"]),
        .testTarget(name: "AWSchemaTests", dependencies: ["AWSchema"]),
        .testTarget(name: "AWKitTests", dependencies: ["AWKit", "AWPreview"])
    ],
    swiftLanguageModes: [.v5]
)
