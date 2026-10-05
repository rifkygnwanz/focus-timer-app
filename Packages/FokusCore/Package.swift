// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FokusCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FokusCore", targets: ["FokusCore"]),
    ],
    targets: [
        .target(
            name: "FokusCore",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "FokusCoreTests",
            dependencies: ["FokusCore"]
        ),
    ]
)
