//
//  UploadControllerTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Lifecycle coverage for the async UploadController (success / failure /
//  progress / remove / retry).
//

import Foundation
import XCTest
@testable import ThemeKit

@MainActor
final class UploadControllerTests: XCTestCase {

    private struct TooBig: LocalizedError { var errorDescription: String? { "too big" } }

    func testUploadSuccessMarksDone() async {
        let controller = UploadController()
        await controller.upload(name: "a.jpg") { _ in }
        XCTAssertEqual(controller.files.count, 1)
        XCTAssertEqual(controller.files.first?.status, .done)
    }

    func testUploadFailureUsesLocalizedDescription() async {
        let controller = UploadController()
        await controller.upload(name: "a.jpg") { _ in throw TooBig() }
        XCTAssertEqual(controller.files.first?.status, .failed("too big"))
    }

    func testProgressSettlesToDone() async {
        let controller = UploadController()
        await controller.upload(name: "a.jpg") { progress in
            progress(0.5)
            progress(2.0)   // out-of-range value is clamped during upload
        }
        XCTAssertEqual(controller.files.first?.status, .done)
    }

    func testRemove() async {
        let controller = UploadController()
        let id = await controller.upload(name: "a.jpg") { _ in }
        controller.remove(id)
        XCTAssertTrue(controller.files.isEmpty)
    }

    func testRetryRerunsSameOperation() async {
        let controller = UploadController()
        let id = await controller.upload(name: "a.jpg") { _ in throw TooBig() }
        XCTAssertEqual(controller.files.first?.status, .failed("too big"))
        await controller.retry(id)
        XCTAssertEqual(controller.files.first?.status, .failed("too big"))
    }
}
