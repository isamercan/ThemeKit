import XCTest
@testable import ThemeKit
@testable import ThemeKitCore

final class DesignCatalogTests: XCTestCase {

    func testBundledCatalogIsDiscoverable() {
        let specs = DesignSpecCatalog.bundled()
        XCTAssertFalse(specs.isEmpty, "No bundled *.design.md resources were found in Bundle.module")
        // Unique ids, non-empty titles.
        XCTAssertEqual(Set(specs.map(\.id)).count, specs.count)
        for spec in specs {
            XCTAssertFalse(spec.title.isEmpty, "\(spec.id) has an empty title")
            if case .bundled = spec.source {} else {
                XCTFail("\(spec.id) is not marked as bundled")
            }
        }
    }

    func testEveryBundledSpecParsesHighConfidence() {
        // Proves the fenced ```themekit blocks are valid AND the resources are
        // discoverable end-to-end.
        let specs = DesignSpecCatalog.bundled()
        XCTAssertFalse(specs.isEmpty)
        for spec in specs {
            let result = DesignMode.parse(spec)
            XCTAssertEqual(result.confidence, .high, "\(spec.id) did not parse at high confidence")
            XCTAssertEqual(result.config.primaryHex.count, 6, "\(spec.id) has a malformed primary hex")
        }
    }

    func testBundledLookupById() {
        let specs = DesignSpecCatalog.bundled()
        let first = specs.first!
        XCTAssertEqual(DesignSpecCatalog.bundled(id: first.id)?.id, first.id)
        XCTAssertNil(DesignSpecCatalog.bundled(id: "does-not-exist"))
    }

    func testPastedSpec() {
        let spec = DesignSpecCatalog.pasted("# Pasted\nprimary #abcdef")
        XCTAssertEqual(spec.source, .pasted)
        XCTAssertEqual(spec.title, "Pasted")
        XCTAssertEqual(DesignMode.parse(spec).config.primaryHex, "abcdef")
    }

    func testRemoteRejectsNonHTTPS() async {
        do {
            _ = try await DesignSpecCatalog.load(remoteURL: URL(string: "http://example.com/x.md")!)
            XCTFail("Expected an insecureURL error")
        } catch let error as DesignSpecError {
            XCTAssertEqual(error, .insecureURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolverFallsBackToHeuristic() async {
        let spec = DesignSpecCatalog.pasted("primary #123456")
        struct Boom: Error {}
        let failing = ClosureDesignResolver { _, _ in throw Boom() }
        let result = await DesignMode.resolve(spec, using: failing)
        XCTAssertEqual(result.method, .heuristic)
        XCTAssertEqual(result.config.primaryHex, "123456")
        XCTAssertTrue(result.warnings.contains { $0.contains("AI resolver failed") })
    }

    func testResolverResultIsUsedWhenItSucceeds() async {
        let spec = DesignSpecCatalog.pasted("ignored prose")
        let cfg = ThemeConfig(primaryHex: "abcdef", dark: true)
        let resolver = ClosureDesignResolver { _, _ in
            DesignParseResult(config: cfg, confidence: .high, method: .resolver("test"))
        }
        let result = await DesignMode.resolve(spec, using: resolver)
        XCTAssertEqual(result.method, .resolver("test"))
        XCTAssertEqual(result.config, cfg)
    }

    @MainActor
    func testApplyReskinsTheme() {
        let spec = DesignSpecCatalog.pasted("""
        ```themekit
        primary: #65c3c8
        base: #faf7f5
        dark: false
        ```
        """)
        let result = DesignMode.parse(spec)
        DesignMode.apply(result)
        XCTAssertEqual(Theme.shared.currentConfig?.primaryHex, "65c3c8")
        XCTAssertEqual(Theme.shared.currentConfig?.baseHex, "faf7f5")
        // restore default so other tests aren't affected
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }
}
