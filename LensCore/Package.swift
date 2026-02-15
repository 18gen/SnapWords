// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LensCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "LensCore", targets: ["LensCore"]),
    ],
    targets: [
        .target(
            name: "LensCore",
            path: "Sources/LensCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LensCoreTests",
            dependencies: ["LensCore"],
            path: "Tests/LensCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
