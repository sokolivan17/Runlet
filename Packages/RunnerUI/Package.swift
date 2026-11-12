// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunnerUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RunnerUI", targets: ["RunnerUI"])],
    dependencies: [
        .package(path: "../RunnerCore"),
        .package(path: "../RunnerEngine"),
        .package(path: "../RunnerPersistence"),
        .package(path: "../RunnerFeatures")
    ],
    targets: [
        .target(name: "RunnerUI", dependencies: [
            .product(name: "RunnerCore", package: "RunnerCore"),
            .product(name: "RunnerEngine", package: "RunnerEngine"),
            .product(name: "RunnerPersistence", package: "RunnerPersistence"),
            .product(name: "RunnerFeatures", package: "RunnerFeatures")
        ]),
        .testTarget(name: "RunnerUITests", dependencies: ["RunnerUI"])
    ]
)
