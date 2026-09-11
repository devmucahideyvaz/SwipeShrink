// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwipeShrink",
    platforms: [
        .iOS(.v13),
        // macOS is supported so the geometry can be unit tested with `swift test`;
        // the UIKit driver is compiled out there.
        .macOS(.v10_15)
    ],
    products: [
        // The UIKit driver, plus the shared geometry.
        .library(name: "SwipeShrink", targets: ["SwipeShrink"]),
        // The SwiftUI view. Depends on the same geometry, so the two
        // implementations cannot drift apart.
        .library(name: "SwipeShrinkUI", targets: ["SwipeShrinkUI"])
    ],
    targets: [
        .target(name: "SwipeShrink", path: "Sources/SwipeShrink"),
        .target(name: "SwipeShrinkUI",
                dependencies: ["SwipeShrink"],
                path: "Sources/SwipeShrinkUI"),
        .testTarget(name: "SwipeShrinkTests",
                    dependencies: ["SwipeShrink"],
                    path: "Tests/SwipeShrinkTests")
    ],
    // Build both targets in Swift 6 language mode, which turns on complete
    // strict concurrency checking.
    swiftLanguageModes: [.v6]
)
