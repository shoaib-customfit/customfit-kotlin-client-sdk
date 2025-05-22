// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "CustomFitSwiftSDK",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "CustomFitSwiftSDK",
            targets: ["CustomFitSwiftSDK"]),
        .executable(
            name: "DemoApp",
            targets: ["DemoApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CustomFitSwiftSDK",
            dependencies: [],
            path: "Sources"),
        .target(
            name: "DemoApp",
            dependencies: ["CustomFitSwiftSDK"],
            path: "DemoApp"),
        .testTarget(
            name: "CustomFitSwiftSDKTests",
            dependencies: ["CustomFitSwiftSDK"]),
    ]
)