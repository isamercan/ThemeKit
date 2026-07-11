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
        // Token-only core — theme engine + design tokens + `@Environment(\.theme)`,
        // with NO component catalog. Adopt this alone for a minimal theme layer; the
        // full `ThemeKit` re-exports it, so existing consumers need no change.
        .library(
            name: "ThemeKitCore",
            targets: ["ThemeKitCore"]
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
        // Optional domain edition — the flight/booking component family (#229
        // modular direction). Depends on the full `ThemeKit` catalog and WRAPS its
        // neutral primitives into booking-flow organisms. NO trait: the edition has
        // zero external deps, so a plain optional product already gives perfect
        // opt-in — a consumer who doesn't add `ThemeKitTravel` to a target compiles
        // nothing from it and downloads the same package they already download.
        .library(
            name: "ThemeKitTravel",
            targets: ["ThemeKitTravel"]
        ),
    ],
    // Opt-in traits keep the core resolution truly dependency-free. The DEFAULT
    // set is EMPTY, so a plain `.package(url: "…ThemeKit.git")` resolves the core
    // ONLY — Lottie, Almanac and HorizonCalendar are never fetched. Enable a trait
    // to pull the matching add-on's dependency at resolution time:
    //   .package(url: "…ThemeKit.git", from: "…", traits: ["Lottie"])    // + lottie-ios
    //   .package(url: "…ThemeKit.git", from: "…", traits: ["Calendar"])  // + Almanac (iOS)
    // The add-on SOURCES are `#if canImport(...)` guarded, so with a trait off the
    // add-on module simply compiles to nothing rather than failing to build.
    traits: [
        .trait(name: "Lottie", description: "Enable the ThemeKitLottie add-on (pulls lottie-ios)."),
        .trait(name: "Calendar", description: "Enable the ThemeKitCalendar add-on (pulls Almanac / HorizonCalendar, iOS-only)."),
        .default(enabledTraits: []),
    ],
    dependencies: [
        // Used solely by the ThemeKitLottie add-on target (behind the "Lottie" trait).
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
        // Token-only core: theme engine, design tokens, `@Environment(\.theme)`,
        // presets, generator, and the theme resource bundle. Zero components, zero
        // third-party deps. Everything else in the package builds on top of this.
        .target(
            name: "ThemeKitCore",
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
        // Full catalog: all components, built on ThemeKitCore. Re-exports the core
        // (`@_exported import ThemeKitCore` in CoreExports.swift), so a plain
        // `import ThemeKit` still surfaces every token and theme symbol unchanged.
        .target(
            name: "ThemeKit",
            dependencies: ["ThemeKitCore"],
            swiftSettings: [
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
                .product(name: "Lottie", package: "lottie-ios", condition: .when(traits: ["Lottie"])),
            ]
        ),
        // Calendar add-on: core + Almanac. The Almanac product is linked ONLY on
        // iOS (it's UIKit/HorizonCalendar-based); the sources are `#if os(iOS)`
        // guarded so the target compiles to an empty module elsewhere.
        .target(
            name: "ThemeKitCalendar",
            dependencies: [
                "ThemeKit",
                .product(name: "Almanac", package: "Almanac", condition: .when(platforms: [.iOS], traits: ["Calendar"])),
            ]
        ),
        // Domain edition: the flight/booking family, built on the full catalog.
        // Composition, not forking — it depends on `ThemeKit` (not just Core) so it
        // can wrap `TextInput`, `Select`, `DateField`, `FormValidator`, … rather than
        // re-implement the field family. One-way dependency: Core ← ThemeKit ← Travel;
        // nothing in `ThemeKit` may name a `ThemeKitTravel` type. No `@_exported`:
        // consumers import both modules explicitly, mirroring `ThemeKitCalendar`.
        .target(
            name: "ThemeKitTravel",
            dependencies: ["ThemeKit"],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "ThemeKitTests",
            dependencies: [
                "ThemeKit",
                // A couple of tests reach engine internals now living in Core
                // (`Bundle.themeKit`, `ColorContrast`) via `@testable import ThemeKitCore`.
                "ThemeKitCore",
                // The edition rides the same snapshot/a11y/RTL harness (ADR-F1).
                "ThemeKitTravel",
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
