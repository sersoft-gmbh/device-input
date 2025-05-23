// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: Array<SwiftSetting> = [
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableExperimentalFeature("StrictConcurrency"),
    .enableExperimentalFeature("GlobalConcurrency"),
    .enableExperimentalFeature("AccessLevelOnImport"),
]

let package = Package(
    name: "device-input",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "DeviceInput",
            targets: ["DeviceInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
        .package(url: "https://github.com/sersoft-gmbh/swift-filestreamer", .upToNextMinor(from: "0.8.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "CInput"),
        .target(
            name: "DeviceInput",
            dependencies: [
                "CInput",
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "FileStreamer", package: "swift-filestreamer"),
            ],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "DeviceInputTests",
            dependencies: [
                "CInput",
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "FileStreamer", package: "swift-filestreamer"),
                "DeviceInput",
            ],
            swiftSettings: swiftSettings),
    ]
)
