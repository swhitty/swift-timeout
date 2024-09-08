//
//  Timeout.swift
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

import Foundation

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
    try await _withThrowingTimeout(isolation: isolation, body: body) {
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
    try await _withThrowingTimeout(isolation: isolation, body: body) {
        try await Task.sleep(until: instant, tolerance: tolerance, clock: ContinuousClock())
        throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
    }.value
}

private func _withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    body: () async throws -> sending T,
    timeout: @Sendable @escaping () async throws -> Void
) async throws -> Transferring<T> {
    try await withoutActuallyEscaping(body) { escapingBody in
        let bodyTask = Task {
            defer { _ = isolation }
            return try await Transferring(escapingBody())
        }
        let timeoutTask = Task {
            defer { bodyTask.cancel() }
            try await timeout()
        }

        let bodyResult = await withTaskCancellationHandler {
            await bodyTask.result
        } onCancel: {
            bodyTask.cancel()
        }
        timeoutTask.cancel()
        let timeoutResult = await timeoutTask.result

        switch bodyResult {
        case .success(let bodySuccess):
            return bodySuccess
        case .failure(let bodyError):
            if case .failure(let timeoutError) = timeoutResult, timeoutError is TimeoutError {
                throw timeoutError
            } else {
                throw bodyError
            }
        }
    }
}

private struct Transferring<Value>: Sendable {
    nonisolated(unsafe) public var value: Value
    init(_ value: Value) {
        self.value = value
    }
}
#else
public func withThrowingTimeout<T>(
    seconds: TimeInterval,
    body: () async throws -> T
) async throws -> T {
    let transferringBody = { try await Transferring(body()) }
    typealias NonSendableClosure = () async throws -> Transferring<T>
    typealias SendableClosure = @Sendable () async throws -> Transferring<T>
    return try await withoutActuallyEscaping(transferringBody) {
        (_ fn: @escaping NonSendableClosure) async throws -> Transferring<T> in
        let sendableFn = unsafeBitCast(fn, to: SendableClosure.self)
        return try await _withThrowingTimeout(body: sendableFn) {
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
    let transferringBody = { try await Transferring(body()) }
    typealias NonSendableClosure = () async throws -> Transferring<T>
    typealias SendableClosure = @Sendable () async throws -> Transferring<T>
    return try await withoutActuallyEscaping(transferringBody) {
        (_ fn: @escaping NonSendableClosure) async throws -> Transferring<T> in
        let sendableFn = unsafeBitCast(fn, to: SendableClosure.self)
        return try await _withThrowingTimeout(body: sendableFn) {
            try await Task.sleep(until: instant, tolerance: tolerance, clock: ContinuousClock())
            throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
        }
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    body: @Sendable @escaping () async throws -> T,
    timeout: @Sendable @escaping () async throws -> Void
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await timeout()
            throw TimeoutError("expired")
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
    }
}

private struct Transferring<Value>: @unchecked Sendable {

    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
#endif