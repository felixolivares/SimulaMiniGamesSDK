// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimulaMiniGameSDK",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "SimulaMiniGameSDK", targets: ["SimulaMiniGameSDK"]),
    ],
    targets: [
        .target(
            name: "SimulaMiniGameSDK",
            path: "Sources/SimulaMiniGameSDK"
        ),
    ]
)
