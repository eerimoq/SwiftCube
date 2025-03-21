// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCube",
    platforms: [.macOS("10.15"), .iOS("16.0")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftCube",
            targets: ["SwiftCube"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftCube", dependencies: [
            ]
        ),
        .testTarget(
            name: "SwiftCubeTests",
            dependencies: ["SwiftCube"], resources: [
                .process("SampleLUT.cube"),
                .process("SampleImage.jpg")]
        ),
    ]
)
