// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JPNetworking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "JPNetworking", targets: ["JPNetworking"]),
    ],
    targets: [
        .target(name: "JPNetworking"),
        .testTarget(
            name: "JPNetworkingTests",
            dependencies: ["JPNetworking"]
        ),
    ]
)
