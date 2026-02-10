// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalHours",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocalHoursCore",
            targets: ["LocalHoursCore"]
        ),
    ],
    dependencies: [
        // Skip dependencies commented out for now - can be re-enabled for Android support
        // .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        // .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        // .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LocalHoursCore",
            dependencies: [],
            path: "Sources/LocalHoursCore"
        ),
        .testTarget(
            name: "LocalHoursCoreTests",
            dependencies: ["LocalHoursCore"],
            path: "Tests/LocalHoursCoreTests"
        ),
    ]
)
