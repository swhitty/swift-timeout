//
//  Task+SleepIndefinitely.swift
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

#if compiler(>=6)

package extension Task<Never, Never> {

    private typealias State = (isCancelled: Bool, continuation: CheckedContinuation<Void, any Error>?)

    static func sleepIndefinitely() async throws -> Never {
        let state = Mutex<State>((isCancelled: false, continuation: nil))
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let isCancelled = state.withLock {
                    if $0.isCancelled {
                        return true
                    } else {
                        $0.continuation = continuation
                        return false
                    }
                }
                if isCancelled {
                    continuation.resume(throwing: _Concurrency.CancellationError())
                }
            }
        } onCancel: {
            let continuation = state.withLock {
                $0.isCancelled = true
                return $0.continuation
            }
            continuation?.resume(throwing: _Concurrency.CancellationError())
        }
        fatalError("can never occur")
    }
}

#endif
