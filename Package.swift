// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Timeout",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Timeout",
            targets: ["Timeout"]
        )
    ],
    targets: [
        .target(
            name: "Timeout",
            path: "Sources",
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "TimeoutTests",
            dependencies: ["Timeout"],
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
