// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunnerCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RunnerCore", targets: ["RunnerCore"])],
    targets: [
        .target(name: "RunnerCore"),
        .testTarget(name: "RunnerCoreTests", dependencies: ["RunnerCore"])
    ]
)
