import XCTest
@testable import ThemeKit

/// Contract for `commandFilter`, the CommandPalette's pure fuzzy matcher:
/// case/diacritic-insensitive, token-prefix over title + keywords, every token
/// must match, empty query passes everything through.
final class CommandPaletteTests: XCTestCase {

    private func item(_ title: String, keywords: [String] = []) -> CommandItem {
        CommandItem(title, keywords: keywords) {}
    }

    private lazy var sections: [CommandSection] = [
        CommandSection("Actions", items: [
            item("New booking", keywords: ["create", "add"]),
            item("Search flights", keywords: ["find"]),
        ]),
        CommandSection("Navigation", items: [
            item("Go to trips", keywords: ["bookings"]),
            item("Settings"),
        ]),
    ]

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(commandFilter(sections, query: "").flatMap(\.items).count, 4)
        XCTAssertEqual(commandFilter(sections, query: "   ").flatMap(\.items).count, 4)
    }

    func testPrefixMatchOnTitle() {
        let hits = commandFilter(sections, query: "sea").flatMap(\.items).map(\.title)
        XCTAssertEqual(hits, ["Search flights"])
    }

    func testMatchOnKeyword() {
        let hits = commandFilter(sections, query: "create").flatMap(\.items).map(\.title)
        XCTAssertEqual(hits, ["New booking"])
    }

    func testCaseAndDiacriticInsensitive() {
        XCTAssertEqual(commandFilter(sections, query: "SEARCH").flatMap(\.items).map(\.title), ["Search flights"])
        // Accented query still matches the plain title word.
        XCTAssertEqual(commandFilter(sections, query: "séttings").flatMap(\.items).map(\.title), ["Settings"])
    }

    func testAllTokensMustMatch() {
        // "new booking" — both tokens match one item.
        XCTAssertEqual(commandFilter(sections, query: "new book").flatMap(\.items).map(\.title), ["New booking"])
        // "new flights" — no single item has both.
        XCTAssertTrue(commandFilter(sections, query: "new flights").flatMap(\.items).isEmpty)
    }

    func testNoMatchDropsEmptySections() {
        let result = commandFilter(sections, query: "zzz")
        XCTAssertTrue(result.isEmpty, "sections with no surviving items are dropped")
    }

    func testWordPrefixInsideTitleMatches() {
        // "trips" is the third word of "Go to trips".
        XCTAssertEqual(commandFilter(sections, query: "trip").flatMap(\.items).map(\.title), ["Go to trips"])
    }
}
