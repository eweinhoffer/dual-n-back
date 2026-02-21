// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftDualNBackPrototype",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SwiftDualNBackPrototype", targets: ["SwiftDualNBackPrototype"]),
    ],
    targets: [
        .executableTarget(
            name: "SwiftDualNBackPrototype",
            path: "Sources/SwiftDualNBackPrototype",
            exclude: ["Assets.xcassets"]
        ),
    ]
)
