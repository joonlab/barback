// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Barback",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Barback",
            path: "Sources/Barback"
        )
    ]
)
