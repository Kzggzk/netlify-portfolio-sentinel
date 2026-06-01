// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetlifyPortfolioSentinel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "NetlifyPortfolioSentinelCore",
            targets: ["NetlifyPortfolioSentinelCore"]
        ),
        .executable(
            name: "NetlifyPortfolioSentinel",
            targets: ["NetlifyPortfolioSentinelApp"]
        ),
        .executable(
            name: "sentinelctl",
            targets: ["SentinelCLI"]
        )
    ],
    targets: [
        .target(
            name: "NetlifyPortfolioSentinelCore",
            path: "src/Core",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "NetlifyPortfolioSentinelApp",
            dependencies: ["NetlifyPortfolioSentinelCore"],
            path: "src/App",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "SentinelCLI",
            dependencies: ["NetlifyPortfolioSentinelCore"],
            path: "src/CLI"
        ),
        .testTarget(
            name: "NetlifyPortfolioSentinelCoreTests",
            dependencies: ["NetlifyPortfolioSentinelCore"],
            path: "tests/CoreTests"
        )
    ]
)
