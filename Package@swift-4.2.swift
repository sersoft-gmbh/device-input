// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "DeviceInput",
    products: [
      .library(name: "DeviceInput", targets: ["DeviceInput"]),
    ],
    dependencies: [
      // Dependencies declare other packages that this package depends on.
      // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
      // Targets are the basic building blocks of a package. A target can define a module or a test suite.
      // Targets can depend on other targets in this package, and on products in packages which this package depends on.
      .target(name: "Clibgrabdevice", dependencies: []),
      .target(name: "DeviceInput", dependencies: ["Clibgrabdevice"]),
      .testTarget(name: "DeviceInputTests", dependencies: ["DeviceInput"]),
    ]
)
