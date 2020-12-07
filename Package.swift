// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "device-input",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        .library(name: "DeviceInput", targets: ["DeviceInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", .upToNextMinor(from: "0.0.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "Cinput"),
        .target(
            name: "DeviceInput",
            dependencies: [
                "Cinput",
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(name: "DeviceInputTests", dependencies: ["DeviceInput"]),
    ]
)
