// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunnerEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RunnerEngine", targets: ["RunnerEngine"])],
    dependencies: [.package(path: "../RunnerCore")],
    targets: [
        .target(name: "RunnerEngine", dependencies: [.product(name: "RunnerCore", package: "RunnerCore")]),
        .testTarget(name: "RunnerEngineTests", dependencies: [
            "RunnerEngine",
            .product(name: "RunnerCore", package: "RunnerCore")
        ])
    ]
)
