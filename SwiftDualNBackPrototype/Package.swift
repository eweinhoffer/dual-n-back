// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftDualNBackPrototype",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SwiftDualNBackPrototype", targets: ["SwiftDualNBackPrototype"]),
    ],
    dependencies: [
        .package(path: "../DualNBackCore"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftDualNBackPrototype",
            dependencies: ["DualNBackCore"],
            path: "Sources/SwiftDualNBackPrototype",
            exclude: ["Assets.xcassets"]
        ),
    ]
)
