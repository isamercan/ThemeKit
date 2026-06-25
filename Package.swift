// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GlobalUIComponents",
    // Source/development language for the bundled String Catalog. Shipped default
    // strings are English; consumers can add their own localizations, and every
    // user-facing string also remains overridable via API parameters.
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Core library — ZERO third-party dependencies (native only).
        .library(
            name: "GlobalUIComponents",
            targets: ["GlobalUIComponents"]
        ),
        // Optional add-on — pulls in Lottie for vector (After Effects / JSON)
        // animations. Import ONLY if you need Lottie; the core stays dependency-free.
        .library(
            name: "GlobalUIComponentsLottie",
            targets: ["GlobalUIComponentsLottie"]
        ),
    ],
    dependencies: [
        // Used solely by the GlobalUIComponentsLottie add-on target.
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "GlobalUIComponents",
            resources: [
                .process("Resources"),
            ]
        ),
        // Lottie add-on: depends on the core + Lottie. Keeps Lottie out of the core
        // dependency graph so consumers who don't need it never download it.
        .target(
            name: "GlobalUIComponentsLottie",
            dependencies: [
                "GlobalUIComponents",
                .product(name: "Lottie", package: "lottie-ios"),
            ]
        ),
        .testTarget(
            name: "GlobalUIComponentsTests",
            dependencies: ["GlobalUIComponents"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
