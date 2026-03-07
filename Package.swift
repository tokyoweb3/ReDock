// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MWM",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MWM",
            dependencies: [
                "KeyboardShortcuts",
            ],
            path: "Sources/MWM",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MWMTests",
            dependencies: ["MWM"],
            path: "Tests/MWMTests"
        ),
    ]
)
