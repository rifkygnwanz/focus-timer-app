// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FokusUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FokusUI", targets: ["FokusUI"]),
    ],
    dependencies: [
        .package(path: "../FokusCore"),
    ],
    targets: [
        .target(
            name: "FokusUI",
            dependencies: ["FokusCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
