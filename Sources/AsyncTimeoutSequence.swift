//
//  AsyncTimeoutSequence.swift
//  swift-timeout
//
//  Created by Simon Whitty on 03/06/2025.
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

import struct Foundation.TimeInterval

public extension AsyncSequence where Element: Sendable {

    /// Creates an asynchronous sequence that throws error if any iteration
    /// takes longer than provided `TimeInterval`.
    func timeout(seconds: TimeInterval) -> AsyncTimeoutSequence<Self> {
        AsyncTimeoutSequence(base: self, seconds: seconds)
    }

    /// Creates an asynchronous sequence that throws error if any iteration
    /// takes longer than provided `Duration` using the supplied `Clock`.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func timeout<C: Clock>(
        duration: Duration,
        clock: C = ContinuousClock()
    ) -> AsyncTimeoutSequence<Self> where C.Duration == Duration {
        AsyncTimeoutSequence(base: self, duration: duration, clock: clock)
    }
}

public struct AsyncTimeoutSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Sendable {
    public typealias Element = Base.Element

    private let base: Base
    private let interval: TimeoutInterval<Base.Element?>

    public init(base: Base, seconds: TimeInterval) {
        self.base = base
        self.interval = .timeInterval(seconds)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public init<C: Clock>(
        base: Base,
        duration: Duration,
        clock: C = ContinuousClock()
    ) where C.Duration == Duration {
        self.base = base
        self.interval = .duration(.init(duration, clock: clock))
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            iterator: base.makeAsyncIterator(),
            interval: interval
        )
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: Base.AsyncIterator
        private let interval: TimeoutInterval<Base.Element?>

        fileprivate init(iterator: Base.AsyncIterator, interval: TimeoutInterval<Base.Element?>) {
            self.iterator = iterator
            self.interval = interval
        }

        public mutating func next() async throws -> Base.Element? {
            switch interval {
                case .timeInterval(let seconds):
                return try await withThrowingTimeout(seconds: seconds) {
                    try await self.iterator.next()
                }

                case .duration(let durationBox):
                guard #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) else {
                    fatalError("cannot occur")
                }
                return try await durationBox.withThrowingTimeout {
                    try await self.iterator.next()
                }
            }
        }
    }
}

private enum TimeoutInterval<T: Sendable> {
    case timeInterval(TimeInterval)
    case duration(DurationBox)

    struct DurationBox {
        private typealias TimeoutClosure = (() async throws -> sending T) async throws -> sending T

        private let storage: TimeoutClosure

        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        init<C: Clock>(
            _ duration: C.Duration,
            clock: C
        ) {
            self.storage = { closure in
                try await Timeout.withThrowingTimeout(
                    after: clock.now.advanced(by: duration),
                    clock: clock
                ) {
                    try await closure()
                }
            }
        }

        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        func withThrowingTimeout(
            _ closure: () async throws -> sending T
        ) async throws -> T {
            try await storage {
                try await closure()
            }
        }
    }
}
