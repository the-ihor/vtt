// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VTT",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VTT",
            path: "Sources/VTT",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
