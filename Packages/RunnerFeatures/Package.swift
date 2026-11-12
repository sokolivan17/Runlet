// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunnerFeatures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RunnerFeatures", targets: ["RunnerFeatures"])],
    dependencies: [
        .package(path: "../RunnerCore"),
        .package(path: "../RunnerEngine"),
        .package(path: "../RunnerPersistence")
    ],
    targets: [
        .target(name: "RunnerFeatures", dependencies: [
            .product(name: "RunnerCore", package: "RunnerCore"),
            .product(name: "RunnerEngine", package: "RunnerEngine"),
            .product(name: "RunnerPersistence", package: "RunnerPersistence")
        ]),
        .testTarget(name: "RunnerFeaturesTests", dependencies: [
            "RunnerFeatures",
            .product(name: "RunnerCore", package: "RunnerCore"),
            .product(name: "RunnerEngine", package: "RunnerEngine"),
            .product(name: "RunnerPersistence", package: "RunnerPersistence")
        ])
    ]
)
