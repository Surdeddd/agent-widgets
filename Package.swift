// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "agent-widgets",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "aw", targets: ["aw"])],
    dependencies: [
        .package(path: "Kit"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.12.1")
    ],
    targets: [
        .target(name: "AWCore", dependencies: [.product(name: "AWSchema", package: "Kit")]),
        .target(name: "AWMCP", dependencies: ["AWCore", .product(name: "MCP", package: "swift-sdk")]),
        .executableTarget(
            name: "aw",
            dependencies: [
                "AWCore",
                "AWMCP",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(name: "AWCoreTests", dependencies: ["AWCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
