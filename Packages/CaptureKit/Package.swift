// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaptureKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CaptureKit", targets: ["CaptureKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "CaptureKit",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]
        ),
        .testTarget(
            name: "CaptureKitTests",
            dependencies: ["CaptureKit"],
            resources: [.copy("Fixtures/obsidian.json")]
        ),
    ]
)
