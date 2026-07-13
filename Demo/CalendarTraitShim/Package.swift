// swift-tools-version: 6.2
import PackageDescription

// Thin wrapper package that forces ThemeKit's "Calendar" trait ON for the Demo app.
//
// A standard `.xcodeproj` app has no app-level Package.swift, so — even in Xcode 26 —
// it cannot *persist* a package-trait selection: the UI toggle lives in DerivedData /
// workspace state and is dropped whenever packages re-resolve (e.g. a branch switch).
// The officially recommended workaround (Apple / SwiftPM) is a thin local package that
// enables the trait in its own manifest. The Demo depends on this package, so SwiftPM
// resolves the root ThemeKit package with `Calendar` on (traits union across all edges)
// and links Almanac into ThemeKitCalendar. Zero effect on public consumers of ThemeKit —
// the root package's default traits stay empty (dependency-free core).
let package = Package(
    name: "DemoCalendarSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DemoCalendarSupport", targets: ["DemoCalendarSupport"]),
    ],
    dependencies: [
        .package(name: "ThemeKit", path: "../..", traits: ["Calendar"]),
    ],
    targets: [
        .target(
            name: "DemoCalendarSupport",
            dependencies: [
                .product(name: "ThemeKitCalendar", package: "ThemeKit"),
            ]
        ),
    ]
)
