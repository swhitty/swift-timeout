// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "TaskTimeout",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "TaskTimeout",
            targets: ["TaskTimeout"]
        )
    ],
    targets: [
        .target(
            name: "TaskTimeout",
            path: "Sources",
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "TaskTimeoutTests",
            dependencies: ["TaskTimeout"],
            path: "Tests",
            swiftSettings: .upcomingFeatures
        )
    ]
)

extension Array where Element == SwiftSetting {

    static var upcomingFeatures: [SwiftSetting] {
        [
            .swiftLanguageMode(.v6)
        ]
    }
}
