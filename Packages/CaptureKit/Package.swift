// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaptureKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CaptureKit", targets: ["CaptureKit"]),
    ],
    targets: [
        .target(name: "CaptureKit"),
        .testTarget(
            name: "CaptureKitTests",
            dependencies: ["CaptureKit"],
            resources: [.copy("Fixtures/obsidian.json")]
        ),
    ]
)
