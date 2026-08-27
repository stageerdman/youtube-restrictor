// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YTRestrictor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "YTRestrictor",
            path: "Sources/YTRestrictor"
        )
    ]
)
