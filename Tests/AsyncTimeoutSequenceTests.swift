//
//  AsyncTimeoutSequenceTests.swift
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

@testable import Timeout
import Testing

struct AsyncTimeoutSequenceTests {

    @Test
    func timeoutSeconds() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let t = Task {
            continuation.yield(1)
            try await Task.sleep(nanoseconds: 1_000)
            continuation.yield(2)
            try await Task.sleepIndefinitely()
        }
        defer { t.cancel() }
        var iterator = stream.timeout(seconds: 0.1).makeAsyncIterator()

        #expect(try await iterator.next() == 1)
        #expect(try await iterator.next() == 2)
        await #expect(throws: TimeoutError.self) {
            try await iterator.next()
        }
    }

    @Test
    func timeoutDuration() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let t = Task {
            continuation.yield(1)
            try await Task.sleep(nanoseconds: 1_000)
            continuation.yield(2)
            try await Task.sleepIndefinitely()
        }
        defer { t.cancel() }
        var iterator = stream.timeout(duration: .milliseconds(100)).makeAsyncIterator()

        #expect(try await iterator.next() == 1)
        #expect(try await iterator.next() == 2)
        await #expect(throws: TimeoutError.self) {
            try await iterator.next()
        }
    }
}
