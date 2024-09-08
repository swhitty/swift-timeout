//
//  TimeoutTests.swift
//  swift-timeout
//
//  Created by Simon Whitty on 31/08/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-timeout
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

#if !canImport(Testing)
import Timeout
import XCTest

final class TimeoutTests: XCTestCase {

    @MainActor
    func testMainActor_ReturnsValue() async throws {
        let val = try await withThrowingTimeout(seconds: 1) {
            MainActor.assertIsolated()
            try await Task.sleep(nanoseconds: 1_000)
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
                defer { MainActor.assertIsolated() }
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

    func testSendable_ReturnsValue() async throws {
        let sendable = TestActor()
        let value = try await withThrowingTimeout(seconds: 1) {
            sendable
        }
        XCTAssertTrue(value === sendable)
    }

    func testNonSendable_ReturnsValue() async throws {
        let ns = try await withThrowingTimeout(seconds: 1) {
            NonSendable("chips")
        }
        XCTAssertEqual(ns.value, "chips")
    }

    func testActor_ReturnsValue() async throws {
        let val = try await TestActor("Fish").returningValue()
        XCTAssertEqual(val, "Fish")
    }

    func testActorThrowsError_WhenTimeoutExpires() async {
        do {
            _ = try await TestActor().returningValue(
                after: 60,
                timeout: 0.05
            )
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

    func testTimeout_Cancels() async {
        let task = Task {
            try await withThrowingTimeout(seconds: 1) {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testReturnsValue_beforeDeadlineExpires() async throws {
        let val = try await TestActor("Fish").returningValue(before: .now + .seconds(2))
        XCTAssert(val == "Fish")
    }

    func testThrowsError_WhenDeadlineExpires() async {
        do {
            _ = try await TestActor("Fish").returningValue(after: 0.1, before: .now)
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }
}

public struct NonSendable<T> {
    public var value: T

    init(_ value: T) {
        self.value = value
    }
}

final actor TestActor<T: Sendable> {

    private var value: T

    init(_ value: T) {
        self.value = value
    }

    init() where T == String {
        self.init("fish")
    }

    func returningValue(after sleep: TimeInterval = 0, timeout: TimeInterval = 1) async throws -> T {
        try await withThrowingTimeout(seconds: timeout) {
            try await Task.sleep(nanoseconds: UInt64(sleep * 1_000_000_000))
            self.assertIsolated()
            return self.value
        }
    }

    func returningValue(after sleep: TimeInterval = 0, before instant: ContinuousClock.Instant) async throws -> T {
        try await withThrowingTimeout(after: instant) {
            try await Task.sleep(nanoseconds: UInt64(sleep * 1_000_000_000))
            #if compiler(>=5.10)
            self.assertIsolated()
            #endif
            return self.value
        }
    }
}
#endif
