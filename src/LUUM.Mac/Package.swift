// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "LUUMMac",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "luum",
            targets: ["luum"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "luum",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/luum"
        ),
        .testTarget(
            name: "luumTests",
            dependencies: ["luum"],
            path: "Tests/luumTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
