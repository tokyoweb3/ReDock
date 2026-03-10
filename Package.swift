// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ReDock",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ReDock",
            dependencies: [
                "KeyboardShortcuts",
            ],
            path: "Sources/ReDock",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ReDockTests",
            dependencies: ["ReDock"],
            path: "Tests/ReDockTests"
        ),
    ]
)
