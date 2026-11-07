// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkSpeedCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WalkSpeedCore", targets: ["WalkSpeedCore"]),
    ],
    targets: [
        .target(name: "WalkSpeedCore"),
        .testTarget(name: "WalkSpeedCoreTests", dependencies: ["WalkSpeedCore"]),
    ]
)
