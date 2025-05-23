// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CustomFitDemoApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    dependencies: [
        // Local dependency to the CustomFit Swift SDK
        .package(path: "../customfit-swift-client-sdk")
    ],
    targets: [
        .executableTarget(
            name: "CustomFitDemoApp",
            dependencies: [
                .product(name: "CustomFitSwiftSDK", package: "customfit-swift-client-sdk")
            ],
            path: "Sources"
        ),
    ]
) 