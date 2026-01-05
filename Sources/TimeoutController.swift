//
//  TimeoutController.swift
//  swift-timeout
//
//  Created by Simon Whitty on 02/06/2025.
//  Copyright 2025 Simon Whitty
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

#if !canImport(Darwin)
import Synchronization
typealias Mutex = Synchronization.Mutex
#endif

import struct Foundation.TimeInterval

public struct TimeoutController: Sendable {
    fileprivate var canary: @Sendable () -> Void
    fileprivate let shared: SharedState

    @discardableResult
    public func expire(seconds: TimeInterval) -> Bool {
        enqueue {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError("Task timed out before completion. Timeout: \(seconds) seconds.")
        }
    }

    @discardableResult
    public func expireImmediatley() -> Bool {
        enqueue(flagAsComplete: true) {
            throw TimeoutError("Task timed out before completion. expireImmediatley()")
        }
    }

    @discardableResult
    public func cancelExpiration() -> Bool {
        enqueue {
            try await Task.sleepIndefinitely()
        }
    }

    struct State {
        var running: Task<Void, any Error>?
        var pending: (@Sendable () async throws -> Never)?
        var isComplete: Bool = false
    }

    final class SharedState: Sendable {
        let state: Mutex<State>

        init(pending: @escaping @Sendable () async throws -> Never) {
            state = Mutex(.init(pending: pending))
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public extension TimeoutController {

    @discardableResult
    func expire<C: Clock>(
        after instant: C.Instant,
        tolerance: C.Instant.Duration? = nil,
        clock: C
    ) -> Bool {
        enqueue {
            try await Task.sleep(until: instant, tolerance: tolerance, clock: clock)
            throw TimeoutError("Task timed out before completion. Deadline: \(instant).")
        }
    }

    @discardableResult
    func expire(
        after instant: ContinuousClock.Instant,
        tolerance: ContinuousClock.Instant.Duration? = nil
    ) -> Bool {
        expire(after: instant, tolerance: tolerance, clock: ContinuousClock())
    }
}

extension TimeoutController {

    init(
        canary: @escaping @Sendable () -> Void,
        pending closure: @escaping @Sendable () async throws -> Never
    ) {
        self.canary = canary
        self.shared = .init(pending: closure)
    }

    @discardableResult
    func enqueue(flagAsComplete: Bool = false, closure: @escaping @Sendable () async throws -> Never) -> Bool {
        shared.state.withLock { s in
            guard !s.isComplete else { return false }
            s.pending = closure
            s.running?.cancel()
            s.isComplete = flagAsComplete
            return true
        }
    }

    func startPendingTask() -> Task<Void, any Error>? {
        return shared.state.withLock { s in
            guard let pending = s.pending else {
                s.isComplete = true
                return nil
            }
            let task = Task { _ = try await pending() }
            s.pending = nil
            s.running = task
            return task
        }
    }

    func waitForTimeout() async throws {
        var lastError: (any Error)?
        while let task = startPendingTask() {
            do {
                try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
            } catch is CancellationError {
                lastError = nil
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
    }
}

func withNonEscapingTimeout<T>(
    _ timeout: @escaping @Sendable () async throws -> Never,
    isolation: isolated (any Actor)? = #isolation,
    body: (TimeoutController) async throws -> sending T
) async throws -> sending T {
    // canary ensuring TimeoutController does not escape at runtime.
    // Swift 6.2 and later can enforce at compile time with ~Escapable
    try await withoutActuallyEscaping({ @Sendable in }) { escaping in
        _ = isolation
        let timeout = TimeoutController(canary: escaping, pending: timeout)
        return try await Transferring(body(timeout))
    }.value
}
