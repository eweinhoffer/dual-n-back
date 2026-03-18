// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualNBackiOS",
    platforms: [
        .iOS(.v16),
    ],
    targets: [
        .executableTarget(
            name: "DualNBackiOS",
            path: "Sources/DualNBackiOS"
        ),
    ]
)
