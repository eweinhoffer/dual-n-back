// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualNBackCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "DualNBackCore", targets: ["DualNBackCore"]),
    ],
    targets: [
        .target(
            name: "DualNBackCore",
            path: "Sources/DualNBackCore",
            resources: [
                .copy("Resources/Speech"),
            ]
        ),
        .testTarget(
            name: "DualNBackCoreTests",
            dependencies: ["DualNBackCore"]
        ),
    ]
)
