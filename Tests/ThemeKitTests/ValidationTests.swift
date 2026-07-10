import XCTest
@testable import ThemeKit

@MainActor
final class ValidationTests: XCTestCase {

    func testRequiredAndEmail() {
        XCTAssertEqual(Validator.validate("", [.required(), .email()], all: true).count, 1)      // only required on empty
        XCTAssertEqual(Validator.validate("nope", [.required(), .email()], all: true).count, 1)  // email fails
        XCTAssertTrue(Validator.validate("a@b.co", [.required(), .email()], all: true).isEmpty)
    }

    func testMinMaxLength() {
        XCTAssertFalse(Validator.validate("ab", [.minLength(3)]).isEmpty)
        XCTAssertTrue(Validator.validate("abc", [.minLength(3)]).isEmpty)
        XCTAssertFalse(Validator.validate("abcd", [.maxLength(3)]).isEmpty)
    }

    func testPhone() {
        XCTAssertTrue(Validator.validate("+90 532 111 22 33", [.phone()]).isEmpty)
        XCTAssertFalse(Validator.validate("123", [.phone()]).isEmpty)
        XCTAssertFalse(Validator.validate("abcdefg", [.phone()]).isEmpty)
    }

    func testPassword() {
        let rule: [ValidationRule] = [.password(minLength: 8, requireUppercase: true, requireDigit: true)]
        XCTAssertFalse(Validator.validate("short1A", rule).isEmpty)        // too short
        XCTAssertFalse(Validator.validate("alllower1", rule).isEmpty)      // no uppercase
        XCTAssertFalse(Validator.validate("NoDigitsHere", rule).isEmpty)   // no digit
        XCTAssertTrue(Validator.validate("Strong1Pass", rule).isEmpty)
    }

    func testCreditCardDate() {
        XCTAssertTrue(Validator.validate("12/28", [.creditCardDate()]).isEmpty)
        XCTAssertTrue(Validator.validate("0130", [.creditCardDate()]).isEmpty)
        XCTAssertFalse(Validator.validate("13/28", [.creditCardDate()]).isEmpty)   // month 13
    }

    func testNumericAndRange() {
        XCTAssertTrue(Validator.validate("42", [.numeric()]).isEmpty)
        XCTAssertFalse(Validator.validate("4a", [.numeric()]).isEmpty)
        XCTAssertTrue(Validator.validate("5", [.range(1...10)]).isEmpty)
        XCTAssertFalse(Validator.validate("11", [.range(1...10)]).isEmpty)
    }

    func testMatch() {
        var other = "secret"
        XCTAssertTrue(Validator.validate("secret", [.match(other)]).isEmpty)
        other = "changed"
        XCTAssertFalse(Validator.validate("secret", [.match(other)]).isEmpty)   // re-reads current value
    }

    func testFormValidatorFirstInvalid() {
        enum Field { case a, b, c }
        let form = FormValidator<Field>([
            .a: [.required("A")],
            .b: [.required("B"), .email()],
            .c: [.required("C")],
        ])
        let first = form.validateAll([.a: "ok", .b: "", .c: ""])
        XCTAssertEqual(first, .b)                       // first invalid in declaration order
        XCTAssertEqual(form.focusedField, .b)
        XCTAssertFalse(form.isValid)
        _ = form.validateAll([.a: "ok", .b: "x@y.z", .c: "ok"])
        XCTAssertTrue(form.isValid)
    }

    func testFormValidatorSubmit() {
        enum Field { case email, password }
        let form = FormValidator<Field>([
            .email: [.required(), .email()],
            .password: [.required(), .minLength(8)],
        ])

        // Invalid form: action must not run; first invalid field gets focus.
        var ran = false
        XCTAssertFalse(form.submit([.email: "nope", .password: "longenough"]) { ran = true })
        XCTAssertFalse(ran)
        XCTAssertEqual(form.focusedField, .email)
        XCTAssertFalse(form.messages(for: .email).isEmpty)

        // Clean form: action runs and submit reports true.
        XCTAssertTrue(form.submit([.email: "a@b.co", .password: "longenough"]) { ran = true })
        XCTAssertTrue(ran)
        XCTAssertNil(form.focusedField)
        XCTAssertTrue(form.isValid)
    }
}
