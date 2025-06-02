//
//  Mutex.swift
//  swift-mutex
//
//  Created by Simon Whitty on 07/09/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-mutex
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

#if canImport(Darwin)
// Backports the Synchronization.Mutex API for earlier Darwin platforms

@usableFromInline
struct Mutex<Value>: @unchecked Sendable {
    let storage: Storage

    @usableFromInline
    init(_ initialValue: consuming sending Value) {
        self.storage = Storage(initialValue)
    }

    @usableFromInline
    borrowing func withLock<Result, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        storage.lock()
        defer { storage.unlock() }
        return try body(&storage.value)
    }

    @usableFromInline
    borrowing func withLockIfAvailable<Result, E>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result? where E: Error {
        guard storage.tryLock() else { return nil }
        defer { storage.unlock() }
        return try body(&storage.value)
    }
}

import struct os.os_unfair_lock_t
import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock
import func os.os_unfair_lock_trylock

extension Mutex {

    final class Storage {
        private let _lock: os_unfair_lock_t

        var value: Value

        init(_ initialValue: Value) {
            self._lock = .allocate(capacity: 1)
            self._lock.initialize(to: os_unfair_lock())
            self.value = initialValue
        }

        func lock() {
            os_unfair_lock_lock(_lock)
        }

        func unlock() {
            os_unfair_lock_unlock(_lock)
        }

        func tryLock() -> Bool {
            os_unfair_lock_trylock(_lock)
        }

        deinit {
            self._lock.deinitialize(count: 1)
            self._lock.deallocate()
        }
    }
}

#elseif canImport(Synchronization)

import Synchronization

typealias Mutex = Synchronization.Mutex

#endif
#endif
