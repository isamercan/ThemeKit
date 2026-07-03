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
        // Optional add-on — a token-bound date-range calendar, built on Almanac
        // (→ HorizonCalendar, iOS-only). Import ONLY if you need it; the core stays
        // dependency-free and cross-platform.
        .library(
            name: "ThemeKitCalendar",
            targets: ["ThemeKitCalendar"]
        ),
    ],
    dependencies: [
        // Used solely by the ThemeKitLottie add-on target.
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0"),
        // Used solely by the ThemeKitCalendar add-on target (iOS-only; pulls
        // HorizonCalendar transitively). A conditional dependency keeps it off
        // macOS builds, so the core package still builds everywhere.
        .package(url: "https://github.com/isamercan/Almanac.git", from: "0.2.0"),
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
            ],
            swiftSettings: [
                // Swift 6.2 upcoming behaviours, adopted early:
                // nonisolated async stays on the caller's actor (no hidden hops),
                // and a @MainActor type's protocol conformances infer @MainActor.
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
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
        // Calendar add-on: core + Almanac. The Almanac product is linked ONLY on
        // iOS (it's UIKit/HorizonCalendar-based); the sources are `#if os(iOS)`
        // guarded so the target compiles to an empty module elsewhere.
        .target(
            name: "ThemeKitCalendar",
            dependencies: [
                "ThemeKit",
                .product(name: "Almanac", package: "Almanac", condition: .when(platforms: [.iOS])),
            ]
        ),
        .testTarget(
            name: "ThemeKitTests",
            dependencies: [
                "ThemeKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        // iOS-only: the sources are `#if os(iOS)` guarded, so on macOS this builds
        // (and passes) as an empty test target — the calendar bridge is exercised
        // on the iOS lane.
        .testTarget(
            name: "ThemeKitCalendarTests",
            dependencies: ["ThemeKitCalendar", "ThemeKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
