// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNES",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .visionOS(.v1),
        .tvOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "SwiftNES", targets: ["SwiftNES"])
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "SwiftNES"),
        .testTarget(
            name: "SwiftNESTest",
            dependencies: ["SwiftNES"],
            resources: [
                .copy("SwiftNESTests/Test Programs/cpu_dummy_reads.nes"),
                .copy("SwiftNESTests/Test Programs/branch_basics.nes"),
                .copy("SwiftNESTests/Test Programs/backward_branch.nes"),
                .copy("SwiftNESTests/Test Programs/forward_branch.nes")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
