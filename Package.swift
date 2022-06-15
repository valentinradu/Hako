// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTinyRedux",
    platforms: [
        .iOS(.v15), .macOS(.v11), .tvOS(.v9),
        .macCatalyst(.v13), .watchOS(.v2),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftTinyRedux",
            targets: ["SwiftTinyRedux"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftTinyRedux",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftTinyReduxTests",
            dependencies: ["SwiftTinyRedux"]
        ),
    ]
)
