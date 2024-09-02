//
//  TaskTimeout.swift
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

import Foundation

public struct TimeoutError: LocalizedError {
    public var errorDescription: String?

    public init(timeout: TimeInterval) {
        self.errorDescription = "Task timed out before completion. Timeout: \(timeout) seconds."
    }
}

#if compiler(>=6.0)
public func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: () async throws -> sending T
) async throws -> sending T {
    // body never leaves isolation, casts are used to keep compiler happy.
    let transferringBody = { try await Transferring(body()) }
    typealias NonSendableClosure = () async throws -> Transferring<T>
    typealias SendableClosure = @Sendable () async throws -> Transferring<T>
    return try await withoutActuallyEscaping(transferringBody) {
        (_ fn: @escaping NonSendableClosure) async throws -> Transferring<T> in
        let sendableFn = unsafeBitCast(fn, to: SendableClosure.self)
        return try await _withThrowingTimeout(isolation: isolation, seconds: seconds, body: sendableFn)
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self, isolation: isolation) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(timeout: seconds)
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
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
        return try await _withThrowingTimeout(seconds: seconds, body: sendableFn)
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    seconds: TimeInterval,
    body: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(timeout: seconds)
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
