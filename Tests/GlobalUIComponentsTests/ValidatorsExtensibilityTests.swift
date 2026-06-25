import XCTest
@testable import GlobalUIComponents

final class ValidatorsExtensibilityTests: XCTestCase {
    // Pure predicates are reusable + testable without the rule/UI layer.
    func testPurePredicates() {
        XCTAssertTrue(Validators.email("a@b.com"))
        XCTAssertFalse(Validators.email("nope"))
        XCTAssertTrue(Validators.phone("+90 (532) 111-22-33"))
        XCTAssertTrue(Validators.intInRange("7", 1...10))
        XCTAssertFalse(Validators.intInRange("99", 1...10))
        XCTAssertTrue(Validators.password("Abc12345", requireSpecial: false))
        XCTAssertFalse(Validators.password("abc", requireUppercase: true))
    }

    // External regex feeding — plain, with options, and a custom predicate.
    func testRegexInjection() {
        XCTAssertTrue(Validator.validate("ABC", [.regex("^[a-z]+$", caseInsensitive: true, "x")]).isEmpty)
        XCTAssertFalse(Validator.validate("ABC", [.regex("^[a-z]+$", "x")]).isEmpty)   // case-sensitive fails
        let custom = ValidationRule("only AAA") { $0 == "AAA" }
        XCTAssertTrue(Validator.validate("AAA", [custom]).isEmpty)
        XCTAssertEqual(Validator.validate("zzz", [custom]).first?.text, "only AAA")
    }

    func testTypedRegex() throws {
        guard #available(iOS 16.0, macOS 13.0, *) else { throw XCTSkip("Typed Regex needs iOS 16 / macOS 13") }
        let rule = ValidationRule.matches(try Regex(#"^\d{3}$"#), "3 digits")
        XCTAssertTrue(Validator.validate("123", [rule]).isEmpty)
        XCTAssertFalse(Validator.validate("12", [rule]).isEmpty)
    }

    func testAsyncRule() async {
        let unique = AsyncValidationRule("Bu kullanıcı adı alınmış") { name in
            // pretend a server call:
            try? await Task.sleep(nanoseconds: 1_000_000)
            return name != "taken"
        }
        let taken = await Validator.validate("taken", async: [unique])
        let free = await Validator.validate("available", async: [unique])
        XCTAssertEqual(taken.first?.text, "Bu kullanıcı adı alınmış")
        XCTAssertTrue(free.isEmpty)
    }
}
