// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Awake",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "Awake",
            path: "Awake",
            exclude: ["AwakeApp.swift", "Info.plist"]
        ),
        .testTarget(
            name: "AwakeTests",
            dependencies: ["Awake"],
            path: "AwakeTests"
        )
    ]
)
