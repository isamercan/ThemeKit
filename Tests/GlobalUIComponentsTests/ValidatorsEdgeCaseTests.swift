//
//  ValidatorsEdgeCaseTests.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Broadens the pure-predicate coverage with boundary and malformed inputs.
//

import XCTest
@testable import GlobalUIComponents

final class ValidatorsEdgeCaseTests: XCTestCase {

    func testRequiredTrimsWhitespace() {
        XCTAssertFalse(Validators.required("   "))
        XCTAssertFalse(Validators.required(""))
        XCTAssertTrue(Validators.required(" a "))
    }

    func testLengthBoundaries() {
        XCTAssertTrue(Validators.minLength("abc", 3))   // exact
        XCTAssertFalse(Validators.minLength("ab", 3))
        XCTAssertTrue(Validators.maxLength("abc", 3))   // exact
        XCTAssertFalse(Validators.maxLength("abcd", 3))
    }

    func testEmailVariants() {
        XCTAssertTrue(Validators.email("a.b+tag@sub.example.co"))
        XCTAssertFalse(Validators.email("a@b"))         // no TLD
        XCTAssertFalse(Validators.email("a@@b.com"))
        XCTAssertFalse(Validators.email("plainaddress"))
        XCTAssertFalse(Validators.email(" a@b.com"))    // leading space
    }

    func testPhoneBoundaries() {
        XCTAssertTrue(Validators.phone("+90 (532) 111-22-33"))
        XCTAssertTrue(Validators.phone("5321112233"))
        XCTAssertFalse(Validators.phone("123"))         // too short
        XCTAssertFalse(Validators.phone("not-a-phone"))
    }

    func testCreditCardDateMonths() {
        XCTAssertTrue(Validators.creditCardDate("01/30"))
        XCTAssertTrue(Validators.creditCardDate("12/28"))
        XCTAssertFalse(Validators.creditCardDate("00/30"))   // month 00
        XCTAssertFalse(Validators.creditCardDate("13/30"))   // month 13
        XCTAssertFalse(Validators.creditCardDate("1/2030"))  // wrong shape
    }

    func testIntInRange() {
        XCTAssertTrue(Validators.intInRange("1", 1...10))    // lower bound
        XCTAssertTrue(Validators.intInRange("10", 1...10))   // upper bound
        XCTAssertFalse(Validators.intInRange("0", 1...10))
        XCTAssertFalse(Validators.intInRange("11", 1...10))
        XCTAssertFalse(Validators.intInRange("x", 1...10))   // not a number
    }

    func testPasswordRules() {
        XCTAssertTrue(Validators.password("Abcd1234", minLength: 8, requireUppercase: true, requireDigit: true))
        XCTAssertFalse(Validators.password("Abcd1", minLength: 8))               // too short
        XCTAssertFalse(Validators.password("abcd1234", requireUppercase: true))  // no uppercase
        XCTAssertFalse(Validators.password("Abcdefgh", requireDigit: true))      // no digit
        XCTAssertTrue(Validators.password("abcdefgh", requireUppercase: false, requireDigit: false))
        XCTAssertFalse(Validators.password("Abcd1234", requireSpecial: true))    // missing special
        XCTAssertTrue(Validators.password("Abcd123!", requireSpecial: true))
    }

    func testNumeric() {
        XCTAssertTrue(Validators.numeric("0123456789"))
        XCTAssertFalse(Validators.numeric("12.3"))
        XCTAssertFalse(Validators.numeric(""))
        XCTAssertFalse(Validators.numeric("12a"))
    }
}
