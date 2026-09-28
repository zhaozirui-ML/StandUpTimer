// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "StandUpTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StandUpTimer", path: "Sources/StandUpTimer")
    ]
)
