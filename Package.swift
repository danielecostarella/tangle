// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tangle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TangleCore", targets: ["TangleCore"]),
        .executable(name: "TangleGUI", targets: ["TangleGUI"]),
        .executable(name: "tangle", targets: ["tangle-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(name: "TangleCore"),
        .executableTarget(
            name: "TangleGUI",
            dependencies: ["TangleCore"]
        ),
        .executableTarget(
            name: "tangle-cli",
            dependencies: [
                "TangleCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "TangleCoreTests",
            dependencies: ["TangleCore"]
        )
    ]
)
