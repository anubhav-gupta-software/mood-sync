// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoodSyncCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MoodSyncCore", targets: ["MoodSyncCore"])
    ],
    targets: [
        .target(name: "MoodSyncCore"),
        .testTarget(name: "MoodSyncCoreTests", dependencies: ["MoodSyncCore"])
    ]
)
