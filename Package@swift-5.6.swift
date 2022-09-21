// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let package = Package(
    name: "device-input",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        .library(
            name: "DeviceInput",
            targets: ["DeviceInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", from: "1.0.0"),
        .package(url: "https://github.com/sersoft-gmbh/swift-filestreamer.git", .upToNextMinor(from: "0.5.0")),
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
            ]
        ),
        .testTarget(
            name: "DeviceInputTests",
            dependencies: [
                "CInput",
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "FileStreamer", package: "swift-filestreamer"),
                "DeviceInput",
            ]),
    ]
)

if ProcessInfo.processInfo.environment["ENABLE_DOCC_SUPPORT"] == "1" {
    package.dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}
