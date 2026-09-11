// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwipeShrink",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        // macOS is supported so the geometry can be unit tested with `swift test`;
        // the UIKit driver is compiled out there.
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwipeShrink", targets: ["SwipeShrink"])
    ],
    targets: [
        .target(name: "SwipeShrink", path: "Sources/SwipeShrink"),
        .testTarget(name: "SwipeShrinkTests",
                    dependencies: ["SwipeShrink"],
                    path: "Tests/SwipeShrinkTests")
    ],
    // Build both targets in Swift 6 language mode, which turns on complete
    // strict concurrency checking.
    swiftLanguageModes: [.v6]
)
