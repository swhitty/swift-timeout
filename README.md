[![Build](https://github.com/swhitty/swift-timeout/actions/workflows/build.yml/badge.svg)](https://github.com/swhitty/swift-timeout/actions/workflows/build.yml)
[![Codecov](https://codecov.io/gh/swhitty/swift-timeout/graphs/badge.svg)](https://codecov.io/gh/swhitty/swift-timeout)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswhitty%2Fswift-timeout%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/swhitty/swift-timeout)
[![Swift 6.0](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswhitty%2Fswift-timeout%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swhitty/swift-timeout)

# Introduction

**swift-timeout** is a lightweight wrapper around [`Task`](https://developer.apple.com/documentation/swift/task) that executes a closure with a given timeout.

# Installation

Timeout can be installed by using Swift Package Manager.

 **Note:** Timeout requires Swift 5.10 on Xcode 15.4+. It runs on iOS 13+, tvOS 13+, macOS 10.15+, Linux and Windows.
To install using Swift Package Manager, add this to the `dependencies:` section in your Package.swift file:

```swift
.package(url: "https://github.com/swhitty/swift-timeout.git", .upToNextMajor(from: "0.2.0"))
```

# Usage

Provide a closure and a [`Instant`](https://developer.apple.com/documentation/swift/continuousclock/instant) for when the child task must complete else `TimeoutError` is thrown:

```swift
import Timeout

let val = try await withThrowingTimeout(after: .now + .seconds(2)) {
  try await perform()
}
```

`TimeInterval` can also be provided:

```swift
let val = try await withThrowingTimeout(seconds: 2.0) {
  try await perform()
}
```

> Note: When the timeout expires the task executing the closure is cancelled and `TimeoutError` is thrown.

# Credits

Timeout is primarily the work of [Simon Whitty](https://github.com/swhitty).

([Full list of contributors](https://github.com/swhitty/swift-timeout/graphs/contributors))
