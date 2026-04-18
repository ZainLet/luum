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
    targets: [
        .executableTarget(
            name: "luum",
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
