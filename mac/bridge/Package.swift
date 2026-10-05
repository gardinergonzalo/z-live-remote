// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZLiveRemoteBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ZLiveRemoteBridge",
            targets: ["ZLiveRemoteBridge"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ZLiveRemoteBridge",
            path: "Sources/ZLiveRemoteBridge"
        )
    ]
)
