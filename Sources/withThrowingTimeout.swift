//
//  withThrowingTimeout.swift
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

import protocol Foundation.LocalizedError
import struct Foundation.TimeInterval

public struct TimeoutError: LocalizedError {
    public var errorDescription: String?

    init(_ description: String) {
        self.errorDescription = description
    }
}

#if compiler(>=6.0)
public func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: () async throws -> sending T
) async throws -> sending T {
    try await _withThrowingTimeout(isolation: isolation, body: { _ in try await body() }) {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw TimeoutError("Task timed out before completion. Timeout: \(seconds) seconds.")
    }.value
}

public func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: (TimeoutController) async throws -> sending T
) async throws -> sending T {
    try await _withThrowingTimeout(isolation: isolation, body: body) {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw TimeoutError("Task timed out before completion. Timeout: \(seconds) seconds.")
    }.value
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func withThrowingTimeout<T, C: Clock>(
    isolation: isolated (any Actor)? = #isolation,
    after instant: C.Instant,
    tolerance: C.Instant.Duration? = nil,
    clock: C,
    body: () async throws -> sending T
) async throws -> sending T {
    try await _withThrowingTimeout(isolation: isolation, body: { _ in try await body() }) {
        try await Task.sleep(until: instant, tolerance: tolerance, clock: clock)
        throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
    }.value
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    after instant: ContinuousClock.Instant,
    tolerance: ContinuousClock.Instant.Duration? = nil,
    body: () async throws -> sending T
) async throws -> sending T {
    try await _withThrowingTimeout(isolation: isolation, body: { _ in try await body() }) {
        try await Task.sleep(until: instant, tolerance: tolerance, clock: ContinuousClock())
        throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
    }.value
}

private func _withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    body: (TimeoutController) async throws -> sending T,
    timeout closure: @Sendable @escaping () async throws -> Never
) async throws -> Transferring<T> {
    try await withoutActuallyEscaping(body) { escapingBody in
        try await withNonEscapingTimeout(closure) { timeout in
            let bodyTask = Task {
                defer { _ = isolation }
                return try await Transferring(escapingBody(timeout))
            }
            let timeoutTask = Task {
                defer { bodyTask.cancel() }
                try await timeout.waitForTimeout()
            }

            let bodyResult = await withTaskCancellationHandler {
                await bodyTask.result
            } onCancel: {
                bodyTask.cancel()
            }
            timeoutTask.cancel()

            if case .failure(let timeoutError) = await timeoutTask.result,
               timeoutError is TimeoutError {
                throw timeoutError
            } else {
                return try bodyResult.get()
            }
        }
    }
}

#else

public func withThrowingTimeout<T>(
    seconds: TimeInterval,
    body: () async throws -> T
) async throws -> T {
    let transferringBody = { try await Transferring(body()) }
    return try await withoutActuallyEscaping(transferringBody) {
        try await _withThrowingTimeout(body: $0) {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError("Task timed out before completion. Timeout: \(seconds) seconds.")
        }
    }.value
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func withThrowingTimeout<T>(
    after instant: ContinuousClock.Instant,
    tolerance: ContinuousClock.Instant.Duration? = nil,
    body: () async throws -> T
) async throws -> T {
    try await withThrowingTimeout(
        after: instant,
        tolerance: tolerance,
        clock: ContinuousClock(),
        body: body
    )
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public func withThrowingTimeout<T, C: Clock>(
    after instant: C.Instant,
    tolerance: C.Instant.Duration? = nil,
    clock: C,
    body: () async throws -> T
) async throws -> T {
    let transferringBody = { try await Transferring(body()) }
    return try await withoutActuallyEscaping(transferringBody) {
        try await _withThrowingTimeout(body: $0) {
            try await Task.sleep(until: instant, tolerance: tolerance, clock: clock)
            throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
        }
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    body: @escaping () async throws -> T,
    timeout: @Sendable @escaping () async throws -> Never
) async throws -> T {
    let body = Transferring(body)
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body.value()
        }
        group.addTask {
            try await timeout()
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
    }
}

#endif
