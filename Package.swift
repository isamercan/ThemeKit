// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThemeKit",
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
            name: "ThemeKit",
            targets: ["ThemeKit"]
        ),
        // Optional add-on — pulls in Lottie for vector (After Effects / JSON)
        // animations. Import ONLY if you need Lottie; the core stays dependency-free.
        .library(
            name: "ThemeKitLottie",
            targets: ["ThemeKitLottie"]
        ),
    ],
    dependencies: [
        // Used solely by the ThemeKitLottie add-on target.
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0"),
        // TEST-ONLY: visual regression (snapshot) testing. Never linked into the
        // shipped library — only the test target depends on it, so consumers
        // still get a zero-dependency core.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
        // DOC-ONLY: DocC build-tool plugin (generate-documentation /
        // preview-documentation). A command plugin — adds no target dependency,
        // so the shipped library stays dependency-free.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "ThemeKit",
            resources: [
                .process("Resources"),
            ]
        ),
        // Lottie add-on: depends on the core + Lottie. Keeps Lottie out of the core
        // dependency graph so consumers who don't need it never download it.
        .target(
            name: "ThemeKitLottie",
            dependencies: [
                "ThemeKit",
                .product(name: "Lottie", package: "lottie-ios"),
            ]
        ),
        .testTarget(
            name: "ThemeKitTests",
            dependencies: [
                "ThemeKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
