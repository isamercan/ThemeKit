// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GlobalComponents-ios",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GlobalComponents-ios",
            targets: ["GlobalComponents-ios"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GlobalComponents-ios"
        ),
        .testTarget(
            name: "GlobalComponents-iosTests",
            dependencies: ["GlobalComponents-ios"]
        ),
    ]
)
