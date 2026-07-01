// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NowPlayingBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "NowPlayingCore"),
        .executableTarget(
            name: "NowPlayingBar",
            dependencies: ["NowPlayingCore"]
        ),
        .testTarget(
            name: "NowPlayingCoreTests",
            dependencies: ["NowPlayingCore"]
        ),
    ]
)
