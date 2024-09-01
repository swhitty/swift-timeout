[![Build](https://github.com/swhitty/TaskTimeout/actions/workflows/build.yml/badge.svg)](https://github.com/swhitty/TaskTimeout/actions/workflows/build.yml)
[![Codecov](https://codecov.io/gh/swhitty/TaskTimeout/graphs/badge.svg)](https://codecov.io/gh/swhitty/TaskTimeout)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20Mac%20|%20tvOS%20|%20Linux%20|%20Windows-lightgray.svg)](https://github.com/swhitty/TaskTimeout/blob/main/Package.swift)
[![Swift 6.0](https://img.shields.io/badge/swift-5.10%20–%206.0-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)
[![Twitter](https://img.shields.io/badge/twitter-@simonwhitty-blue.svg)](http://twitter.com/simonwhitty)

# Introduction

**TaskTimeout** is a lightweight wrapper around [`ThrowingTaskGroup`](https://developer.apple.com/documentation/swift/throwingtaskgroup) that executes a closure with a given timeout.

# Installation

TaskTimeout can be installed by using Swift Package Manager.

 **Note:** TaskTimeout requires Swift 5.10 on Xcode 15.4+. It runs on iOS 13+, tvOS 13+, macOS 10.15+, Linux and Windows.
To install using Swift Package Manager, add this to the `dependencies:` section in your Package.swift file:

```swift
.package(url: "https://github.com/swhitty/TaskTimeout.git", .upToNextMajor(from: "0.1.0"))
```

# Usage

Usage is similar to using task groups:

```swift
let val = try await withThrowingTimeout(seconds: 1.5) {
  try await perform()
}
```

If the timeout expires before a value is returned the task is cancelled and `TimeoutError` is thrown.

# Credits

TaskTimeout is primarily the work of [Simon Whitty](https://github.com/swhitty).

([Full list of contributors](https://github.com/swhitty/TaskTimeout/graphs/contributors))
