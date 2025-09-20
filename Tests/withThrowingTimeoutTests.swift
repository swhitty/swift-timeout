//
//  withThrowingTimeoutTests.swift
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

@testable import Timeout
import struct Foundation.TimeInterval
import Testing

struct WithThrowingTimeoutTests {

    @Test @MainActor
    func mainActor_ReturnsValue() async throws {
        let val = try await withThrowingTimeout(seconds: 1) {
            MainActor.assertIsolated()
            try await Task.sleep(nanoseconds: 1_000)
            MainActor.assertIsolated()
            return "Fish"
        }
        #expect(val == "Fish")
    }

    @Test
    func mainActorThrowsError_WhenTimeoutExpires() async {
        await #expect(throws: TimeoutError.self) { @MainActor in
            try await withThrowingTimeout(seconds: 0.05) {
                MainActor.assertIsolated()
                defer { MainActor.assertIsolated() }
                try await Task.sleepIndefinitely()
            }
        }
    }

    @Test
    func sendable_ReturnsValue() async throws {
        let sendable = TestActor()
        let value = try await withThrowingTimeout(seconds: 1) {
            sendable
        }
        #expect(value === sendable)
    }

    @Test
    func nonSendable_ReturnsValue() async throws {
        let ns = try await withThrowingTimeout(seconds: 1) {
            NonSendable("chips")
        }
        #expect(ns.value == "chips")
    }

    @Test
    func actor_ReturnsValue() async throws {
        #expect(
            try await TestActor("Fish").returningValue() == "Fish"
        )
    }

    @Test
    func actorThrowsError_WhenTimeoutExpires() async {
        await #expect(throws: TimeoutError.self) {
            try await withThrowingTimeout(seconds: 0.05) {
                try await TestActor().returningValue(after: 60, timeout: 0.05)
            }
        }
    }

    @Test
    func timeout_cancels() async {
        let task = Task {
            try await withThrowingTimeout(seconds: 1) {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func returnsValue_beforeDeadlineExpires() async throws {
        #expect(
            try await TestActor("Fish").returningValue(before: .now + .seconds(2)) == "Fish"
        )
    }

    @Test
    func throwsError_WhenDeadlineExpires() async {
        await #expect(throws: TimeoutError.self) {
            try await TestActor("Fish").returningValue(after: 0.1, before: .now)
        }
    }

    @Test
    func returnsValueWithClock_beforeDeadlineExpires() async throws {
        #expect(
            try await withThrowingTimeout(after: .now + .seconds(2), clock: ContinuousClock()) {
                "Fish"
            } == "Fish"
        )
    }

    @Test
    func throwsErrorWithClock_WhenDeadlineExpires() async {
        await #expect(throws: TimeoutError.self) {
            try await withThrowingTimeout(after: .now, clock: ContinuousClock()) {
                try await Task.sleep(for: .seconds(2))
            }
        }
    }

    @Test
    func timeout_ExpiresImmediatley() async throws {
        await #expect(throws: TimeoutError.self) {
            try await withThrowingTimeout(seconds: 1_000) { timeout in
                timeout.expireImmediatley()
            }
        }
    }

    @Test
    func timeout_ExpiresAfterSeconds() async throws {
        await #expect(throws: TimeoutError.self) {
            try await withThrowingTimeout(seconds: 1_000) { timeout in
                timeout.expire(seconds: 0.1)
                try await Task.sleepIndefinitely()
            }
        }
    }

    @Test
    func timeout_ExpiresAfterDeadline() async throws {
        await #expect(throws: TimeoutError.self) {
            try await withThrowingTimeout(seconds: 1_000) { timeout in
                timeout.expire(after: .now + .seconds(0.1))
                try await Task.sleepIndefinitely()
            }
        }
    }

    @Test
    func timeout_ExpirationCancels() async throws {
        #expect(
            try await withThrowingTimeout(seconds: 0.1) { timeout in
                timeout.cancelExpiration()
                try await Task.sleep(for: .seconds(0.3))
                return "Fish"
            } == "Fish"
        )
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
            self.assertIsolated()
            return self.value
        }
    }
}
