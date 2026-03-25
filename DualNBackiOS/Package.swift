// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualNBackiOS",
    platforms: [
        .iOS(.v16),
    ],
    dependencies: [
        .package(path: "../DualNBackCore"),
    ],
    targets: [
        .executableTarget(
            name: "DualNBackiOS",
            dependencies: ["DualNBackCore"],
            path: "Sources/DualNBackiOS"
        ),
    ]
)
