//
//  TaskTimeoutTests.swift
//  TaskTimeout
//
//  Created by Simon Whitty on 31/08/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/TaskTimeout
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import TaskTimeout
import XCTest

final class TaskTimeoutTests: XCTestCase {

    @MainActor
    func testMainActor_ReturnsValue() async throws {
        let val = try await withThrowingTimeout(seconds: 1) {
            MainActor.assertIsolated()
            return "Fish"
        }
        XCTAssertEqual(val, "Fish")
    }

    @MainActor
    func testMainActorThrowsError_WhenTimeoutExpires() async {
        do {
            try await withThrowingTimeout(seconds: 0.05) {
                MainActor.assertIsolated()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

    func testActor_ReturnsValue() async throws {
        let val = try await TestActor().returningString("Fish")
        XCTAssertEqual(val, "Fish")
    }

    func testActorThrowsError_WhenTimeoutExpires() async {
        do {
            _ = try await TestActor().returningString(
                after: 60,
                timeout: 0.05
            )
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }
}

final actor TestActor {

    func returningString(_ string: String = "Fish", after sleep: TimeInterval = 0, timeout: TimeInterval = 1) async throws -> String {
        try await returningValue(string, after: sleep, timeout: timeout)
    }

    func returningValue<T: Sendable>(_ value: T, after sleep: TimeInterval = 0, timeout: TimeInterval = 1) async throws -> T {
        try await withThrowingTimeout(seconds: timeout) {
            assertIsolated()
            try await Task.sleep(nanoseconds: UInt64(sleep * 1_000_000_000))
            return value
        }
    }
}
