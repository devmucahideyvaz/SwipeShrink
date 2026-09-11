// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwipeShrink",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        // macOS is supported so the geometry can be unit tested with `swift test`;
        // the UIKit driver is compiled out there.
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "SwipeShrink", targets: ["SwipeShrink"])
    ],
    targets: [
        .target(name: "SwipeShrink", path: "Sources/SwipeShrink"),
        .testTarget(name: "SwipeShrinkTests",
                    dependencies: ["SwipeShrink"],
                    path: "Tests/SwipeShrinkTests")
    ]
)
