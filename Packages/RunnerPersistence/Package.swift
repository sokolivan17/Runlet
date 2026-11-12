// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunnerPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RunnerPersistence", targets: ["RunnerPersistence"])],
    dependencies: [
        .package(path: "../RunnerCore"),
        .package(path: "../RunnerEngine")
    ],
    targets: [
        .target(name: "RunnerPersistence", dependencies: [
            .product(name: "RunnerCore", package: "RunnerCore"),
            .product(name: "RunnerEngine", package: "RunnerEngine")
        ]),
        .testTarget(name: "RunnerPersistenceTests", dependencies: [
            "RunnerPersistence",
            .product(name: "RunnerCore", package: "RunnerCore"),
            .product(name: "RunnerEngine", package: "RunnerEngine")
        ])
    ]
)
